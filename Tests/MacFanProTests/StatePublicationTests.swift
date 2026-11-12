import Combine
import Testing
@testable import MacFanProApp
@testable import MacFanProCore

@Suite("State publication — no services", .serialized)
@MainActor
struct StatePublicationTests {
    @Test("Equal sensor snapshots do not publish; RPM, mode, profile and safety changes do")
    func monitorPublication() {
        let app = AppState(startServices: false)
        var publications = 0
        let subscription = app.objectWillChange.sink { publications += 1 }
        defer { subscription.cancel() }
        func snapshot(_ rpm: Int = 2000) -> ThermalStatus {
            .init(fans: [.init(index: 0, actualRPM: rpm, targetRPM: 2000,
                              minRPM: 1000, maxRPM: 6000, mode: "manual")], temperatures: ["Tp01": 60])
        }
        app.applyMonitorUpdate(status: snapshot(), profile: .smart, state: .active(profileName: "Smart"))
        let initial = publications
        #expect(initial > 0)
        app.applyMonitorUpdate(status: snapshot(), profile: .smart, state: .active(profileName: "Smart"))
        #expect(publications == initial)
        app.applyMonitorUpdate(status: snapshot(2100), profile: .smart, state: .safetyOverride)
        #expect(publications > initial)
        #expect(app.latestStatus?.fans.first?.actualRPM == 2100)
        #expect(app.monitorState == .safetyOverride)
        app.applyMonitorUpdate(status: snapshot(2100), profile: .balanced, state: .safetyOverride)
        #expect(app.activeProfile == .balanced)
    }

    @Test("Heartbeat debounce and unreadable advisory state survive publication deduplication")
    func daemonPublication() {
        let app = AppState(startServices: false)
        var publications = 0
        let subscription = app.objectWillChange.sink { publications += 1 }
        defer { subscription.cancel() }
        let hold = DaemonHoldState(command: "set 2000", owner: "cli")
        func apply(_ heartbeat: Bool, readable: Bool = true) {
            app.applyDaemonStatus(didReadVersion: readable, version: readable ? "old" : nil,
                                  didReadState: readable, hold: readable ? hold : nil, heartbeatOK: heartbeat)
        }
        apply(true)
        let initial = publications
        apply(true)
        #expect(publications == initial)
        apply(false, readable: false)
        #expect(!app.daemonUnreachable)
        #expect(app.externalHold == hold)
        #expect(app.daemonVersionMismatch == "old")
        apply(false, readable: false)
        #expect(app.daemonUnreachable)
        let unreachable = publications
        apply(false, readable: false)
        #expect(publications == unreachable)
        apply(true, readable: false)
        #expect(!app.daemonUnreachable)
        app.applyDaemonStatus(didReadVersion: true, version: nil, didReadState: true, hold: nil, heartbeatOK: true)
        #expect(app.externalHold == nil)
        #expect(app.daemonVersionMismatch == nil)
    }
}
