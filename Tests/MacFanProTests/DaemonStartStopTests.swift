import Foundation
import Testing
@testable import MacFanProCore

/// Startup reconcile and SIGTERM release, adopted from ThermalForge #31. The pure
/// decisions mirror upstream's DaemonLifecycleTests; the daemon cases drive the real
/// DaemonServer against a simulated SMC, so no fan or socket is touched.
@Suite("Daemon start and stop")
struct DaemonStartStopTests {
    private struct SMCUnreadable: Error {}

    @Test("Startup: manual fans are reset, auto fans left alone, unreadable fans reset anyway, a failed reset reported")
    func reconcileDecisions() {
        var resets = 0
        #expect(StartupFanReconcile.run(manualControlEngaged: { true }, resetAuto: { resets += 1 }) == .reset)
        #expect(StartupFanReconcile.run(manualControlEngaged: { false }, resetAuto: { resets += 1 }) == .alreadyAuto)
        #expect(StartupFanReconcile.run(manualControlEngaged: { throw SMCUnreadable() },
                                        resetAuto: { resets += 1 }) == .resetAfterUnreadable)
        #expect(resets == 2)
        let failed = StartupFanReconcile.run(manualControlEngaged: { true }, resetAuto: { throw SMCUnreadable() })
        guard case .resetFailed = failed else { Issue.record("expected resetFailed, got \(failed)"); return }
    }

    @Test("SIGTERM releases fans only when the daemon controls them or owes a release")
    func shutdownReleasesOnlyOwnFans() {
        #expect(DaemonShutdown.releasesFans(holding: true, safetySuspended: false))
        #expect(DaemonShutdown.releasesFans(holding: false, safetySuspended: true))
        #expect(DaemonShutdown.releasesFans(holding: false, safetySuspended: false, releasePending: true))
        #expect(!DaemonShutdown.releasesFans(holding: false, safetySuspended: false))
    }

    @Test("Manual control is detected from any fan mode or Ftst, and an unreadable key throws")
    func manualControlDetection() throws {
        let f = ControlFixture()
        #expect(try !f.fans.manualControlEngaged())
        f.smc.set("F1Md", [1])
        #expect(try f.fans.manualControlEngaged())
        f.smc.set("F1Md", [0])
        f.smc.set("Ftst", [1])
        #expect(try f.fans.manualControlEngaged())
        f.smc.onRead = { $0 != "F0Md" }
        #expect(throws: MacFanProError.self) { try f.fans.manualControlEngaged() }
    }

    @Test("A starting daemon releases fans a killed daemon left manual, and leaves auto fans untouched")
    func startupReleasesLeftoverManualFans() {
        let f = ControlFixture()
        var writes = 0
        f.smc.onWrite = { _, _ in writes += 1; return true }
        f.daemon.reconcileFansAtStartup()
        #expect(writes == 0)

        f.smc.set("Ftst", [1]); f.smc.set("F0Md", [1]); f.smc.set("F1Md", [1])
        f.daemon.reconcileFansAtStartup()
        #expect(f.smc.bytes("F0Md") == [0] && f.smc.bytes("F1Md") == [0] && f.smc.bytes("Ftst") == [0])
        #expect(f.state.command == nil)
    }

    @Test("A failed startup reset is retried by the watchdog instead of being dropped")
    func failedStartupResetIsRetried() {
        let f = ControlFixture()
        f.smc.set("F0Md", [1])
        f.smc.onWrite = { _, _ in false }
        f.daemon.reconcileFansAtStartup()
        #expect(f.smc.bytes("F0Md") == [1])
        f.smc.onWrite = nil
        f.daemon.watchdogTick()
        #expect(f.smc.bytes("F0Md") == [0])
    }

    @Test("SIGTERM releases a held curve, and writes nothing when the daemon holds nothing")
    func shutdownRelease() {
        let held = ControlFixture()
        #expect(held.send(.init(verb: .set, rpm: 3000)).ok)
        #expect(held.smc.bytes("F0Md") == [1])
        #expect(held.daemon.releaseFansForShutdown())
        #expect(held.smc.bytes("F0Md") == [0] && held.smc.bytes("F1Md") == [0])

        let idle = ControlFixture()
        var writes = 0
        idle.smc.onWrite = { _, _ in writes += 1; return true }
        #expect(idle.daemon.releaseFansForShutdown())
        #expect(writes == 0)
    }
}
