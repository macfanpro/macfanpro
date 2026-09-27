import Foundation
import Testing
@testable import MacFanProApp
@testable import MacFanProCore

@Suite("Profile switch ordering and calibration paths — no hardware writes")
struct AuditFixTests {
    @Test("During Default only the reset passes, until the monitor runs Silent")
    func defaultHoldsStaleWrites() {
        var gate = ProfileSwitchGate()
        let press = gate.defaultPressed()
        for stale in [FanCommand.setRPM(3000), .setFan(index: 0, rpm: 3000), .setMax] {
            #expect(!gate.allows(stale))
        }
        #expect(gate.allows(.resetAuto))
        let applied = gate.resetFinished(press, ok: true)
        #expect(applied)
        // A report from the old profile, queued before the switch, keeps the gate shut.
        gate.monitorReported(handsOff: false)
        #expect(!gate.allows(.setMax))
        gate.monitorReported(handsOff: true)
        // Silent's own safety max passes once the monitor has switched.
        #expect(gate.allows(.setMax))
    }

    @Test("A profile picked while Default is in flight wins over its late result")
    func newerPickWins() {
        var gate = ProfileSwitchGate()
        let press = gate.defaultPressed()
        gate.picked(handsOff: false)
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
        #expect(!firstApplied)
        let secondApplied = gate.resetFinished(second, ok: true)
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

    @Test("Picking Silent holds the old profile's writes until the monitor switches")
    func silentPick() {
        var gate = ProfileSwitchGate()
        gate.picked(handsOff: true)
        #expect(!gate.allows(.setRPM(3000)))
        #expect(gate.allows(.resetAuto))
        gate.monitorReported(handsOff: true)
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
}
