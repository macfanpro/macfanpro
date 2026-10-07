// Adapts ThermalForge 42bb534's atomic bundle exchange to MacFanPro's complete
// signed bundles, embedded helper and localization resources. See NOTICE.md.
import Darwin
import Foundation

public enum AppBundleReplacement {
    /// Preparation happens inside a private directory on the destination volume.
    /// A failed copy/validation never removes the installed app. The random 0700
    /// parent also protects a staged bundle after handing it to the login user.
    @discardableResult
    public static func replace(at destination: URL, prepare: (URL) throws -> Void) throws -> String? {
        try Prepared(at: destination, prepare: prepare).commit()
    }

    /// Keep preparation separate from commit so the installer can validate the
    /// entire replacement before stopping or modifying the existing service.
    public final class Prepared {
        public let staged: URL
        private let destination: URL
        private let container: URL
        private var cleanup = true
        private var committed = false

        public init(at destination: URL, prepare: (URL) throws -> Void) throws {
            let fm = FileManager.default
            self.destination = destination.standardizedFileURL
            try fm.createDirectory(at: self.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            var template = Array(self.destination.deletingLastPathComponent()
                .appendingPathComponent(".macfanpro-install-XXXXXX").path.utf8CString)
            guard let pointer = mkdtemp(&template) else { throw AppBundleReplacement.posixError() }
            container = URL(fileURLWithPath: String(cString: pointer), isDirectory: true)
            staged = container.appendingPathComponent(self.destination.lastPathComponent)
            do {
                try prepare(staged)
                var info = stat()
                guard lstat(staged.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
                    throw CocoaError(.fileWriteInvalidFileName)
                }
            } catch {
                try? fm.removeItem(at: container)
                throw error
            }
        }

        deinit { if cleanup { try? FileManager.default.removeItem(at: container) } }

        @discardableResult
        public func commit() throws -> String? {
            guard !committed else { throw CocoaError(.fileWriteFileExists) }
            var info = stat()
            let exists = lstat(destination.path, &info) == 0
            if !exists && errno != ENOENT { throw AppBundleReplacement.posixError() }
            let result = exists ? renamex_np(staged.path, destination.path, UInt32(RENAME_SWAP))
                                : rename(staged.path, destination.path)
            guard result == 0 else { throw AppBundleReplacement.posixError() }
            committed = true
            do { try FileManager.default.removeItem(at: container) }
            catch {
                cleanup = false
                return "New app installed, but the previous bundle could not be removed at \(container.path): \(error.localizedDescription)"
            }
            cleanup = false
            return nil
        }
    }

    /// Called only on our private staging copy. chown uses file descriptors and
    /// never follows links or modifies their targets outside the bundle.
    public static func handOver(_ bundle: URL, uid: uid_t, gid: gid_t) throws {
        let fd = open(bundle.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw posixError() }
        defer { close(fd) }
        try handOver(fd, uid: uid, gid: gid)
    }

    private static func handOver(_ fd: Int32, uid: uid_t, gid: gid_t) throws {
        guard fchown(fd, uid, gid) == 0 else { throw posixError() }
        let copy = dup(fd)
        guard copy >= 0 else { throw posixError() }
        guard let directory = fdopendir(copy) else { close(copy); throw posixError() }
        defer { closedir(directory) }
        while true {
            errno = 0
            guard let entry = readdir(directory) else {
                if errno != 0 { throw posixError() }
                break
            }
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
            }
            if name == "." || name == ".." { continue }
            var info = stat()
            guard fstatat(fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { throw posixError() }
            switch info.st_mode & S_IFMT {
            case S_IFDIR:
                let child = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard child >= 0 else { throw posixError() }
                defer { close(child) }
                try handOver(child, uid: uid, gid: gid)
            case S_IFREG:
                let child = openat(fd, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
                guard child >= 0 else { throw posixError() }
                defer { close(child) }
                guard fstat(child, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
                      fchown(child, uid, gid) == 0 else { throw posixError() }
            case S_IFLNK:
                guard fchownat(fd, name, uid, gid, AT_SYMLINK_NOFOLLOW) == 0 else { throw posixError() }
            default: throw CocoaError(.fileWriteInvalidFileName)
            }
        }
    }

    private static func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

/// A version string alone cannot distinguish a local build from a Homebrew
/// build. Compare the Mach-O build UUID as well: signing and Homebrew stripping
/// change file bytes while retaining this linker-generated build identity.
/// This is a packaging consistency check; signature verification is separate.
public enum AppInstallSource {
    public static func matches(_ bundle: URL, binary: URL, version: String) -> Bool {
        let info = NSDictionary(contentsOf: bundle.appendingPathComponent("Contents/Info.plist"))
        let helper = bundle.appendingPathComponent(EmbeddedServiceInstallation.helperRelativePath)
        var metadata = stat()
        guard info?["CFBundleIdentifier"] as? String == "io.github.macfanpro.app",
              info?["CFBundleShortVersionString"] as? String == version,
              lstat(helper.path, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_mode & 0o111 != 0 else { return false }
        if FileManager.default.contentsEqual(atPath: helper.path, andPath: binary.path) { return true }
        guard let helperID = buildIdentity(helper), let binaryID = buildIdentity(binary) else { return false }
        return helperID == binaryID
    }

    /// MacFanPro ships thin arm64 Mach-O binaries. Parse bounded load commands
    /// directly so end users do not need Xcode/dwarfdump to run the installer.
    static func buildIdentity(_ binary: URL) -> Data? {
        guard let data = try? Data(contentsOf: binary, options: .mappedIfSafe), data.count >= 32 else { return nil }
        func uint32(_ offset: Int) -> UInt32 {
            (0..<4).reduce(0) { $0 | (UInt32(data[offset + $1]) << ($1 * 8)) }
        }
        guard uint32(0) == 0xfeedfacf, uint32(4) == 0x0100000c else { return nil }
        let count = Int(uint32(16)), bytes = Int(uint32(20))
        guard count > 0, count <= 4096, bytes <= data.count - 32 else { return nil }
        var offset = 32
        let end = offset + bytes
        var uuid: Data?
        for _ in 0..<count {
            guard offset <= end - 8 else { return nil }
            let command = uint32(offset), length = Int(uint32(offset + 4))
            guard length >= 8, length % 4 == 0, length <= end - offset else { return nil }
            if command == 0x1b { // LC_UUID
                guard length == 24, uuid == nil else { return nil }
                uuid = data.subdata(in: (offset + 8)..<(offset + 24))
            }
            offset += length
        }
        guard offset == end, let uuid, uuid.contains(where: { $0 != 0 }) else { return nil }
        return data.subdata(in: 4..<12) + uuid // CPU type/subtype and UUID
    }

    public static func verifySignature(of bundle: URL) throws {
        switch SystemTools.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", bundle.path]) {
        case .exited(0, _): break
        case .exited(let status, let output):
            throw Failure(message: SystemTools.exitDetail(tool: "codesign", status: status, output: output))
        case .notLaunched(let reason): throw Failure(message: "codesign did not run: \(reason)")
        }
    }

    public struct Failure: Error, LocalizedError {
        public let message: String
        public init(message: String) { self.message = message }
        public var errorDescription: String? { message }
    }
}
