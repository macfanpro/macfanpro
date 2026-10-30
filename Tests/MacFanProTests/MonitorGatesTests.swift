import Foundation
import Testing
@testable import MacFanProCore

@Suite("Monitor gates — simulated samples only")
struct MonitorGatesTests {
    @Test("Explicit hands-off selection releases immediately instead of waiting for cold")
    func handsOffBypassesColdGate() {
        let f = ControlFixture()
        let monitor = f.monitor(.balanced)
        var commands: [FanCommand] = []
        monitor.onFanCommand = { commands.append($0) }
        f.smc.temperature = 70
        f.tick(monitor, count: 100)
        #expect(commands.contains { $0.isHold })
        monitor.switchProfile(.silent)
        f.tick(monitor)
        #expect(commands.last == .resetAuto)
        #expect(monitor.state == .idle)
    }
    @Test("Anomaly cooldown preserves current history and calibration does not consume a report")
    func anomalyCooldown() {
        var gate = AnomalyGate()
        let start = Date(timeIntervalSince1970: 1000)
        #expect({ (gate.report(temperature: 50, at: start, enabled: true) == nil) }())
        #expect({ (gate.report(temperature: 60, at: start.addingTimeInterval(2), enabled: true) != nil) }())
        #expect({ (gate.report(temperature: 80, at: start.addingTimeInterval(4), enabled: true) == nil) }())
        #expect({ (gate.report(temperature: 80, at: start.addingTimeInterval(62), enabled: true) == nil) }())
        #expect({ (gate.report(temperature: 50, at: start.addingTimeInterval(64), enabled: false) == nil) }())
        #expect({ (gate.report(temperature: 60, at: start.addingTimeInterval(66), enabled: true) != nil) }())
    }

    @Test("Only consecutive identical process snapshots collapse")
    func compactHistory() {
        let lines = AnomalyGate.compact([("a", "idle"), ("b", "idle"), ("c", "worker"), ("d", "idle")])
        #expect(lines == ["  a → b: idle (×2)", "  c: worker", "  d: idle"])
    }

    @Test("Five seconds of cold must be continuous at different polling rates", arguments: [0.01, 0.1, 0.5, 1.0])
    func coldStreak(interval: Double) {
        var gate = FanOffGate()
        let ticks = Int((5 / interval).rounded())
        for _ in 0..<(ticks - 1) { #expect({ (!gate.ready(cold: true, interval: interval)) }()) }
        #expect({ (gate.ready(cold: true, interval: interval)) }())
        #expect({ (!gate.ready(cold: false, interval: interval)) }())
        #expect({ (!gate.ready(cold: true, interval: interval)) }())
    }

    @Test("UI cadence handles clock rollback, profile reselection and immediate safety transitions")
    func displayCadence() {
        var gate = StatusPushGate()
        let t = Date(timeIntervalSince1970: 1000)
        #expect({ (gate.shouldPush(at: t, profileID: "silent", state: .idle)) }())
        #expect({ (!gate.shouldPush(at: t.addingTimeInterval(0.5), profileID: "silent", state: .idle)) }())
        #expect({ (gate.shouldPush(at: t.addingTimeInterval(0.6), profileID: "silent", state: .safetyOverride)) }())
        #expect({ (gate.shouldPush(at: t.addingTimeInterval(-1), profileID: "silent", state: .safetyOverride)) }())
        gate.reset()
        #expect({ (gate.shouldPush(at: t, profileID: "silent", state: .safetyOverride)) }())
    }

    @Test("Smart and ordinary curves ignore a brief cold dip, but sustained cold releases", arguments: [FanProfile.smart, .balanced])
    func controlLoopColdConfirmation(profile: FanProfile) {
        let f = ControlFixture()
        let monitor = f.monitor(profile)
        var commands: [FanCommand] = []
        monitor.onFanCommand = { commands.append($0) }
        f.smc.temperature = 65
        f.tick(monitor, count: 100)
        #expect(commands.contains { $0.isHold })
        f.smc.temperature = 49
        f.tick(monitor, count: 20)
        #expect(!commands.contains(.resetAuto))
        f.smc.temperature = 65
        f.tick(monitor)
        f.smc.temperature = 49
        f.tick(monitor, count: 70)
        #expect(commands.last == .resetAuto)
    }
}
