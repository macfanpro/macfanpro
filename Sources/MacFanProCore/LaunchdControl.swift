import Foundation

/// A launchd step that failed during install or uninstall. Kept apart from
/// MacFanProError, whose cases describe SMC failures: a bootout/bootstrap
/// problem is neither an SMC write nor fixed by sudo (the caller already has it),
/// and the user needs the command that recovers. `detail` is launchctl's own
/// output, folded in so the user sees one message with the real cause.
public enum LaunchdError: Error, CustomStringConvertible, Equatable, LocalizedError {
    case bootoutFailed(exitStatus: Int32, detail: String, rerun: String)
    case stillRegistered(seconds: Int, rerun: String)
    case bootstrapFailed(exitStatus: Int32, detail: String, rerun: String)
    case queryFailed(exitStatus: Int32, detail: String)

    public var errorDescription: String? { description }

    public var description: String {
        switch self {
        case .bootoutFailed(let status, let detail, let rerun):
            return "Couldn't stop the running MacFanPro daemon\(Self.cause(detail, status)). Re-run: \(rerun)"
        case .stillRegistered(let seconds, let rerun):
            return "launchd still had the old MacFanPro daemon registered \(seconds)s after it was stopped. Re-run: \(rerun)"
        case .bootstrapFailed(let status, let detail, let rerun):
            return "Couldn't start the MacFanPro daemon, also on retry\(Self.cause(detail, status)). Re-run: \(rerun)"
        case .queryFailed(let status, let detail):
            return "Couldn't determine whether the MacFanPro daemon is registered\(Self.cause(detail, status)). Check launchd and retry."
        }
    }

    /// ": <launchctl's message> (launchctl exit N)", or just the exit status when
    /// launchctl said nothing.
    static func cause(_ detail: String, _ status: Int32) -> String {
        detail.isEmpty ? " (launchctl exit \(status))" : ": \(detail) (launchctl exit \(status))"
    }
}

/// The launchd steps install/uninstall drive. launchctl, the registration query
/// and the clock are injected so the ordering logic tests without root; `system`
/// is the real thing. Nothing here waits a fixed time: each wait polls for the
/// state it needs, bounded so a genuine failure still ends.
struct LaunchdControl {
    /// Runs launchctl with the given arguments; returns its exit status and its
    /// combined stdout/stderr, trimmed. Output is captured, never printed raw.
    var launchctl: ([String]) throws -> (status: Int32, output: String)
    var isRegistered: () throws -> Bool
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var pause: (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    /// Cap on waiting for launchd to finish tearing the old job down. Above
    /// launchd's default 20s SIGTERM→SIGKILL exit timeout, so it only ends a wait
    /// that is never going to succeed.
    var teardownLimit: TimeInterval = 30
    var pollInterval: TimeInterval = 0.2

    static let system = LaunchdControl(
        launchctl: { arguments in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            p.arguments = arguments
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            try p.run()
            // Drain before waiting, so a full pipe can never stall launchctl.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (p.terminationStatus, output)
        },
        isRegistered: { try MacFanProDaemon.registrationStatus() }
    )

    /// launchctl print returns 113 for a missing service. Other failures mean
    /// unknown state, not absence: installation/removal must stop in that case.
    static func registrationStatus(_ run: SystemTools.ToolRun) throws -> Bool {
        switch run {
        case .exited(0, _): return true
        case .exited(113, _): return false
        case .exited(let status, let output): throw LaunchdError.queryFailed(exitStatus: status, detail: output)
        case .notLaunched(let reason): throw LaunchdError.queryFailed(exitStatus: -1, detail: reason)
        }
    }

    /// Poll `condition` until it holds; false only if `limit` passes first.
    func waitUntil(limit: TimeInterval, _ condition: () throws -> Bool) rethrows -> Bool {
        let deadline = now() + limit
        while true {
            if try condition() { return true }
            if now() >= deadline { return false }
            pause(pollInterval)
        }
    }

    func bootoutIfRegistered(label: String, rerun: String) throws {
        guard try isRegistered() else { return }
        let result = try launchctl(["bootout", "system/\(label)"])
        guard result.status == 0 else {
            throw LaunchdError.bootoutFailed(exitStatus: result.status, detail: result.output, rerun: rerun)
        }
        // bootout can return before launchd finishes tearing the job down; an
        // immediate bootstrap would then fail. Wait for the state, not a delay.
        guard try waitUntil(limit: teardownLimit, { try !isRegistered() }) else {
            throw LaunchdError.stillRegistered(seconds: Int(teardownLimit), rerun: rerun)
        }
    }

    func bootstrap(plist: String, rerun: String, note: (String) -> Void) throws {
        let first = try launchctl(["bootstrap", "system", plist])
        guard first.status != 0 else { return }
        // Registered despite the error: the job is loaded, so the caller's
        // running check decides. Retrying would only fail on the existing job.
        guard try !isRegistered() else { return }
        note("Starting the daemon failed\(LaunchdError.cause(first.output, first.status)); retrying once.")
        let second = try launchctl(["bootstrap", "system", plist])
        guard second.status == 0 else {
            if try isRegistered() { return } // same partial-success check as the first attempt
            throw LaunchdError.bootstrapFailed(exitStatus: second.status, detail: second.output, rerun: rerun)
        }
    }
}
