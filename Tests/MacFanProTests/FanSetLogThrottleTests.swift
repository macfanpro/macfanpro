import Foundation
import Testing
@testable import MacFanProCore

@Suite("Fan set log throttle")
struct FanSetLogThrottleTests {
    @Test("A ramp logs one line per fan per interval and counts the skipped steps")
    func rampIsCoalesced() {
        var throttle = FanSetLogThrottle()
        let start = Date(timeIntervalSince1970: 1_000_000)
        var lines: [String] = []
        // A 12-second ramp at 10 steps a second on two fans: 240 writes.
        for step in 0..<120 {
            let now = start.addingTimeInterval(Double(step) / 10)
            for fan in 0..<2 {
                if let line = throttle.line(fan: fan, rpm: 3000 - step * 14, at: now) { lines.append(line) }
            }
        }
        #expect(lines == [
            "Set fan 0 to 3000 RPM", "Set fan 1 to 3000 RPM",
            "Set fan 0 to 2300 RPM (49 ramp steps since the last line)",
            "Set fan 1 to 2300 RPM (49 ramp steps since the last line)",
            "Set fan 0 to 1600 RPM (49 ramp steps since the last line)",
            "Set fan 1 to 1600 RPM (49 ramp steps since the last line)",
        ])
    }

    @Test("Writes spaced beyond the interval are all logged, and a reset logs the next one at once")
    func spacedWritesAndReset() {
        var throttle = FanSetLogThrottle()
        let start = Date(timeIntervalSince1970: 1_000_000)
        #expect(throttle.line(fan: 0, rpm: 2500, at: start) == "Set fan 0 to 2500 RPM")
        #expect(throttle.line(fan: 0, rpm: 2600, at: start.addingTimeInterval(6)) == "Set fan 0 to 2600 RPM")
        #expect(throttle.line(fan: 0, rpm: 2700, at: start.addingTimeInterval(7)) == nil)
        throttle.reset()
        #expect(throttle.line(fan: 0, rpm: 2800, at: start.addingTimeInterval(8)) == "Set fan 0 to 2800 RPM")
    }
}
