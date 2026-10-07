import ArgumentParser
import Foundation
import MacFanProCore

/// A first-install migration. Old binaries stay in a root-owned backup and are
/// restored if the new installer fails. User data is copied, never removed.
final class LegacyMigration {
    private static let oldLabel = "com.thermalforge.daemon"
    private static let oldApp = "/Applications/ThermalForge.app"
    private static let oldBinary = "/usr/local/bin/thermalforge"
    private static let oldPlist = "/Library/LaunchDaemons/com.thermalforge.daemon.plist"
    private static let oldSocket = "/var/run/thermalforge.sock"
    private let fm = FileManager.default
    private let uid: Int
    private let backup: URL
    private var saved: [(String, URL)] = []
    private var changedRuntime = false
    private var finished = false
    let appWasRunning: Bool

    static var isPresent: Bool {
        [oldApp, oldBinary, oldPlist].contains { FileManager.default.fileExists(atPath: $0) }
            || registered(oldLabel)
    }

    static func registered(_ label: String) -> Bool {
        (try? run("/bin/launchctl", ["print", "system/\(label)"]).status) == 0
    }

    init(ownerUID: Int) throws {
        uid = ownerUID
        guard try !MacFanProDaemon.registrationStatus(),
              !fm.fileExists(atPath: "/Applications/MacFanPro.app") else {
            throw ValidationError("MacFanPro is already installed. Remove the older ThermalForge installation separately before retrying migration.")
        }
        appWasRunning = (try Self.run("/usr/bin/pgrep", ["-x", "-u", "\(uid)", "ThermalForgeApp"]).status) == 0
        backup = URL(fileURLWithPath: "/Library/Application Support/MacFanPro/Migrations")
            .appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: backup, withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        for path in [Self.oldApp, Self.oldBinary, Self.oldPlist] where fm.fileExists(atPath: path) {
            let destination = backup.appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)
            try fm.copyItem(atPath: path, toPath: destination.path)
            saved.append((path, destination))
        }
        print("ThermalForge migration backup: \(backup.path)")
    }

    func prepare() throws {
        do {
            try migrateUserData()
            changedRuntime = true
            _ = try Self.run("/usr/bin/pkill", ["-x", "-u", "\(uid)", "ThermalForgeApp"])
            Thread.sleep(forTimeInterval: 0.5)
            guard try Self.run("/usr/bin/pgrep", ["-x", "-u", "\(uid)", "ThermalForgeApp"]).status != 0 else {
                throw ValidationError("ThermalForge is still running; quit it before migrating.")
            }
            // The new core contains the checked release path. Do not run a
            // potentially user-replaced legacy executable with root privileges.
            try FanControl().resetAuto()
            if Self.registered(Self.oldLabel) {
                try Self.require("/bin/launchctl", ["bootout", "system/\(Self.oldLabel)"])
            }
            guard !Self.registered(Self.oldLabel) else {
                throw ValidationError("The old ThermalForge daemon did not stop.")
            }
            for (path, _) in saved { try fm.removeItem(atPath: path) }
            unlink(Self.oldSocket)
            unlink("/tmp/thermalforge.sock")
        } catch {
            rollback()
            throw error
        }
    }

    func complete() {
        finished = true
        print("ThermalForge was replaced. Previous files remain at \(backup.path).")
        print("Remove its old Homebrew package with: brew uninstall thermalforge")
    }

    func rollback() {
        guard changedRuntime, !finished else { return }
        finished = true
        do {
            _ = try Self.run("/usr/bin/pkill", ["-x", "-u", "\(uid)", "MacFanProApp"])
            try MacFanProDaemon.bootoutIfRegistered()
            try FanControl().resetAuto()
            for path in [MacFanProDaemon.plistPath, MacFanProDaemon.installPath,
                         "/Applications/MacFanPro.app"] where fm.fileExists(atPath: path) {
                try fm.removeItem(atPath: path)
            }
            unlink(MacFanProDaemon.socketPath)
            for (path, copy) in saved {
                if fm.fileExists(atPath: path) { try fm.removeItem(atPath: path) }
                try fm.copyItem(atPath: copy.path, toPath: path)
            }
            if fm.fileExists(atPath: Self.oldPlist), !Self.registered(Self.oldLabel) {
                try Self.require("/bin/launchctl", ["bootstrap", "system", Self.oldPlist])
            }
            if appWasRunning {
                _ = try Self.run("/bin/launchctl", ["asuser", "\(uid)", "/usr/bin/open", Self.oldApp])
            }
            print("Installation failed; the previous ThermalForge runtime was restored.")
        } catch {
            FileHandle.standardError.write(Data("Rollback needs attention: \(error). Backup: \(backup.path)\n".utf8))
        }
    }

    private func migrateUserData() throws {
        guard let account = getpwuid(uid_t(uid)), let homePointer = account.pointee.pw_dir else {
            throw ValidationError("Cannot resolve the controlling user's home directory.")
        }
        let home = URL(fileURLWithPath: String(cString: homePointer))
        let oldSupport = home.appendingPathComponent("Library/Application Support/ThermalForge")
        let newSupport = home.appendingPathComponent("Library/Application Support/MacFanPro")
        try asUser("/bin/mkdir", ["-p", newSupport.path])
        for name in ["calibration.json", "profiles", "logs"] {
            let source = oldSupport.appendingPathComponent(name)
            let destination = newSupport.appendingPathComponent(name)
            if fm.fileExists(atPath: source.path), !fm.fileExists(atPath: destination.path) {
                try asUser("/bin/cp", ["-R", source.path, destination.path])
            }
        }
        // Copy presentation preferences only; cached upstream update URLs must
        // never carry over into the independent release channel.
        let old = try Self.run("/usr/bin/sudo", ["-u", "#\(uid)", "/usr/bin/defaults", "export", "com.thermalforge.app", "-"])
        guard old.status == 0,
              let oldValues = try PropertyListSerialization.propertyList(from: old.data, format: nil) as? [String: Any] else { return }
        let newDomain = "io.github.macfanpro.app"
        let current = try Self.run("/usr/bin/sudo", ["-u", "#\(uid)", "/usr/bin/defaults", "export", newDomain, "-"])
        let currentValues: [String: Any] = current.status == 0
            ? ((try? PropertyListSerialization.propertyList(from: current.data, format: nil)) as? [String: Any] ?? [:]) : [:]
        let values = LegacyPreferences.merging(old: oldValues, current: currentValues)
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
        let path = backup.appendingPathComponent("preferences.plist")
        try data.write(to: path)
        // stdin carries the plist so the user need not read the root-only backup.
        let imported = try Self.run("/usr/bin/sudo", ["-u", "#\(uid)", "/usr/bin/defaults", "import", newDomain, "-"], input: data)
        guard imported.status == 0 else { throw ValidationError("Could not import GUI preferences.") }
    }

    private func asUser(_ path: String, _ arguments: [String]) throws {
        try Self.require("/usr/bin/sudo", ["-u", "#\(uid)", path] + arguments)
    }

    private static func require(_ path: String, _ arguments: [String]) throws {
        let result = try run(path, arguments)
        guard result.status == 0 else {
            throw ValidationError("\(path) failed (\(result.status)): \(String(decoding: result.data, as: UTF8.self))")
        }
    }

    private static func run(_ path: String, _ arguments: [String], input: Data? = nil) throws -> (status: Int32, data: Data) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let stdin = Pipe()
        if input != nil { process.standardInput = stdin }
        try process.run()
        if let input {
            stdin.fileHandleForWriting.write(input)
            try stdin.fileHandleForWriting.close()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, data)
    }
}
