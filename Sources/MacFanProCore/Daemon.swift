//
//  Daemon.swift
//  MacFanPro
//
//  Privileged daemon that runs as root via launchd.
//  Listens on a Unix socket so the app can control fans without sudo.
//

import Darwin
import Foundation
import IOKit.pwr_mgt

// MARK: - Constants

public enum MacFanProDaemon {
    // /var/run is root-owned 0755: unprivileged processes cannot create entries,
    // so path squatting is structurally impossible (unlike world-writable /tmp).
    // Cleared at boot; RunAtLoad re-creates the socket at daemon load.
    public static let socketPath = "/var/run/macfanpro.sock"
    public static let plistPath = "/Library/LaunchDaemons/io.github.macfanpro.daemon.plist"
    public static let installPath = "/usr/local/bin/macfanpro"
    public static let label = "io.github.macfanpro.daemon"

    /// Check if the daemon socket exists and accepts connections
    public static var isRunning: Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        setPath(&addr, socketPath)

        // Bounded connect: a wedged daemon (accept loop stalled, listen backlog
        // full) must make this return false — NOT hang. This is on the emergency
        // reset path: `sudo macfanpro auto` → FanCommandRouter.apply → this
        // guard; returning false there falls back to a direct root SMC reset, which
        // is exactly the right behavior when the daemon can't be reached. An
        // unbounded connect here would hang the one command that must always work.
        return connectWithTimeout(fd, &addr, timeout: 2.0)
    }

    /// Whether launchd has our label registered in the system domain. This is
    /// true even when the job is loaded-but-failing (retry-looping on a dead
    /// exec) — where `isRunning` is false because the socket never comes up — so
    /// it's the right question to ask before deciding to boot out. Requires root
    /// (system domain); the install/uninstall callers already run under sudo.
    public static var isRegisteredWithLaunchd: Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["print", "system/\(label)"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Boot out our launchd job, but only if the label is actually registered —
    /// so a fresh install (nothing loaded) doesn't provoke a spurious
    /// "Boot-out failed: No such process". If a bootout IS attempted and fails
    /// for a real reason, it throws rather than swallowing it.
    public static func bootoutIfRegistered() throws {
        guard isRegisteredWithLaunchd else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["bootout", "system/\(label)"]
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw MacFanProError.writeFailed(
                "launchctl bootout system/\(label) failed (exit \(p.terminationStatus))"
            )
        }
        Thread.sleep(forTimeInterval: 0.5)   // let launchd settle before re-bootstrap
    }
}

// MARK: - Daemon Client

public enum DaemonError: Error, CustomStringConvertible {
    case notRunning
    case connectionFailed
    case commandFailed(String)
    /// The running daemon speaks the pre-Phase-2 string protocol (upgrade window:
    /// `brew upgrade` done, `sudo macfanpro install` not yet). Its socket is up so
    /// it isn't "not running" — callers must handle this distinctly (reinstall nudge /
    /// direct-SMC fallback), not mistake it for a transient failure.
    case incompatibleDaemon

    public var description: String {
        switch self {
        case .notRunning:
            return "MacFanPro daemon is not running. Run: sudo macfanpro install"
        case .connectionFailed:
            return "Failed to connect to daemon socket"
        case .commandFailed(let msg):
            return "Daemon error: \(msg)"
        case .incompatibleDaemon:
            return "The background daemon is an older build using the previous control protocol. Reinstall to reconnect: sudo macfanpro install"
        }
    }
}

/// The daemon's current hold, returned by the `state` verb as JSON.
public struct DaemonHoldState: Codable, Equatable {
    /// The held fan command ("max", "set 3000", "setfan 1 3000"), or nil if none.
    public let command: String?
    /// Who set it: "cli" (unsupervised, never watchdog-reverted), "app"
    /// (supervised, reverted if the app stops checking in), or "none".
    public let owner: String
    /// True while the thermal floor is overriding this hold to max for safety. The
    /// `command` still reflects what the USER asked for (e.g. "set 2000"), never "max",
    /// so the app can say "held at 2000 — temporarily maxed for safety".
    public let safetySuspended: Bool

    public init(command: String?, owner: String, safetySuspended: Bool = false) {
        self.command = command
        self.owner = owner
        self.safetySuspended = safetySuspended
    }

    public var isEmpty: Bool { owner == "none" }
    public var isCLIHold: Bool { owner == "cli" }
}

/// The result of applying a fan command: the daemon's advisory note (e.g. a clamp)
/// and the RPM it actually applied. Both come straight from the daemon's response so
/// the CLI echoes the authoritative value, never a laggy target-register read-back.
public struct FanApplyResult: Equatable {
    public let note: String?
    public let appliedRPM: Int?
    public init(note: String?, appliedRPM: Int?) {
        self.note = note
        self.appliedRPM = appliedRPM
    }
}

public final class DaemonClient {
    public init() {}

    /// Read the daemon's current hold (what's set and who owns it) so the menu
    /// bar app can reflect a CLI hold instead of fighting or wiping it.
    public func readState() throws -> DaemonHoldState {
        let response = try request(DaemonRequest(verb: .state))
        guard response.ok, let state = response.state else {
            throw DaemonError.commandFailed("malformed state response")
        }
        return state
    }

    /// Apply a `FanCommand`, throwing `commandFailed` on an error response.
    /// - oneshot: apply the command but do NOT arm the heartbeat watchdog — for
    ///   fire-and-forget CLI holds that must persist without a supervising process.
    ///   The menu bar app leaves this false so it stays supervised/crash-protected.
    ///   No effect on resetAuto (nothing to hold).
    @discardableResult
    public func execute(_ command: FanCommand, oneshot: Bool = false) throws -> FanApplyResult {
        let req = DaemonRequest(command, oneshot: oneshot)
        let response = try request(req, timeout: DaemonRequestPolicy.timeout(for: req.verb))
        guard response.ok else {
            throw DaemonError.commandFailed(
                response.message ?? response.error.map { String(describing: $0) } ?? "daemon error"
            )
        }
        // Note + applied RPM ride back on an OK response (e.g. a clamp).
        return FanApplyResult(note: response.note, appliedRPM: response.appliedRPM)
    }

    /// Send one typed request and return the typed response — length-prefixed JSON
    /// frames, no string protocol. Runs over the SAME bounded socket code as before
    /// (the v0.1.7 freeze fix): non-blocking `connectWithTimeout` plus
    /// SO_RCVTIMEO/SO_SNDTIMEO, so a wedged daemon can never block the caller.
    public func request(_ req: DaemonRequest, timeout: TimeInterval = 2.0) throws -> DaemonResponse {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw DaemonError.connectionFailed }
        defer { close(fd) }
        var noSignal: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal,
                         socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw DaemonError.connectionFailed
        }

        // Bound every send/recv so a hung or contended daemon can never block the
        // caller indefinitely — the v0.1.7 freeze. Healthy round-trips here are
        // sub-millisecond for heartbeat/version/state. Hardware writes use a
        // separate 30s budget because initial M1-M4 manual acquisition can take
        // up to the shared 20s acquisition budget; cached reads retain the 2s default.
        let whole = Int(timeout)
        var tv = timeval(tv_sec: whole, tv_usec: Int32((timeout - Double(whole)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        setPath(&addr, MacFanProDaemon.socketPath)

        // connect() must ALSO be bounded, not just read/write. A wedged daemon
        // (accept loop stalled in a slow handleClient, listen backlog full) makes a
        // fresh connect() block indefinitely — and with the launch-adopt gate that
        // would silently leave the app with no fan control and no heartbeat. The
        // shared helper connects non-blocking, polls within `timeout`, and restores
        // blocking mode on success so SO_RCVTIMEO/SO_SNDTIMEO govern the frame I/O.
        guard connectWithTimeout(fd, &addr, timeout: timeout) else {
            throw DaemonError.notRunning
        }

        let frame = try DaemonProtocol.encodeFrame(req, max: DaemonProtocol.maxRequestBytes)
        try DaemonProtocol.writeFrame(fd, frame)
        do {
            let body = try DaemonProtocol.readFrame(fd, max: DaemonProtocol.maxResponseBytes)
            return try DaemonProtocol.decode(DaemonResponse.self, from: body)
        } catch DaemonProtocol.FrameError.legacyPeer {
            // A pre-Phase-2 daemon replied with a raw string; surface it distinctly so
            // callers can nudge a reinstall / fall back to direct SMC, not treat it as
            // a generic failure.
            throw DaemonError.incompatibleDaemon
        }
    }
}

// MARK: - Hold State

/// The daemon's current fan hold. Distinguishes an unsupervised CLI hold (never
/// watchdog-reverted — a fire-and-forget `macfanpro max`) from a supervised
/// app hold (reverted if the app stops checking in). These are the two states
/// the old single `lastHeartbeat: Date?` nil conflated, which is why an app
/// heartbeat silently re-armed the watchdog against a CLI oneshot hold (v0.1.5).
private enum HoldState {
    case none
    case unsupervised(command: String)
    case supervised(command: String, lastBeat: Date)

    /// The held command string ("max" / "set 3000" / "setfan 1 3000"), for
    /// wake re-apply. nil when nothing is held.
    var command: String? {
        switch self {
        case .none: return nil
        case .unsupervised(let c), .supervised(let c, _): return c
        }
    }

    func snapshot(safetySuspended: Bool = false) -> DaemonHoldState {
        switch self {
        case .none: return DaemonHoldState(command: nil, owner: "none", safetySuspended: safetySuspended)
        case .unsupervised(let c): return DaemonHoldState(command: c, owner: "cli", safetySuspended: safetySuspended)
        case .supervised(let c, _): return DaemonHoldState(command: c, owner: "app", safetySuspended: safetySuspended)
        }
    }
}

// MARK: - Daemon Server

public final class DaemonServer {
    private let socketFD: Int32
    private let fanControl: FanControl
    /// uid of the controlling user (who ran `sudo macfanpro install`). The
    /// socket is chown'd to this uid + 0600, so only that user (and root) connect.
    private let ownerUID: uid_t
    /// Serializes all SMC access — prevents data race between client handler and watchdog
    private let smcLock = NSLock()
    /// The current hold and its owner. Re-applied after sleep/wake; the watchdog
    /// reverts it only when it's `.supervised` and the app has gone silent.
    private var hold: HoldState = .none
    /// True while the thermal floor is overriding a hold to max. Guarded by stateLock.
    private var safetySuspended = false
    /// True after a failed write could not be undone: fans may be left manual (or
    /// Ftst set) with no hold recorded. The watchdog loop retries the reset.
    /// Guarded by stateLock.
    private var releasePending = false
    private let stateLock = NSLock()

    /// Per-fan [min, max] RPM, cached at init (fixed hardware constants) for clamping
    /// `set`/`setfan` — so a hostile value can't drive the SMC out of range.
    private let fanLimits: [(min: Float, max: Float)]
    /// Flood protection for SMC-writing verbs (`auto`/reset exempt). Guarded by rateLock.
    private var rateLimiter: RateLimiter
    private let rateLock = NSLock()
    /// The thermal safety floor's decision logic (thresholds mirrored from FanProfile).
    private let thermalFloor = ThermalFloor()
    /// A temperature sampler injected by tests. When nil, the floor reads the SMC
    /// safety keys itself — per key under smcLock — so it unit-tests via ThermalFloor
    /// and runs without head-of-line blocking in production.
    private let injectedSampler: (() -> Float?)?

    /// Phase 4 connection layer (concurrent bounded accept + framed I/O), created in run().
    private var connectionServer: ConnectionServer?

    public init(fanControl: FanControl, ownerUID: uid_t,
                sampleMaxTemp: (() -> Float?)? = nil) throws {
        self.fanControl = fanControl
        self.ownerUID = ownerUID
        // Cache fan RPM limits once (fixed hardware constants). Empty on a read failure
        // → clamp becomes a no-op and FanControl's own range check stays the backstop.
        self.fanLimits = (try? fanControl.status())?.fans
            .map { (Float($0.minRPM), Float($0.maxRPM)) } ?? []
        self.rateLimiter = RateLimiter(now: Date())
        self.injectedSampler = sampleMaxTemp

        // Refuse to start with an unusable owner. uid 0 would make the socket
        // root-only and silently lock every non-root account (the user's app/CLI)
        // out of fan control. Fail loudly under KeepAlive so Console.app shows why,
        // rather than a mystery "daemon-down" banner. Install.run() guarantees a
        // real uid, so reaching here means a hand-edited plist or a dev mistake.
        guard ownerUID != 0 else {
            NSLog("MacFanPro daemon: refusing to start — owner uid is 0. Reinstall with `sudo macfanpro install` from your user account.")
            throw MacFanProError.writeFailed("daemon owner uid must be non-zero")
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw MacFanProError.smcConnectionFailed
        }
        self.socketFD = fd

        // Remove stale socket (safe now: only root can have created anything in
        // root-owned /var/run — no unprivileged squatter to preserve).
        unlink(MacFanProDaemon.socketPath)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        setPath(&addr, MacFanProDaemon.socketPath)

        // Bind under a 0077 umask so the socket is 0700-from-birth — the previous
        // bind→chmod gap (default umask briefly left it world-accessible) never
        // exists. Restore the process umask immediately after.
        let oldMask = umask(0o077)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        umask(oldMask)
        guard bindResult == 0 else {
            close(fd)
            throw MacFanProError.writeFailed("bind() failed: \(errno)")
        }

        // Hand the socket to the controlling user: owned by them, group wheel,
        // 0600. Only that user (and root — perms don't bind root) can connect.
        //
        // The boundary is the umask(0o077) above — the socket is 0700-from-birth
        // unconditionally. These two calls are refinement, not the boundary: chown so
        // the user (not just root) can connect, chmod to trim the meaningless execute
        // bit on a socket. Neither degrades security if it fails — chown failing
        // leaves it root-only (fails closed); chmod failing leaves user-owned 0700,
        // functionally identical to 0600 on a socket. We guard them anyway for
        // DIAGNOSABILITY: an unchecked failure would surface as a mystery
        // "daemon-down" banner with no cause. A loud crash-loop under KeepAlive that
        // puts the errno in Console.app beats a silent lockout.
        guard chown(MacFanProDaemon.socketPath, ownerUID, 0) == 0 else {
            let err = errno
            NSLog("MacFanPro daemon: chown of the socket to uid %u failed: errno %d", ownerUID, err)
            close(fd)
            throw MacFanProError.writeFailed("chown() failed: errno \(err)")
        }
        guard chmod(MacFanProDaemon.socketPath, 0o600) == 0 else {
            let err = errno
            NSLog("MacFanPro daemon: chmod(0600) on the socket failed: errno %d", err)
            close(fd)
            throw MacFanProError.writeFailed("chmod() failed: errno \(err)")
        }

        guard listen(fd, 16) == 0 else {   // backlog holds queued connects while at the 8-handler cap
            close(fd)
            throw MacFanProError.writeFailed("listen() failed")
        }
    }

    /// Run the server loop (blocks forever)
    public func run() {
        NSLog("MacFanPro daemon: listening on %@", MacFanProDaemon.socketPath)
        // Start log maintenance even when no fan command has been issued.
        TFLogger.shared.daemon("Listening on \(MacFanProDaemon.socketPath)")

        // Watch for sleep/wake to re-apply fan settings
        registerWakeNotification()

        // Heartbeat watchdog: if app set fans to manual but hasn't checked in
        // for 15 seconds, reset to auto. Prevents fans stuck after app crash.
        startHeartbeatWatchdog()

        // Thermal safety floor: overrides a below-max hold toward max when a critical
        // sensor crosses the threshold, unkillable from user space. Defense in depth —
        // the client monitor is primary; this is the backstop that survives the app.
        startThermalFloor()

        // Accept connections concurrently (bounded) so one hung connection can't stall
        // others, and — the security fix — a slow-reading client can no longer hold
        // smcLock during the response write (processFrame takes it only around process()).
        let server = ConnectionServer(listenFD: socketFD) { [self] body in processFrame(body) }
        server.start()
        connectionServer = server

        // Main thread runs the RunLoop for wake notifications
        RunLoop.main.run()
    }

    // MARK: - Heartbeat Watchdog

    private func startHeartbeatWatchdog() {
        DispatchQueue.global(qos: .utility).async { [self] in
            while true {
                Thread.sleep(forTimeInterval: 5)

                retryPendingRelease()

                stateLock.lock()
                let current = hold
                stateLock.unlock()

                // ONLY a supervised hold is reverted — that's the app's crash
                // protection: the app set fans manually and stopped checking in,
                // so hand control back to macOS. An unsupervised CLI hold is
                // never touched here (the user asked for it; it persists until
                // CLI `auto` or the menu bar Default clears it). This is the
                // v0.1.5 fix: the app's heartbeat can no longer drag a CLI hold
                // into the supervised branch.
                guard case .supervised(_, let lastBeat) = current,
                      Date().timeIntervalSince(lastBeat) > 15 else { continue }

                // If the thermal floor is holding fans at max (overheating), do NOT
                // resetAuto — dropping fans while hot is the unsafe move. The app is
                // gone, so clear the dead hold (it must not be restored on cooldown);
                // fans stay at max, and the floor's cooldown path resets to auto once
                // it's safe. Crash protection preserved, its auto-reset deferred.
                stateLock.lock()
                let suspended = safetySuspended
                stateLock.unlock()
                if suspended {
                    // Under smcLock, like the floor's restore, so the hold can't vanish
                    // between the restore reading it and applying it (which would leave
                    // that speed pinned with no hold). Re-check once the lock is held.
                    smcLock.lock()
                    stateLock.lock()
                    if safetySuspended, case .supervised(_, let beat) = hold, beat == lastBeat { hold = .none }
                    stateLock.unlock()
                    smcLock.unlock()
                    NSLog("MacFanPro daemon: supervised hold timed out during thermal suspension — cleared; fans stay at max until cooldown")
                    continue
                }

                // Only the revert path allocates anything autoreleasable (NSLog +
                // error interpolation), and it never returns from this loop, so pool
                // it. The sleep/guard/continue stay outside — a steady tick allocates
                // nothing autoreleasable (Date is a value type).
                autoreleasepool {
                    smcLock.lock()
                    defer { smcLock.unlock() }
                    // Heartbeats take only stateLock, so re-check once smcLock is held
                    // and clear the expired hold in the same step. A heartbeat arriving
                    // during the reset then finds no hold to renew, instead of keeping a
                    // manual hold on record over fans that are back on auto. Commands
                    // need smcLock, so none can change the hold until this finishes.
                    stateLock.lock()
                    let expired: String?
                    if case .supervised(let command, let beat) = hold, beat == lastBeat {
                        hold = .none
                        expired = command
                    } else {
                        expired = nil
                    }
                    stateLock.unlock()
                    guard let expired else { return }
                    NSLog("MacFanPro daemon: heartbeat timeout — resetting fans to auto")
                    do {
                        try fanControl.resetAuto()
                    } catch {
                        NSLog("MacFanPro daemon: watchdog reset failed: %@, will retry", "\(error)")
                        // Put the expired hold back so the next tick retries the reset.
                        stateLock.lock()
                        if case .none = hold { hold = .supervised(command: expired, lastBeat: lastBeat) }
                        stateLock.unlock()
                    }
                }
            }
        }
    }

    // MARK: - Phase 3 Invariants (rate limit, clamp, thermal floor)

    /// Consume a rate-limiter token for an SMC-writing verb. `auto`/reset never calls
    /// this — reset must never be denied.
    private func allowWrite() -> Bool {
        rateLock.lock(); defer { rateLock.unlock() }
        return rateLimiter.allow(now: Date())
    }

    /// True while the thermal floor is overriding fans to max.
    private func isSuspended() -> Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return safetySuspended
    }

    /// Clamp a requested RPM to the fan's cached [min, max]. Returns the value to apply
    /// and an advisory note if it was clamped (the command still succeeds).
    private func clampRPM(_ rpm: Float, fan: Int) -> (value: Float, note: String?) {
        guard fan >= 0, fan < fanLimits.count else { return (rpm, nil) }
        let limit = fanLimits[fan]
        if limit.max > 0 && rpm > limit.max {
            return (limit.max, "clamped \(Int(rpm)) → \(Int(limit.max)) RPM (max)")
        }
        if limit.min > 0 && rpm < limit.min {
            return (limit.min, "clamped \(Int(rpm)) → \(Int(limit.min)) RPM (min)")
        }
        return (rpm, nil)
    }

    /// Apply a held command STRING directly to the SMC — no hold bookkeeping, so it
    /// never touches lastBeat. Shared by wake re-apply and the thermal-floor restore.
    /// Caller holds smcLock.
    private func applyCommandString(_ command: String) throws {
        let parts = command.split(separator: " ")
        switch parts.first.map(String.init) {
        case "max":
            try fanControl.setMax()
        case "set":
            if let rpm = parts.dropFirst().first.flatMap({ Float($0) }) {
                try fanControl.setAllFans(rpm: rpm)
            }
        case "setfan":
            let args = Array(parts.dropFirst())
            if args.count >= 2, let index = Int(args[0]), let rpm = Float(args[1]) {
                try fanControl.setSpeed(fan: index, rpm: rpm)
            }
        default:
            break
        }
    }

    // MARK: - Thermal Safety Floor

    /// 1s cadence: the client monitor at 100ms is primary; this is a backstop, and
    /// thermal mass doesn't move meaningfully in a second.
    private static let thermalCadence: TimeInterval = 1.0

    private func startThermalFloor() {
        DispatchQueue.global(qos: .utility).async { [self] in
            while true {
                Thread.sleep(forTimeInterval: Self.thermalCadence)
                autoreleasepool { thermalTick() }
            }
        }
    }

    /// Peak CPU/GPU temperature. Production path reads each safety key under smcLock
    /// and RELEASES between keys: the read serializes with client writes (no torn SMC
    /// access — the defect this fixes) but never holds the lock longer than a single
    /// ~0.3ms read, so a full ~10ms sweep can't head-of-line-block a fan command.
    /// Sampling temps interleaved with writes is safe — a write changes fan speed, not
    /// the sensors, and a threshold check doesn't need an instantaneous snapshot.
    private func currentSafetyTemp() -> Float? {
        if let injected = injectedSampler { return injected() }
        var peak: Float = 0
        for key in FanControl.safetyTempKeys {
            smcLock.lock()
            let t = fanControl.readTemp(key)
            smcLock.unlock()
            if let t { peak = max(peak, t) }
        }
        return peak > 0 ? peak : nil
    }

    private func thermalTick() {
        // Read hold/suspension FIRST, and skip the SMC sweep entirely when there is no
        // hold and we aren't already overriding. Rationale (we will be asked): the floor
        // protects a HOLD. No hold means fans are on Apple's auto curve — macOS is
        // managing thermals and there is nothing for the floor to override, so a reading
        // it could not act on is not safety. The floor exists for one case: MacFanPro
        // has pinned fans below what the machine needs and something has gone wrong. The
        // client monitor at 100ms is the primary governor with its own override; this is
        // the backstop that survives the app's death. So an idle daemon does zero SMC
        // work per tick — only a live below-max hold (or an active suspension) samples.
        stateLock.lock()
        let suspended = safetySuspended
        let heldCommand = hold.command
        stateLock.unlock()

        guard suspended || heldCommand != nil else { return }

        guard let temp = currentSafetyTemp() else { return }

        switch thermalFloor.evaluate(temp: temp, holdCommand: heldCommand, suspended: suspended) {
        case .none:
            return

        case .engage:
            // Override the below-max hold to max. Direct SMC write — NEVER recordHold,
            // so the user's command + lastBeat are preserved for restore.
            // Mark the suspension in the same smcLock section as the write, so a
            // command can't slip in between, see no suspension and lower the fans.
            smcLock.lock()
            let ok = (try? fanControl.setMax()) != nil
            if ok { stateLock.lock(); safetySuspended = true; stateLock.unlock() }
            smcLock.unlock()
            guard ok else { return }
            NSLog("MacFanPro daemon: thermal floor engaged at %.1f°C — fans held at max (was %@)",
                  temp, heldCommand ?? "none")

        case .restore:
            // Re-read the hold at restore time, under smcLock — the watchdog may have
            // cleared a dead app's hold during the suspension (then go to auto), and an
            // `auto` may have ended the suspension since this tick sampled it (then
            // there is nothing to restore; replaying the old command would re-pin fans
            // with no hold). Commands need smcLock, so the hold can't change until the
            // restore write and the state update below are done.
            smcLock.lock()
            stateLock.lock()
            let stillSuspended = safetySuspended
            let restoreCommand = hold.command
            stateLock.unlock()
            guard stillSuspended else { smcLock.unlock(); return }
            let ok: Bool
            if let cmd = restoreCommand {
                ok = (try? applyCommandString(cmd)) != nil
            } else {
                ok = (try? fanControl.resetAuto()) != nil
            }
            // Like engage: change state only after the write lands. Staying suspended
            // makes the next tick retry instead of leaving fans at max unreported.
            if ok { stateLock.lock(); safetySuspended = false; stateLock.unlock() }
            smcLock.unlock()
            guard ok else {
                NSLog("MacFanPro daemon: thermal floor restore failed at %.1f°C — will retry", temp)
                return
            }
            NSLog("MacFanPro daemon: thermal floor cleared at %.1f°C — %@",
                  temp, restoreCommand.map { "restored \($0)" } ?? "reset to auto")
        }
    }

    // MARK: - Sleep/Wake

    /// IOKit root port for power notifications
    private var rootPort: io_connect_t = 0
    private var notifyPort: IONotificationPortRef?
    private var notifier: io_object_t = 0

    private func registerWakeNotification() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        rootPort = IORegisterForSystemPower(
            refcon, &notifyPort, { (refcon, _, messageType, messageArgument) in
                guard let refcon = refcon else { return }
                let server = Unmanaged<DaemonServer>.fromOpaque(refcon).takeUnretainedValue()

                // IOKit message constants (macros unavailable in Swift)
                let kSystemHasPoweredOn: UInt32 = 0xe0000300
                let kSystemWillSleep: UInt32 = 0xe0000280
                let kCanSystemSleep: UInt32 = 0xe0000270

                switch messageType {
                case kSystemHasPoweredOn:
                    server.handleWake()
                case kSystemWillSleep, kCanSystemSleep:
                    IOAllowPowerChange(server.rootPort, numericCast(Int(bitPattern: messageArgument)))
                default:
                    break
                }
            }, &notifier
        )

        guard rootPort != 0, let notifyPort = notifyPort else {
            NSLog("MacFanPro daemon: failed to register for power notifications")
            return
        }

        let source = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        NSLog("MacFanPro daemon: registered for wake notifications")
    }

    private func handleWake() {
        stateLock.lock()
        let heldCommand = hold.command
        stateLock.unlock()
        guard let command = heldCommand else {
            NSLog("MacFanPro daemon: woke — no profile to re-apply")
            return
        }

        NSLog("MacFanPro daemon: woke — re-applying: %@", command)

        // Delay slightly — SMC needs a moment after wake
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [self] in
            smcLock.lock()
            defer { smcLock.unlock() }
            // Re-check under smcLock: during the delay an `auto` or a watchdog reset may
            // have cleared the hold, a new command may have replaced it, or the thermal
            // floor may be holding max. Replaying the stale command would re-pin fans
            // with no hold recorded, outside the watchdog's and the floor's reach.
            stateLock.lock()
            let current = hold.command
            let suspended = safetySuspended
            stateLock.unlock()
            guard current == command, !suspended else {
                NSLog("MacFanPro daemon: wake re-apply skipped — hold changed during the delay")
                return
            }
            do {
                try applyCommandString(command)
                NSLog("MacFanPro daemon: re-applied after wake")
            } catch {
                NSLog("MacFanPro daemon: wake re-apply failed: %@", "\(error)")
            }
        }
    }

    // MARK: - Request Processing

    /// Decode a request body → response: the framing/version/log wrapper around the
    /// atomic process(). smcLock is taken ONLY for the process() call — never around
    /// the I/O, so a slow-reading client can no longer hold it during the write.
    private func processFrame(_ body: Data) -> DaemonResponse {
        guard let request = try? DaemonProtocol.decode(DaemonRequest.self, from: body) else {
            // Undecodable = unknown verb or a shape from a newer client.
            return .unsupported(daemonVersion: MacFanProVersion.current)
        }
        // A newer protocol than we speak → tell the client our build so it can react.
        guard request.v <= DaemonProtocol.version else {
            return .unsupported(daemonVersion: MacFanProVersion.current)
        }
        // Liveness/state/version use only stateLock (or immutable data). Let them
        // answer during a slow firmware handoff instead of starving the watchdog.
        let response = DaemonRequestPolicy.perform(request.verb, lock: smcLock) {
            process(request)
        }
        // Verb + outcome only — never raw client bytes.
        NSLog("MacFanPro daemon: verb=%@ outcome=%@", request.verb.rawValue,
              response.ok ? "ok" : (response.error?.rawValue ?? "error"))
        return response
    }

    /// The full request dispatch — MOVED VERBATIM from the pre-Phase-4 serial handler.
    /// For hardware verbs the CALLER holds smcLock for the whole call, so every check-then-act
    /// (blockedByCLIHold, rate limit, clamp, recordHold + SMC write) stays atomic exactly
    /// as before; Phase 4 concurrency lives only in the I/O around this, never inside it.
    /// Same-class concurrent writers resolve by last-write-wins (recordHold overwrites) —
    /// the one authority rule is cross-class (CLI outranks app via blockedByCLIHold);
    /// equal-authority ties are arbitrary-but-consistent by design, not by lock order.
    private func process(_ request: DaemonRequest) -> DaemonResponse {
        let response: DaemonResponse
        do {
            let oneshot = request.oneshot

            // Record a hold: unsupervised (CLI oneshot — never watchdog-reverted) or
            // supervised (app — reverted if it stops checking in). Overwrites whatever
            // was held, so an explicit app command cleanly takes over a CLI hold with
            // no orphan left behind. The command STRING is kept verbatim so wake
            // re-apply (handleWake) and the `state` snapshot are unchanged.
            func recordHold(_ heldCommand: String) {
                stateLock.lock()
                releasePending = false
                hold = oneshot
                    ? .unsupervised(command: heldCommand)
                    : .supervised(command: heldCommand, lastBeat: Date())
                stateLock.unlock()
            }

            // A supervised (app) command must NOT silently overwrite an unsupervised
            // CLI hold — the CLI hold wins and the app is told to yield via the error,
            // instead of clobbering it in the ~100ms before its next state poll.
            // `oneshot` commands and `auto` are never blocked, so explicit app takeover
            // (which sends `auto` first, clearing the hold) still works.
            func blockedByCLIHold() -> Bool {
                guard !oneshot else { return false }
                stateLock.lock(); defer { stateLock.unlock() }
                if case .unsupervised = hold { return true }
                return false
            }

            // Flood cap for SMC-writing verbs. `auto`/reset is exempt — a reset must
            // never be denied. Checked after usage validation (malformed requests
            // don't burn tokens), before the write.
            let rateLimited = DaemonResponse.failure(.rateLimited, "too many fan commands; try again shortly")

            switch request.verb {
            case .max:
                if !allowWrite() { response = rateLimited; break }
                if blockedByCLIHold() { response = .failure(.heldByCLI, "held by cli"); break }
                // Skip the SMC write while the thermal floor holds fans at max — record
                // the new hold to restore on cooldown, but don't drop fans while hot.
                if !isSuspended() { try fanControl.setMax() }
                recordHold("max")
                response = .ok()
            case .auto:
                // Exempt from the rate cap. Also the "hand back to Apple's auto curve"
                // path, so it clears any thermal suspension — Apple's auto handles heat.
                try fanControl.resetAuto()
                stateLock.lock(); hold = .none; safetySuspended = false; releasePending = false; stateLock.unlock()
                response = .ok()
            case .set:
                guard let rpm = request.rpm else {
                    response = .failure(.usage, "usage: set <rpm>")
                    break
                }
                try FanControl.validateRPM(Float(rpm))
                if !allowWrite() { response = rateLimited; break }
                if blockedByCLIHold() { response = .failure(.heldByCLI, "held by cli"); break }
                let (clamped, note) = clampRPM(Float(rpm), fan: 0)
                if !isSuspended() { try fanControl.setAllFans(rpm: clamped) }
                recordHold("set \(Int(clamped))")
                response = .ok(note: note, appliedRPM: Int(clamped))
            case .setfan:
                guard let index = request.fan, let rpm = request.rpm else {
                    response = .failure(.usage, "usage: setfan <index> <rpm>")
                    break
                }
                // Validate even while thermally suspended, before consuming a token
                // or recording a hold that would be replayed on cooldown/wake.
                try fanControl.validateFanIndex(index)
                try FanControl.validateRPM(Float(rpm))
                if !allowWrite() { response = rateLimited; break }
                if blockedByCLIHold() { response = .failure(.heldByCLI, "held by cli"); break }
                let (clamped, note) = clampRPM(Float(rpm), fan: index)
                if !isSuspended() { try fanControl.setSpeed(fan: index, rpm: clamped) }
                recordHold("setfan \(index) \(Int(clamped))")
                response = .ok(note: note, appliedRPM: Int(clamped))
            case .status:
                // Same snake_case shape as the standalone CLI `status`, carried as an
                // opaque payload string (no consumer decodes it today).
                let status = try fanControl.status()
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                let data = try encoder.encode(status)
                response = .statusResponse(String(data: data, encoding: .utf8) ?? "{}")
            case .state:
                // Current hold + owner (+ whether the thermal floor is overriding it),
                // so the app can reflect a CLI hold rather than fight or wipe it.
                stateLock.lock()
                let snap = hold.snapshot(safetySuspended: safetySuspended)
                stateLock.unlock()
                response = .stateResponse(snap)
            case .heartbeat:
                // Refreshes a SUPERVISED hold's liveness only. On an unsupervised CLI
                // hold this is deliberately a no-op — the app checking in must NOT
                // convert a CLI hold into a supervised one (the v0.1.5 bug).
                stateLock.lock()
                if case .supervised(let c, _) = hold {
                    hold = .supervised(command: c, lastBeat: Date())
                }
                stateLock.unlock()
                response = .ok()
            case .version:
                // Reports the build this daemon process is running, so a CLI from a
                // newer install can detect it's talking to a stale daemon.
                response = .versionResponse(MacFanProVersion.current)
            }
        } catch let error as MacFanProError {
            switch error {
            case .invalidFanIndex, .invalidRPM:
                response = .failure(.usage, "\(error)")
            default:
                response = .failure(.internal, "\(error)")
                releaseAfterFailedWrite(request.verb)
            }
        } catch {
            response = .failure(.internal, "\(error)")
            releaseAfterFailedWrite(request.verb)
        }

        return response
    }

    /// A max/set/setfan that failed part-way may have left Ftst or a fan's manual mode
    /// set, and no hold is recorded for it, so nothing would ever hand the fans back.
    /// With no earlier hold to keep, reset to auto; if that fails too (the SMC can be
    /// unavailable during dark wake), let the watchdog loop retry. Caller holds smcLock.
    private func releaseAfterFailedWrite(_ verb: DaemonRequest.Verb) {
        switch verb {
        case .max, .set, .setfan: break
        default: return
        }
        stateLock.lock()
        let keep = hold.command != nil || safetySuspended
        stateLock.unlock()
        guard !keep else { return }
        let released = (try? fanControl.resetAuto()) != nil
        stateLock.lock(); releasePending = !released; stateLock.unlock()
        NSLog("MacFanPro daemon: fan write failed — %@", released ? "reset to auto" : "reset failed, will retry")
    }

    /// Retry a reset that `releaseAfterFailedWrite` could not complete, unless a hold
    /// or the thermal floor has taken the fans since.
    private func retryPendingRelease() {
        stateLock.lock()
        let pending = releasePending
        stateLock.unlock()
        guard pending else { return }
        smcLock.lock()
        defer { smcLock.unlock() }
        stateLock.lock()
        let needed = releasePending && hold.command == nil && !safetySuspended
        stateLock.unlock()
        let done = !needed || (try? fanControl.resetAuto()) != nil
        stateLock.lock(); if done { releasePending = false }; stateLock.unlock()
        if needed { NSLog("MacFanPro daemon: pending reset %@", done ? "succeeded" : "failed, will retry") }
    }

    deinit {
        close(socketFD)
        unlink(MacFanProDaemon.socketPath)
    }
}

// MARK: - Helpers

/// Copy a path string into sockaddr_un.sun_path
private func setPath(_ addr: inout sockaddr_un, _ path: String) {
    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
            _ = strlcpy(dest, path, 104)
        }
    }
}

/// Connect `fd` to `addr` bounded by `timeout` seconds, so a wedged daemon (accept
/// loop stalled, listen backlog full) can never block the caller forever. Both
/// `DaemonClient.sendRaw` (throws on false) and `MacFanProDaemon.isRunning`
/// (returns the Bool) go through here, so the two connect paths can't diverge.
///
/// Non-blocking connect, then `poll()` for completion. `poll()` is retried on EINTR
/// with the REMAINING budget — a signal must not turn a healthy daemon into a
/// spurious "not running". On success the socket is restored to blocking mode so
/// any SO_RCVTIMEO/SO_SNDTIMEO the caller set still governs the following read/write.
private func connectWithTimeout(_ fd: Int32, _ addr: inout sockaddr_un, timeout: TimeInterval) -> Bool {
    let origFlags = fcntl(fd, F_GETFL, 0)
    _ = fcntl(fd, F_SETFL, origFlags | O_NONBLOCK)

    let rc = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    var connected: Bool
    if rc == 0 {
        connected = true
    } else if errno == EINPROGRESS {
        connected = false
        let deadline = DispatchTime.now() + timeout
        while true {
            let now = DispatchTime.now()
            if now >= deadline { break }   // budget exhausted → not connected
            let remainingMs = Int32((deadline.uptimeNanoseconds - now.uptimeNanoseconds) / 1_000_000)

            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let por = poll(&pfd, 1, remainingMs)
            if por > 0 {
                // Woke on writability: connect finished — success iff SO_ERROR == 0.
                var soErr: Int32 = 0
                var soLen = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(fd, SOL_SOCKET, SO_ERROR, &soErr, &soLen)
                connected = (soErr == 0)
                break
            } else if por == 0 {
                break                       // timed out → not connected
            } else if errno == EINTR {
                continue                    // interrupted — recompute remaining budget, retry
            } else {
                break                       // real poll error → not connected
            }
        }
    } else {
        connected = false                   // ECONNREFUSED, EAGAIN (backlog full), …
    }

    if connected { _ = fcntl(fd, F_SETFL, origFlags) }   // restore blocking for read/write
    return connected
}
