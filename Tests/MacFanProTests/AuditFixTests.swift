import Foundation
import Testing
@testable import MacFanProApp
@testable import MacFanProCore

@Suite("Profile switch ordering and calibration paths — no hardware writes")
struct AuditFixTests {
    @Test("During Default only the reset passes, until the monitor confirms the switch")
    func defaultHoldsStaleWrites() {
        var gate = ProfileSwitchGate()
        let press = gate.defaultPressed()
        for stale in [FanCommand.setRPM(3000), .setFan(index: 0, rpm: 3000), .setMax] {
            #expect(!gate.allows(stale))
        }
        #expect(gate.allows(.resetAuto))
        let applied = gate.resetFinished(press, ok: true)
        #expect(applied)
        // The old profile's writes, queued on the monitor before the switch, arrive
        // before its confirmation and are still dropped.
        #expect(!gate.allows(.setMax))
        gate.switchApplied(press)
        // Silent's own first safety max, issued after the switch, passes.
        #expect(gate.allows(.setMax))
    }

    @Test("A profile picked while Default is in flight wins over its late result")
    func newerPickWins() {
        var gate = ProfileSwitchGate()
        let press = gate.defaultPressed()
        _ = gate.picked(handsOff: false)
        #expect(gate.allows(.setRPM(3000)))
        let applied = gate.resetFinished(press, ok: true)
        #expect(!applied)
        #expect(gate.allows(.setRPM(3000)))
    }

    @Test("Only the latest Default press applies its result")
    func latestPressApplies() {
        var gate = ProfileSwitchGate()
        let first = gate.defaultPressed()
        let second = gate.defaultPressed()
        let firstApplied = gate.resetFinished(first, ok: true)
        let secondApplied = gate.resetFinished(second, ok: true)
        #expect(!firstApplied)
        #expect(secondApplied)
    }

    @Test("A failed reset leaves the current profile running")
    func failedResetReopens() {
        var gate = ProfileSwitchGate()
        let press = gate.defaultPressed()
        let applied = gate.resetFinished(press, ok: false)
        #expect(applied)
        #expect(gate.allows(.setRPM(3000)))
    }

    @Test("Picking Silent holds the old profile's writes until its own switch is confirmed")
    func silentPick() {
        var gate = ProfileSwitchGate()
        let first = gate.picked(handsOff: true)
        let second = gate.picked(handsOff: true)
        #expect(!gate.allows(.setRPM(3000)))
        #expect(gate.allows(.resetAuto))
        // The earlier pick's confirmation doesn't open the gate for the newer one.
        gate.switchApplied(first)
        #expect(!gate.allows(.setMax))
        gate.switchApplied(second)
        #expect(gate.allows(.setMax))
    }

    @Test("Under sudo, calibration resolves the invoking user's home")
    func sudoUserHome() throws {
        let uid = getuid()
        try #require(uid != 0, "Tests must not run as root")
        let account = try #require(getpwuid(uid))
        let home = String(cString: account.pointee.pw_dir)

        let user = try #require(CalibrationData.invokingUser(euid: 0, environment: ["SUDO_UID": "\(uid)"]))
        #expect(user.uid == uid)
        #expect(user.gid == account.pointee.pw_gid)
        #expect(user.home.path == home)
    }

    @Test("Without sudo, or with a root or malformed SUDO_UID, calibration keeps the current home")
    func noInvokingUser() {
        #expect(CalibrationData.invokingUser(euid: getuid(), environment: ["SUDO_UID": "\(getuid())"]) == nil)
        #expect(CalibrationData.invokingUser(euid: 0, environment: [:]) == nil)
        #expect(CalibrationData.invokingUser(euid: 0, environment: ["SUDO_UID": "0"]) == nil)
        #expect(CalibrationData.invokingUser(euid: 0, environment: ["SUDO_UID": "abc"]) == nil)
        #expect(CalibrationData.filePath.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path))
    }

    @Test("A result that fails validation is not saved and the previous file is kept")
    func invalidResultKeepsPreviousFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("macfanpro-cal-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("calibration.json")

        func result(_ measurements: [CalibrationData.Measurement]) -> CalibrationData {
            CalibrationData(machine: "Test1,1", fans: 2, maxRPM: 7826, minRPM: 2317,
                            calibratedAt: "2026-09-27T00:00:00Z", mode: "quick", measurements: measurements)
        }
        let valid = result([.init(targetTemp: 60, holdingRPMPercent: 0.3),
                            .init(targetTemp: 80, holdingRPMPercent: 0.7)])
        try valid.save(to: url)
        let saved = try Data(contentsOf: url)

        let invalid = [
            result([]),
            result([.init(targetTemp: 60, holdingRPMPercent: 1.5)]),
            result([.init(targetTemp: 60, holdingRPMPercent: 0.8),
                    .init(targetTemp: 80, holdingRPMPercent: 0.3)]),
        ]
        for data in invalid {
            let reason = try #require(data.validationError)
            #expect(throws: CalibrationData.InvalidResult.self) { try data.save(to: url) }
            do { try data.save(to: url) } catch let error as CalibrationData.InvalidResult {
                #expect(error.reason == reason)
            }
            #expect(try Data(contentsOf: url) == saved)
        }

        // With no previous file, nothing is created either.
        let fresh = dir.appendingPathComponent("fresh/calibration.json")
        #expect(throws: CalibrationData.InvalidResult.self) { try result([]).save(to: fresh) }
        #expect(!FileManager.default.fileExists(atPath: fresh.path))
    }
}
