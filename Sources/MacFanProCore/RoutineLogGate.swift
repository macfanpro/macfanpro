import Foundation

/// Only gates successful routine diagnostics, never hardware execution or errors.
/// Uptime avoids changes in the wall clock extending the quiet window.
final class RoutineLogGate {
    private let lock = NSLock()
    private var last: [String: TimeInterval] = [:]
    private let now: () -> TimeInterval

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }

    func allows(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let current = now()
        if let previous = last[key], current >= previous, current - previous < 30 { return false }
        last[key] = current
        return true
    }

    func allows(request: DaemonRequest, response: DaemonResponse) -> Bool {
        // Errors, CLI holds and advisory outcomes (e.g. clamping) remain observable.
        guard response.ok, response.note == nil else { return true }
        switch request.verb {
        case .heartbeat, .version, .state, .status:
            return false
        case .set, .setfan:
            return request.oneshot || allows(key: request.verb.rawValue)
        case .max, .auto, .autoIfApp:
            return true
        }
    }
}
