import Foundation
import Testing
@testable import MacFanProCore

@Suite("Routine diagnostics — no hardware")
struct RoutineLogGateTests {
    @Test("Routine polls are quiet; errors, advisories, CLI commands and release remain visible")
    func requestPolicy() {
        let gate = RoutineLogGate(now: { 100 })
        for verb: DaemonRequest.Verb in [.heartbeat, .version, .state, .status] {
            #expect(!gate.allows(request: .init(verb: verb), response: .init(ok: true)))
            #expect(gate.allows(request: .init(verb: verb), response: .init(ok: false)))
        }
        for verb: DaemonRequest.Verb in [.set, .setfan] {
            #expect(gate.allows(request: .init(verb: verb), response: .init(ok: true)))
            #expect(!gate.allows(request: .init(verb: verb), response: .init(ok: true)))
            #expect(gate.allows(request: .init(verb: verb), response: .init(ok: false)))
            #expect(gate.allows(request: .init(verb: verb), response: .init(ok: true, note: "clamped")))
            #expect(gate.allows(request: .init(verb: verb, oneshot: true), response: .init(ok: true)))
        }
        for verb: DaemonRequest.Verb in [.max, .auto, .autoIfApp] {
            for _ in 0..<2 { #expect(gate.allows(request: .init(verb: verb), response: .init(ok: true))) }
        }
    }

    @Test("Each fan keeps its own first sample and exact 30-second boundary; rollback recovers")
    func cadence() {
        var time: TimeInterval = 100
        let gate = RoutineLogGate(now: { time })
        #expect(gate.allows(key: "fan-0"))
        #expect(gate.allows(key: "fan-1"))
        time = 129.999
        #expect(!gate.allows(key: "fan-0"))
        time = 130
        #expect(gate.allows(key: "fan-0"))
        time = 1
        #expect(gate.allows(key: "fan-0"))
        #expect(!gate.allows(key: "fan-0"))
    }

    @Test("Concurrent handlers share a single admission per window")
    func concurrency() {
        let gate = RoutineLogGate(now: { 100 })
        let lock = NSLock()
        var admitted = 0
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            if gate.allows(key: "set") { lock.lock(); admitted += 1; lock.unlock() }
        }
        #expect(admitted == 1)
    }
}
