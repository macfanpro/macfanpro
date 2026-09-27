import Foundation
import Testing
@testable import MacFanProApp
@testable import MacFanProCore

@Suite("Default and calibration fixes — no hardware writes")
struct AuditFixTests {
    @Test("Only curve ramp writes are dropped after Default; max and reset always pass")
    func rampWrites() {
        #expect(AppState.isRampWrite(.setRPM(3000)))
        #expect(AppState.isRampWrite(.setFan(index: 0, rpm: 3000)))
        #expect(!AppState.isRampWrite(.setMax))
        #expect(!AppState.isRampWrite(.resetAuto))
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
