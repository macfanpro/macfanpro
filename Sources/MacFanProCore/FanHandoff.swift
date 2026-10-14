import Foundation

/// Manual-mode acquisition, separated from IOKit so slow firmware can be tested
/// without changing real fan speeds. Re-read modes on every call (including wake).
enum FanHandoff {
    // A fully stopped M4 can reject mode writes for more than ten seconds.
    // Share one 20s acquisition budget across both fans, rather than failing
    // fan 0 at 10s despite the original two-fan path allowing ~20s overall.
    static let acquisitionSeconds: TimeInterval = 20

    /// Attempt every fan even if one mode write fails. Target RPM is advisory
    /// once automatic mode is restored. A rejected required write succeeds only
    /// if a fresh read after the full release confirms the desired state.
    static func release(
        indices: [Int], hasFtst: Bool, modeKey: (Int) -> String,
        read: (String) -> UInt8?,
        write: (String, [UInt8]) -> Bool
    ) throws {
        var failedModeKeys: [String] = []
        for index in indices {
            let key = modeKey(index)
            if !write(key, [0]) { failedModeKeys.append(key) }
            _ = write(SMCFanKey.key(SMCFanKey.target, fan: index), floatToSMCBytes(0))
        }
        let failedFtst = hasFtst && !write(SMCFanKey.forceTest, [0])
        // Stopped M4 fans can reject F*Md=0 while already in system mode (3).
        // Read after Ftst clears: that write can itself hand control back.
        for key in failedModeKeys {
            guard let mode = read(key), mode == 0 || mode == 3 else {
                throw MacFanProError.writeFailed(key)
            }
        }
        if failedFtst, read(SMCFanKey.forceTest) != 0 {
            throw MacFanProError.writeFailed(SMCFanKey.forceTest)
        }
    }

    static func acquire(
        indices: [Int], hasFtst: Bool, modeKey: (Int) -> String,
        readMode: (Int) -> UInt8?, write: (String, [UInt8]) -> Bool,
        sleep: (TimeInterval) -> Void = Thread.sleep(forTimeInterval:),
        now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) throws {
        let pending = indices.filter { readMode($0) != 1 }
        guard !pending.isEmpty else { return }
        let deadline = now() + acquisitionSeconds
        if hasFtst {
            guard write(SMCFanKey.forceTest, [1]) else {
                throw MacFanProError.unlockFailed("Failed to write Ftst=1. Run with sudo.")
            }
            sleep(0.5)
        }
        for index in pending {
            var succeeded = false
            while now() < deadline {
                if write(modeKey(index), [1]) {
                    succeeded = true
                    break
                }
                sleep(0.1)
            }
            guard succeeded else {
                throw MacFanProError.unlockFailed(
                    "Timed out setting fan \(index) to manual mode. Run with sudo."
                )
            }
        }
    }
}

/// Hardware writes may need the shared 20s firmware-handoff budget on this Mac.
/// Keep liveness/version reads fast; never extend their timeout to hide a stall.
enum DaemonRequestPolicy {
    static func timeout(for verb: DaemonRequest.Verb) -> TimeInterval {
        switch verb {
        case .max, .set, .setfan, .auto, .autoIfApp: return 30
        case .status, .state, .heartbeat, .version: return 2
        }
    }

    static func needsSMCLock(_ verb: DaemonRequest.Verb) -> Bool {
        switch verb {
        case .state, .heartbeat, .version: return false
        default: return true
        }
    }

    static func perform<T>(_ verb: DaemonRequest.Verb, lock: NSLock, _ body: () -> T) -> T {
        guard needsSMCLock(verb) else { return body() }
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
