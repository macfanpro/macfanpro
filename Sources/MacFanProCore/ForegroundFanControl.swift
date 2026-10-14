import Foundation

/// A foreground controller must use the daemon's ownership and thermal protection
/// when installed. Once selected, a lost daemon is an error, never a direct write.
/// Call apply/finish serially, and drain the monitor before finish.
public final class ForegroundFanControl {
    private let execute: (FanCommand) throws -> Void
    private let installationLock: ServiceInstallationLock?
    private var needsRelease = false

    public convenience init() throws {
        guard geteuid() == 0 else { throw FanRouteError.rootRequired }
        // A second watch/calibration or an installer must not replace the active
        // controller midway through a foreground session (including idle ticks).
        let lock = try ServiceInstallationLock()
        if try MacFanProDaemon.registrationStatus() || MacFanProDaemon.isRunning {
            let client = DaemonClient()
            let response = try client.request(DaemonRequest(verb: .version))
            guard response.ok, let version = response.version,
                  MacFanProVersion.atLeast(version, MacFanProVersion.oneshotProtocolSince)
            else { throw FanRouteError.legacyDaemonNeedsReinstall }
            guard try !client.readState().isCLIHold else {
                throw EmbeddedServiceInstallation.Failure.manualHold
            }
            self.init(send: { try client.request($0, timeout: DaemonRequestPolicy.timeout(for: $0.verb)) }, lock: lock)
        } else {
            let fans = try FanControl()
            self.init(execute: { command in
                switch command {
                case .setMax: try fans.setMax()
                case .setRPM(let rpm): try fans.setAllFans(rpm: rpm)
                case .setFan(let index, let rpm): try fans.setSpeed(fan: index, rpm: rpm)
                case .resetAuto: try fans.resetAuto()
                case .releaseAppHold: throw DaemonError.notRunning
                }
            }, lock: lock)
        }
    }

    init(execute: @escaping (FanCommand) throws -> Void, lock: ServiceInstallationLock? = nil) {
        self.execute = execute
        self.installationLock = lock
    }

    convenience init(send: @escaping (DaemonRequest) throws -> DaemonResponse, lock: ServiceInstallationLock? = nil) {
        self.init(execute: { command in
            let response = try send(DaemonRequest(command, oneshot: true))
            guard response.ok else {
                throw DaemonError.commandFailed(response.message ?? "daemon rejected the command")
            }
        }, lock: lock)
    }

    public func apply(_ command: FanCommand) throws {
        // A failed write may already have acquired one fan's manual mode.
        if command.isHold { needsRelease = true }
        try execute(command)
        if command == .resetAuto { needsRelease = false }
    }

    public func finish() throws {
        if needsRelease { try apply(.resetAuto) }
    }
}
