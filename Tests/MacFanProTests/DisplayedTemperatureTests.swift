import Foundation
import Testing
@testable import MacFanProCore

@Suite("Displayed CPU temperature — cores, not hotspot keys")
struct DisplayedTemperatureTests {
    private func status(_ temps: [String: Float]) -> ThermalStatus {
        ThermalStatus(fans: [], temperatures: temps)
    }

    // Captured together on Mac16,5 (M4 Max) during a Metal-only load, while
    // Stats showed hottest CPU 62.3 and hottest GPU 68.7.
    private let m4GPULoad: [String: Float] = [
        "TCDX": 73.1, "TCMb": 71.7,
        "Tp06": 75.2, "Tp02": 67.6, "Tp0A": 67.2,
        "Tp01": 61.3, "Tp05": 60.4, "Tp09": 61.9, "Tp0D": 62.3, "Tp0b": 59.8, "Tp0e": 60.1,
        "Te05": 61.4, "Te0S": 62.0,
        "Tg05": 69.0, "Tg0L": 63.2,
    ]

    @Test("On M4 the CPU row reads the core keys, not Tp06 or TCDX")
    func m4GPULoadMatchesStats() {
        let s = status(m4GPULoad)
        #expect(s.cpuTemp(coreKeys: ThermalStatus.m4CoreKeys) == 62.3)
        // Fan control and the safety floor still see the hotspot, as upstream.
        #expect(s.safetyPeakTemp == 75.2)
    }

    @Test("CPU display falls back through prefixes and aggregates when core keys are unavailable")
    func cpuFallbacks() {
        let cases: [(reason: String, temps: [String: Float], coreKeys: Set<String>, expected: Float)] = [
            ("No key table", m4GPULoad, [], 75.2),
            ("Table keys absent", ["Tp0X": 58.0, "TCDX": 70.0], ThermalStatus.m4CoreKeys, 58.0),
            ("Only aggregate CPU keys", ["TCDX": 55.0, "Tg05": 50.0], ThermalStatus.m4CoreKeys, 55.0),
        ]
        for row in cases {
            #expect(status(row.temps).cpuTemp(coreKeys: row.coreKeys) == row.expected, "\(row.reason)")
        }
    }

    @Test("Headline is the hotter displayed row")
    func headline() {
        let s = status(["Tp01": 61.3, "Tg05": 69.0, "TCDX": 80.0])
        let cpu = s.displayedCPUTemp ?? 0
        #expect(s.displayedPeakTemp == max(cpu, 69.0))
    }

    @Test("M4 efficiency cores participate in both the monitor and daemon safety floor")
    func efficiencyCoreSafety() {
        for key in ["Te05", "Te0S", "Te09", "Te0H"] {
            #expect(FanControl.safetyTempKeys.contains(key))
            let s = status([key: 96, "Tp01": 70, "TCDX": 75, "Tg05": 65])
            #expect(s.safetyPeakTemp == 96)
        }
        let f = ControlFixture(sample: { nil })
        f.smc.set("Te05", floatToSMCBytes(96))
        let monitor = f.monitor(.silent)
        var commands: [FanCommand] = []
        monitor.onFanCommand = { commands.append($0) }
        f.tick(monitor)
        #expect(commands == [.setMax])
        // Use the actual key sweep, not the fixture's injected peak sampler.
        let daemon = DaemonServer(fanControl: f.fans, ownerUID: getuid(), sampleMaxTemp: nil, socketFD: nil, now: f.clock.now)
        #expect(daemon.processFrame(try! JSONEncoder().encode(DaemonRequest(verb: .set, rpm: 2000, oneshot: true))).ok)
        daemon.thermalTick()
        #expect(f.smc.float("F0Tg") == 6000)
    }

    @Test("No CPU or GPU sensors leaves the rows and headline empty")
    func empty() {
        let s = status(["TH0x": 31.0, "TAOL": 25.0])
        #expect(s.displayedCPUTemp == nil)
        #expect(s.displayedGPUTemp == nil)
        #expect(s.displayedPeakTemp == nil)
    }
}
