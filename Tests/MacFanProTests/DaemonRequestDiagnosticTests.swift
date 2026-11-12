import Foundation
import Testing
@testable import MacFanProCore

@Suite("Explicit speed diagnostics — simulated SMC")
struct DaemonRequestDiagnosticTests {
    @Test("A CLI target is recorded after a sampled app ramp, including repeated CLI changes")
    func cliTargetsSurviveFanLogGate() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacFanPro.Diagnostic.\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        var fanLines: [String] = []
        let logger = TFLogger(directory: root, append: { data, _ in fanLines.append(String(decoding: data, as: UTF8.self)) })
        let smc = SimulatedSMC(maxima: [6000, 4000])
        let fans = FanControl(smc: smc.connection, logger: logger)
        var requests: [String] = []
        let daemon = DaemonServer(fanControl: fans, ownerUID: getuid(), sampleMaxTemp: { 50 },
                                  socketFD: nil, now: Date.init, requestLog: { requests.append($0) })
        func send(_ request: DaemonRequest) throws -> DaemonResponse {
            daemon.processFrame(try JSONEncoder().encode(request))
        }
        #expect(try send(.init(verb: .set, rpm: 2000)).ok)
        #expect(logger.flush())
        let initial = fanLines.count
        for rpm in [3000, 3500] {
            let response = try send(.init(verb: .set, rpm: rpm, oneshot: true))
            #expect(response.ok)
            #expect(smc.float("F0Tg") == Float(rpm))
            #expect(smc.float("F1Tg") == Float(rpm))
            #expect(requests.last?.contains("fan 0=\(rpm) RPM") == true)
            #expect(requests.last?.contains("fan 1=\(rpm) RPM") == true)
        }
        #expect(logger.flush())
        #expect(fanLines.count == initial) // Reproduce the low-level quiet window.
        let clamped = try send(.init(verb: .setfan, rpm: 5000, fan: 1, oneshot: true))
        #expect(clamped.ok)
        #expect(smc.float("F1Tg") == 4000)
        #expect(requests.last?.contains("requestedFan=1 requestedRPM=5000") == true)
        #expect(requests.last?.contains("fan 1=4000 RPM") == true)
        #expect(requests.last?.contains("clamped") == true)
        let count = requests.count
        #expect(try send(.init(verb: .heartbeat)).ok)
        #expect(try send(.init(verb: .state)).ok)
        #expect(requests.count == count)
    }

    @Test("Thermally queued targets are labelled as accepted, with the safety advisory retained")
    func suspendedTargets() throws {
        let smc = SimulatedSMC(maxima: [6000])
        var lines: [String] = []
        let daemon = DaemonServer(fanControl: FanControl(smc: smc.connection), ownerUID: getuid(),
                                  sampleMaxTemp: { 100 }, socketFD: nil, now: Date.init,
                                  requestLog: { lines.append($0) })
        let initial = daemon.processFrame(try JSONEncoder().encode(DaemonRequest(verb: .set, rpm: 1500)))
        #expect(initial.ok)
        daemon.thermalTick()
        let response = daemon.processFrame(try JSONEncoder().encode(DaemonRequest(verb: .set, rpm: 2000, oneshot: true)))
        #expect(response.ok)
        #expect(smc.float("F0Tg") == 6000)
        #expect(lines.last?.contains("acceptedTargets=[fan 0=2000 RPM]") == true)
        #expect(lines.last?.contains("queued until cooldown") == true)
    }
}
