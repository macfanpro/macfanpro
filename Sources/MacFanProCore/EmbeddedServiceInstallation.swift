import Darwin
import Foundation

/// Rules shared by the GUI and the privileged CLI. No environment variable or
/// user-selected path can redirect the graphical installer to another bundle.
public enum EmbeddedServiceInstallation {
    public static let appPath = "/Applications/MacFanPro.app"
    public static let helperRelativePath = "Contents/Helpers/macfanpro"
    public static let helperPath = appPath + "/" + helperRelativePath
    public static let homebrewPaths = ["/opt/homebrew/opt/macfanpro", "/usr/local/opt/macfanpro"]

    public enum Failure: String, Error, LocalizedError {
        case location, account, homebrew, identity, newerService, otherOwner, manualHold, unsafePath, busy
        public var errorDescription: String? { "MacFanPro service setup: \(rawValue)." }
    }

    public static func validateOwner(_ uid: UInt32) throws {
        guard uid > 0, uid != UInt32.max, let account = getpwuid(uid),
              account.pointee.pw_dir != nil else { throw Failure.account }
    }

    public static func validateBundle(_ bundle: URL, executable: URL, version: String) throws {
        guard bundle.standardizedFileURL.path == appPath,
              bundle.resolvingSymlinksInPath().path == appPath,
              executable.standardizedFileURL.path == helperPath,
              executable.resolvingSymlinksInPath().path == helperPath else { throw Failure.location }
        let info = NSDictionary(contentsOf: bundle.appendingPathComponent("Contents/Info.plist"))
        guard info?["CFBundleIdentifier"] as? String == "io.github.macfanpro.app",
              info?["CFBundleShortVersionString"] as? String == version else { throw Failure.identity }
    }

    public static func verifySignature() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appPath]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure.identity }
    }

    /// Check the recorded service owner, even when the daemon is offline. Never
    /// silently move a different login user's control socket to this account.
    public static func validateExistingPlist(_ data: Data?, owner: UInt32) throws {
        guard let data else { return }
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              plist["Label"] as? String == MacFanProDaemon.label,
              let arguments = plist["ProgramArguments"] as? [String],
              arguments.count == 4, arguments[0] == MacFanProDaemon.installPath,
              arguments[1] == "daemon", arguments[2] == "--owner-uid",
              UInt32(arguments[3]) == owner else { throw Failure.otherOwner }
    }

    public static func validateLiveService(version: String?, target: String, state: DaemonHoldState?) throws {
        if let version, MacFanProVersion.isNewerRelease(version, than: target) { throw Failure.newerService }
        // Replacing a daemon cannot preserve a live unsupervised hold atomically.
        // Require the user to explicitly finish it instead of silently resetting it.
        if state?.isCLIHold == true { throw Failure.manualHold }
    }

    /// Require root-owned, non-writable ancestors before staging any root executable.
    /// Does not follow directory symlinks (including a substituted /usr/local/bin).
    public static func validateDirectory(_ directory: URL) throws {
        var current = directory.standardizedFileURL
        while current.path != "/" {
            var metadata = stat()
            guard lstat(current.path, &metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFDIR,
                  metadata.st_uid == 0, metadata.st_mode & 0o022 == 0 else { throw Failure.unsafePath }
            current.deleteLastPathComponent()
        }
    }
}

/// Serialize service mutations, including legacy CLI installs, across processes.
/// The lock lives in the root-owned runtime directory and is never unlinked.
public final class ServiceInstallationLock {
    private let descriptor: Int32
    public init() throws {
        descriptor = open("/var/run/macfanpro-install.lock", O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw EmbeddedServiceInstallation.Failure.unsafePath }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0, metadata.st_uid == 0,
              metadata.st_mode & S_IFMT == S_IFREG, metadata.st_nlink == 1,
              metadata.st_mode & 0o077 == 0 else {
            close(descriptor); throw EmbeddedServiceInstallation.Failure.unsafePath
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor); throw EmbeddedServiceInstallation.Failure.busy
        }
    }
    deinit { flock(descriptor, LOCK_UN); close(descriptor) }
}

/// An in-memory snapshot avoids leaving privileged executable backups in /tmp.
/// Production paths are constants; injected paths are only used by isolated tests.
public struct ServiceFileSnapshot {
    private let entries: [(URL, Data?, Int)]
    public init() throws {
        for path in [MacFanProDaemon.installPath, MacFanProDaemon.plistPath] {
            var metadata = stat()
            if lstat(path, &metadata) == 0 {
                guard metadata.st_uid == 0, metadata.st_mode & 0o022 == 0 else {
                    throw EmbeddedServiceInstallation.Failure.unsafePath
                }
            }
        }
        try self.init(paths: [(URL(fileURLWithPath: MacFanProDaemon.installPath), 0o755),
                              (URL(fileURLWithPath: MacFanProDaemon.plistPath), 0o644)])
    }
    init(paths: [(URL, Int)]) throws {
        entries = try paths.map { url, mode in
            var metadata = stat()
            if lstat(url.path, &metadata) != 0 {
                guard errno == ENOENT else { throw CocoaError(.fileReadUnknown) }
                return (url, nil, mode)
            }
            guard metadata.st_mode & S_IFMT == S_IFREG else { throw EmbeddedServiceInstallation.Failure.unsafePath }
            return (url, try Data(contentsOf: url), Int(metadata.st_mode & 0o777))
        }
    }
    public func restore() throws {
        for (url, data, mode) in entries {
            if let data {
                try Self.replace(url, data: data, mode: mode)
            } else if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
    public struct RollbackFailure: Error, LocalizedError {
        let details: String
        public var errorDescription: String? { details }
    }

    /// Restore files even if launchd refuses to stop the current job. Report all
    /// failures, and never bootstrap a second job when stopping the first failed.
    public func restoreService(stop: () throws -> Void, start: () throws -> Void) throws {
        var failures: [String] = []
        do { try stop() } catch { failures.append("stop: \(error)") }
        do { try restore() } catch { failures.append("files: \(error)") }
        if failures.isEmpty {
            do { try start() } catch { failures.append("start: \(error)") }
        }
        if !failures.isEmpty { throw RollbackFailure(details: failures.joined(separator: "; ")) }
    }

    /// Create the temporary file with final permissions before writing its bytes.
    /// Atomic replacement never follows an existing destination symlink.
    public static func replace(_ url: URL, data: Data, mode: Int) throws {
        let temp = url.deletingLastPathComponent().appendingPathComponent(".macfanpro-\(UUID().uuidString)")
        let fd = open(temp.path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, mode_t(mode))
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temp) }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        guard fchmod(fd, mode_t(mode)) == 0, rename(temp.path, url.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
