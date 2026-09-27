import Foundation
import IOKit
import Testing
@testable import MacFanProCore

/// All state and failure injection belong to this fixture. No real SMC connection,
/// daemon socket, timers, calibration file or runtime log is used by these tests.
final class ControlFixture: @unchecked Sendable {
    final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var date = Date(timeIntervalSince1970: 10_000)
        func now() -> Date { lock.lock(); defer { lock.unlock() }; return date }
        func advance(_ seconds: TimeInterval) {
            lock.lock(); date.addTimeInterval(seconds); lock.unlock()
        }
    }

    let clock = Clock()
    let smc: SimulatedSMC
    let fans: FanControl
    let daemon: DaemonServer

    init(maxima: [Float] = [6000, 6000], sample: (() -> Float?)? = nil) {
        let smc = SimulatedSMC(maxima: maxima)
        self.smc = smc
        fans = FanControl(smc: smc.connection)
        daemon = DaemonServer(fanControl: fans, ownerUID: getuid(),
                              sampleMaxTemp: sample ?? { smc.temperature }, socketFD: nil, now: clock.now)
    }

    @discardableResult
    func send(_ request: DaemonRequest) -> DaemonResponse {
        daemon.processFrame(try! JSONEncoder().encode(request))
    }
    var state: DaemonHoldState { send(DaemonRequest(verb: .state)).state! }

    func monitor(_ profile: FanProfile, interval: TimeInterval = 0.1) -> ThermalMonitor {
        ThermalMonitor(fanControl: fans, profile: profile, interval: interval, logger: nil,
                       loadCalibration: { nil }, now: clock.now, captureProcesses: { "test" })
    }

    func tick(_ monitor: ThermalMonitor, interval: TimeInterval = 0.1, count: Int = 1) {
        for _ in 0..<count { clock.advance(interval); monitor.pollOnce() }
    }
}

final class SimulatedSMC: @unchecked Sendable {
    private let lock = NSLock()
    private var keys: [String: [UInt8]]
    private var writeHook: ((String, [UInt8]) -> Bool)?

    init(maxima: [Float]) {
        keys = ["FNum": [UInt8(maxima.count)], "Ftst": [0], "TCDX": floatToSMCBytes(70)]
        for (i, maximum) in maxima.enumerated() {
            keys["F\(i)Mn"] = floatToSMCBytes(1000)
            keys["F\(i)Mx"] = floatToSMCBytes(maximum)
            keys["F\(i)Ac"] = floatToSMCBytes(0)
            keys["F\(i)Tg"] = floatToSMCBytes(0)
            keys["F\(i)Md"] = [0]
        }
    }

    var onWrite: ((String, [UInt8]) -> Bool)? {
        get { lock.lock(); defer { lock.unlock() }; return writeHook }
        set { lock.lock(); writeHook = newValue; lock.unlock() }
    }
    func bytes(_ key: String) -> [UInt8]? { lock.lock(); defer { lock.unlock() }; return keys[key] }
    func set(_ key: String, _ value: [UInt8]) { lock.lock(); keys[key] = value; lock.unlock() }
    func float(_ key: String) -> Float { smcBytesToFloat(bytes(key) ?? [], size: 4) }
    var temperature: Float {
        get { float("TCDX") }
        set { set("TCDX", floatToSMCBytes(newValue)) }
    }

    lazy var connection = SMCConnection { [unowned self] input, output in
        let key = String(decoding: (0..<4).map { UInt8((input.key >> (24 - 8 * $0)) & 0xFF) }, as: UTF8.self)
        guard let value = self.bytes(key) else { output.result = 0x84; return kIOReturnSuccess }
        output.result = 0
        switch input.data8 {
        case SMCCommand.readKeyInfo.rawValue:
            output.keyInfo.dataSize = UInt32(value.count)
        case SMCCommand.readBytes.rawValue:
            withUnsafeMutableBytes(of: &output.bytes) { buffer in
                for (i, byte) in value.enumerated() { buffer[i] = byte }
            }
        case SMCCommand.writeBytes.rawValue:
            let data = withUnsafeBytes(of: input.bytes) { Array($0.prefix(value.count)) }
            if self.onWrite?(key, data) == false { output.result = 0x84 }
            else { self.set(key, data) }
        default: break
        }
        return kIOReturnSuccess
    }
}

@Suite("Daemon recovery through the real dispatcher — simulated SMC")
struct DaemonRecoveryTests {
    @Test("R1: a partial multi-fan write invalidates even an existing max hold",
          arguments: [true, false], [true, false])
    func partialWrite(oneshot: Bool, resetAlsoFails: Bool) {
        let f = ControlFixture()
        #expect(f.send(.init(verb: .max, oneshot: oneshot)).ok)
        f.smc.onWrite = { key, bytes in
            if key == "F1Tg", bytes == floatToSMCBytes(2000) { return false }
            if resetAlsoFails, (key.hasSuffix("Md") || key == "Ftst"), bytes == [0] { return false }
            return true
        }
        #expect(!f.send(.init(verb: .set, rpm: 2000, oneshot: oneshot)).ok)
        #expect(f.state.isEmpty)
        #expect(!f.state.safetySuspended)
        f.smc.temperature = 96
        f.daemon.thermalTick()
        #expect(f.state.command != "max")
        f.smc.onWrite = nil
        f.clock.advance(20)
        f.daemon.watchdogTick()
        for i in 0..<2 { #expect(f.smc.bytes("F\(i)Md") == [0]) }
        #expect(f.smc.bytes("Ftst") == [0])
    }

    @Test("A single-fan request cannot discard another fan's pending recovery")
    func recoveryBeforeNewWrite() {
        let f = ControlFixture()
        #expect(f.send(.init(verb: .max, oneshot: true)).ok)
        f.smc.onWrite = { key, bytes in
            !(key == "F1Tg" && bytes == floatToSMCBytes(2000)) &&
            !((key.hasSuffix("Md") || key == "Ftst") && bytes == [0])
        }
        #expect(!f.send(.init(verb: .set, rpm: 2000, oneshot: true)).ok)
        #expect(!f.send(.init(verb: .setfan, rpm: 3000, fan: 0, oneshot: true)).ok)
        #expect(f.state.isEmpty)
        f.smc.onWrite = nil
        #expect(f.send(.init(verb: .setfan, rpm: 3000, fan: 0, oneshot: true)).ok)
        #expect(f.smc.bytes("F0Md") == [1])
        #expect(f.smc.bytes("F1Md") == [0])
        #expect(f.smc.float("F0Tg") == 3000)
    }

    @Test("R2: watchdog waiting behind a floor engage keeps max until cooldown")
    func floorEngageRacesWatchdog() throws {
        let f = ControlFixture()
        #expect(f.send(.init(verb: .set, rpm: 3000)).ok)
        f.clock.advance(16)
        f.smc.temperature = 96
        let entered = DispatchSemaphore(value: 0), resume = DispatchSemaphore(value: 0)
        let floorDone = DispatchSemaphore(value: 0), watchdogDone = DispatchSemaphore(value: 0)
        let watchdogStarted = DispatchSemaphore(value: 0)
        f.smc.onWrite = { key, bytes in
            if key == "F0Tg", bytes == floatToSMCBytes(6000) {
                entered.signal()
                return resume.wait(timeout: .now() + 3) == .success
            }
            return true
        }
        DispatchQueue.global().async { f.daemon.thermalTick(); floorDone.signal() }
        defer { resume.signal() }
        try #require(entered.wait(timeout: .now() + 2) == .success)
        DispatchQueue.global().async { watchdogStarted.signal(); f.daemon.watchdogTick(); watchdogDone.signal() }
        try #require(watchdogStarted.wait(timeout: .now() + 2) == .success)
        #expect(watchdogDone.wait(timeout: .now() + 0.05) == .timedOut)
        resume.signal()
        try #require(floorDone.wait(timeout: .now() + 2) == .success)
        try #require(watchdogDone.wait(timeout: .now() + 2) == .success)
        f.smc.onWrite = nil
        #expect(f.state.isEmpty && f.state.safetySuspended)
        #expect(f.smc.bytes("F0Md") == [1])
        #expect(f.smc.float("F0Tg") == 6000)
        f.daemon.thermalTick()
        #expect(f.smc.float("F0Tg") == 6000)
        f.smc.temperature = 89
        f.daemon.thermalTick()
        #expect(!f.state.safetySuspended)
        #expect(f.smc.bytes("F0Md") == [0])
    }

    @Test("A heartbeat arriving during watchdog reset cannot resurrect the cleared hold")
    func heartbeatDuringReset() {
        let f = ControlFixture()
        #expect(f.send(.init(verb: .set, rpm: 3000)).ok)
        f.clock.advance(16)
        f.smc.onWrite = { key, bytes in
            if key == "F0Md", bytes == [0] { #expect(f.send(.init(verb: .heartbeat)).ok) }
            return true
        }
        f.daemon.watchdogTick()
        #expect(f.state.isEmpty)
        #expect(f.smc.bytes("F0Md") == [0])
    }

    @Test("The floor revalidates a hold cancelled while temperature was being sampled")
    func cancelledDuringSample() {
        var cancel: (() -> Void)?
        let f = ControlFixture(sample: { cancel?(); return 96 })
        #expect(f.send(.init(verb: .set, rpm: 3000, oneshot: true)).ok)
        cancel = { #expect(f.send(.init(verb: .auto)).ok) }
        f.daemon.thermalTick()
        cancel = nil
        #expect(f.state.isEmpty && !f.state.safetySuspended)
        #expect(f.smc.bytes("F0Md") == [0])
    }

    @Test("A partly failed cooldown restore re-establishes max before retaining suspension")
    func failedRestore() {
        let f = ControlFixture()
        #expect(f.send(.init(verb: .set, rpm: 2000, oneshot: true)).ok)
        f.smc.temperature = 96
        f.daemon.thermalTick()
        f.smc.onWrite = { key, bytes in !(key == "F1Tg" && bytes == floatToSMCBytes(2000)) }
        f.smc.temperature = 89
        f.daemon.thermalTick()
        #expect(f.state.safetySuspended)
        #expect(f.smc.float("F0Tg") == 6000 && f.smc.float("F1Tg") == 6000)
        f.smc.temperature = 96
        f.daemon.thermalTick()
        #expect(f.smc.float("F0Tg") == 6000)
        f.smc.onWrite = nil
        f.smc.temperature = 89
        f.daemon.thermalTick()
        #expect(!f.state.safetySuspended && f.state.command == "set 2000")
        #expect(f.smc.float("F0Tg") == 2000 && f.smc.float("F1Tg") == 2000)
    }

    @Test("A low-speed request during suspension changes only the cooldown target")
    func suspendedRequest() {
        let f = ControlFixture()
        #expect(f.send(.init(verb: .set, rpm: 3000, oneshot: true)).ok)
        f.smc.temperature = 96
        f.daemon.thermalTick()
        let result = f.send(.init(verb: .set, rpm: 2000, oneshot: true))
        #expect(result.ok && result.note?.contains("queued") == true)
        #expect(f.state.safetySuspended && f.state.command == "set 2000")
        #expect(f.smc.float("F0Tg") == 6000)
        f.smc.temperature = 89
        f.daemon.thermalTick()
        #expect(f.smc.float("F0Tg") == 2000)
    }

    @Test("R3: an automatic retry preserves a newer CLI max; explicit auto still releases it")
    func conditionalRelease() {
        let f = ControlFixture()
        #expect(f.send(.init(verb: .set, rpm: 3000)).ok)
        f.smc.onWrite = { key, bytes in !((key.hasSuffix("Md") || key == "Ftst") && bytes == [0]) }
        #expect(!f.send(.init(.releaseAppHold, oneshot: false)).ok)
        f.smc.onWrite = nil
        #expect(f.send(.init(verb: .max, oneshot: true)).ok)
        let retry = f.send(.init(.releaseAppHold, oneshot: false))
        #expect(retry.error == .heldByCLI)
        #expect(f.state.owner == "cli" && f.state.command == "max")
        #expect(f.smc.float("F0Tg") == 6000)
        #expect(f.send(.init(.resetAuto, oneshot: false)).ok)
        #expect(f.state.isEmpty && f.smc.bytes("F0Md") == [0])
    }

    @Test("R6: returned targets equal the writes for either ordering of different fan limits",
          arguments: [[Float(6000), 4000], [4000, 6000]])
    func perFanResponse(maxima: [Float]) throws {
        let f = ControlFixture(maxima: maxima)
        let response = f.send(.init(verb: .set, rpm: 5000, oneshot: true))
        #expect(response.ok)
        let values = try #require(response.appliedFanRPMs)
        #expect(response.appliedRPM == nil)
        #expect(response.note != nil)
        for (i, limit) in maxima.enumerated() {
            #expect(values[i] == FanRPM(index: i, rpm: Int(min(5000, limit))))
            #expect(f.smc.float("F\(i)Tg") == Float(values[i].rpm))
        }
        #expect(try JSONDecoder().decode(DaemonResponse.self, from: JSONEncoder().encode(response)) == response)
        f.smc.temperature = 96
        f.daemon.thermalTick()
        f.smc.temperature = 89
        f.daemon.thermalTick()
        for value in values { #expect(f.smc.float("F\(value.index)Tg") == Float(value.rpm)) }
    }
}

@Suite("Monitor acknowledgement, ramp and retry — simulated time and SMC")
struct MonitorRecoveryTests {
    @Test("An update callback can stop monitoring on the monitor queue")
    func stopFromCallback() {
        let f = ControlFixture()
        let monitor = f.monitor(.silent)
        monitor.onUpdate = { [weak monitor] _, _, _ in monitor?.stop() }
        f.tick(monitor)
    }

    @Test("A failed first direct hold still releases partially acquired fans on cooldown")
    func failedFirstHoldReleases() {
        let f = ControlFixture()
        let monitor = f.monitor(.silent)
        monitor.onFanCommand = { command in
            switch command {
            case .setMax: try f.fans.setMax()
            case .resetAuto: try f.fans.resetAuto()
            default: Issue.record("Unexpected command: \(command)")
            }
        }
        f.smc.onWrite = { key, bytes in !(key == "F1Tg" && bytes == floatToSMCBytes(6000)) }
        f.smc.temperature = 96
        f.tick(monitor)
        #expect(f.smc.bytes("F0Md") == [1])
        #expect(monitor.state != .safetyOverride)
        f.smc.temperature = 49
        f.tick(monitor)
        #expect(f.smc.bytes("F0Md") == [0] && f.smc.bytes("F1Md") == [0])
        #expect(f.smc.bytes("Ftst") == [0])
    }

    @Test("GUI-style pump retry uses daemon ownership even before a CLI state poll")
    func pumpRetryPreservesCLI() throws {
        let f = ControlFixture()
        let monitor = f.monitor(.silent)
        let completed = DispatchSemaphore(value: 0)
        let pump = FanCommandPump { command in f.send(.init(command, oneshot: false)).ok }
        monitor.onFanCommandAsync = { command, finish in
            pump.submit(command == .resetAuto ? .releaseAppHold : command) { ok in
                finish(ok)
                completed.signal()
            }
        }
        f.smc.temperature = 96
        f.tick(monitor)
        try #require(completed.wait(timeout: .now() + 3) == .success)
        f.smc.temperature = 94
        f.tick(monitor)
        #expect(monitor.state == .safetyOverride)
        f.smc.onWrite = { key, bytes in !((key.hasSuffix("Md") || key == "Ftst") && bytes == [0]) }
        f.smc.temperature = 49
        f.tick(monitor)
        try #require(completed.wait(timeout: .now() + 3) == .success)
        f.tick(monitor) // consume failed acknowledgement
        f.smc.onWrite = nil
        #expect(f.send(.init(verb: .max, oneshot: true)).ok)
        f.clock.advance(2)
        f.tick(monitor)
        try #require(completed.wait(timeout: .now() + 3) == .success)
        f.tick(monitor)
        #expect(f.state.isCLIHold && f.state.command == "max")
        #expect(f.smc.float("F0Tg") == 6000)
    }

    @Test("R4: both ramp directions progress at 0.01, 0.1 and 1 second intervals",
          arguments: [0.01, 0.1, 1.0], [FanProfile.balanced, .smart])
    func smallStepsAccumulate(interval: TimeInterval, profile: FanProfile) throws {
        let f = ControlFixture()
        let monitor = f.monitor(profile, interval: interval)
        var targets: [Float] = []
        monitor.onFanCommand = { command in if case .setRPM(let rpm) = command { targets.append(rpm) } }
        f.smc.temperature = 80
        f.tick(monitor, interval: interval, count: Int(40 / interval))
        let high = try #require(targets.last)
        #expect(high > 2000)
        #expect(monitor.state == .active(profileName: profile.name))
        let risingCount = targets.count
        f.smc.temperature = 54
        f.tick(monitor, interval: interval, count: Int(25 / interval))
        #expect(targets.count > risingCount)
        #expect(try #require(targets.last) < high - 500)
    }

    @Test("R5: failed CLI cooldown retries and becomes idle only after success",
          arguments: [FanProfile.balanced, .smart, .silent])
    func synchronousResetRetry(profile: FanProfile) {
        let f = ControlFixture()
        let monitor = f.monitor(profile)
        var resets = 0
        var failReset = true
        monitor.onFanCommand = { command in
            if command == .resetAuto {
                resets += 1
                if failReset { throw MacFanProError.writeFailed("test reset") }
            }
        }
        f.smc.temperature = 96
        f.tick(monitor)
        #expect(monitor.state == .safetyOverride)
        f.smc.temperature = 49
        f.tick(monitor)
        #expect(monitor.state != .idle)
        f.tick(monitor, count: 50)
        #expect(resets >= 2)
        failReset = false
        f.tick(monitor, count: 310)
        let successCount = resets
        #expect(monitor.state == .idle)
        f.tick(monitor, count: 50)
        #expect(resets == successCount)
    }

    @Test("Safety max failure is retried; successful max retains the 95/90 hysteresis")
    func safetyRetry() {
        let f = ControlFixture()
        let monitor = f.monitor(.silent)
        var commands: [FanCommand] = []
        var failures = 1
        monitor.onFanCommand = { command in
            commands.append(command)
            if command == .setMax, failures > 0 { failures -= 1; throw MacFanProError.writeFailed("max") }
        }
        f.smc.temperature = 96
        f.tick(monitor)
        #expect(monitor.state != .safetyOverride)
        // A brief fall below 95 must not cancel the still-unfulfilled max demand.
        f.smc.temperature = 94
        f.tick(monitor, count: 25)
        #expect(monitor.state == .safetyOverride)
        #expect(commands == [.setMax, .setMax])
        f.smc.temperature = 94
        f.tick(monitor, count: 25)
        #expect(commands == [.setMax, .setMax])
        f.smc.temperature = 89
        f.tick(monitor)
        #expect(commands.last == .resetAuto)
        #expect(monitor.state == .idle)
    }

    @Test("A failed reset cannot make a later hot tick trust a stale max state")
    func hotAfterFailedReset() {
        let f = ControlFixture()
        let monitor = f.monitor(.silent)
        var commands: [FanCommand] = []
        monitor.onFanCommand = { command in
            commands.append(command)
            if command == .resetAuto { throw MacFanProError.writeFailed("partial reset") }
        }
        f.smc.temperature = 96
        f.tick(monitor)
        f.smc.temperature = 49
        f.tick(monitor)
        f.smc.temperature = 96
        f.tick(monitor)
        #expect(commands == [.setMax, .resetAuto, .setMax])
    }

    @Test("Async writes are bounded; only an acknowledged reset clears active state")
    func asyncAcknowledgement() throws {
        let f = ControlFixture()
        let monitor = f.monitor(.balanced)
        var pending: [(FanCommand, @Sendable (Bool) -> Void)] = []
        monitor.onFanCommandAsync = { command, completion in pending.append((command, completion)) }
        f.smc.temperature = 96
        f.tick(monitor, count: 20)
        #expect(pending.count == 1)
        #expect(monitor.state == .idle)
        pending.removeFirst().1(true)
        f.smc.temperature = 94
        f.tick(monitor)
        #expect(monitor.state == .safetyOverride)
        f.smc.temperature = 49
        f.tick(monitor)
        #expect(pending.first?.0 == .resetAuto)
        pending.removeFirst().1(false)
        f.tick(monitor, count: 25)
        try #require(pending.count == 1)
        #expect(pending.first?.0 == .resetAuto)
        pending.removeFirst().1(true)
        f.tick(monitor)
        #expect(monitor.state == .idle)
        f.tick(monitor, count: 50)
        #expect(pending.isEmpty)
    }

    @Test("A new profile invalidates a late acknowledgement and its automatic retry")
    func profileCancelsOldCompletion() throws {
        let f = ControlFixture()
        let monitor = f.monitor(.silent)
        var pending: [(FanCommand, @Sendable (Bool) -> Void)] = []
        monitor.onFanCommandAsync = { pending.append(($0, $1)) }
        f.smc.temperature = 96
        f.tick(monitor)
        try #require(pending.count == 1)
        monitor.switchProfile(.balanced)
        f.smc.temperature = 70
        f.tick(monitor)
        pending.removeFirst().1(true)
        f.tick(monitor)
        #expect(monitor.activeProfile == .balanced)
        #expect(monitor.state != .safetyOverride)
        #expect(!pending.contains { $0.0 == .resetAuto })
    }

    @Test("Switching to Smart retains its sustained trigger while keeping the old release obligation")
    func newProfileTiming() {
        let f = ControlFixture()
        let monitor = f.monitor(.balanced)
        var commands: [FanCommand] = []
        monitor.onFanCommand = { commands.append($0) }
        f.smc.temperature = 96
        f.tick(monitor)
        monitor.switchProfile(.smart)
        f.smc.temperature = 60
        f.tick(monitor, count: 50)
        #expect(commands == [.setMax])
        f.tick(monitor, count: 15)
        #expect(commands.count > 1)
        f.smc.temperature = 49
        f.tick(monitor, count: 20)
        #expect(commands.last == .resetAuto)
    }
}
