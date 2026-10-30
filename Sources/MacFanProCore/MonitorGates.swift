import Foundation

/// Diagnostic reporting only. Every sample updates history, even during calibration
/// or a report cooldown; fan control and safety logging never pass through this gate.
struct AnomalyGate {
    private var history: [Float] = []
    private var lastReport: Date?
    private let cooldown: TimeInterval = 60

    mutating func report(temperature: Float, at now: Date, enabled: Bool) -> String? {
        defer {
            history.append(temperature)
            if history.count > 15 { history.removeFirst() }
        }
        let previous = history.last
        let sustained = history.count >= 15 ? history.first : nil
        let event: (String, Float, String)?
        if let previous, abs(temperature - previous) > 5 {
            event = ("Instant", previous, "2s")
        } else if let sustained, abs(temperature - sustained) > 10 {
            event = ("Sustained", sustained, "30s")
        } else { event = nil }
        guard enabled, let (kind, from, window) = event,
              lastReport.map({ now.timeIntervalSince($0) >= cooldown || now < $0 }) ?? true else { return nil }
        lastReport = now
        if kind == "Sustained" { history.removeAll() }
        let delta = temperature - from
        return "\(kind) \(delta > 0 ? "spike" : "drop"): \(String(format: "%.1f", from))→\(String(format: "%.1f", temperature))°C (\(String(format: "%+.1f", delta))°C in \(window))"
    }

    static func compact(_ snapshots: [(timestamp: String, processes: String)]) -> [String] {
        var lines: [String] = []
        var index = 0
        while index < snapshots.count {
            let first = snapshots[index]
            var end = index + 1
            while end < snapshots.count, snapshots[end].processes == first.processes { end += 1 }
            if end - index == 1 { lines.append("  \(first.timestamp): \(first.processes)") }
            else { lines.append("  \(first.timestamp) → \(snapshots[end - 1].timestamp): \(first.processes) (×\(end - index))") }
            index = end
        }
        return lines
    }
}

/// Only sampled cold time counts: sleep or a stalled poll cannot earn a release.
struct FanOffGate {
    private var coldSeconds: TimeInterval = 0
    mutating func reset() { coldSeconds = 0 }
    mutating func ready(cold: Bool, interval: TimeInterval) -> Bool {
        coldSeconds = cold ? coldSeconds + interval : 0
        return coldSeconds + 0.000_001 >= 5
    }
}

/// Wall-time UI cadence, independent of the monitor's resettable tick counter.
struct StatusPushGate {
    private var lastPush: Date?
    private var profileID: String?
    private var state: MonitorState?
    mutating func shouldPush(at now: Date, profileID: String, state: MonitorState) -> Bool {
        let changed = self.profileID != profileID || self.state != state
        guard changed || lastPush.map({ now.timeIntervalSince($0) >= 1 || now < $0 }) ?? true else { return false }
        lastPush = now
        self.profileID = profileID
        self.state = state
        return true
    }
    mutating func reset() { lastPush = nil }
}
