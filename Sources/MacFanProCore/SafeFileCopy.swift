// Adapted from ThermalForge 42bb534. See NOTICE.md.
import Darwin
import Foundation

/// Copy one regular file so that what gets written is exactly the file that was
/// checked. The source is opened once, without following a symlink; the checks run
/// on that open handle, and the bytes come from it too. A
/// swap of the path after the check can't change what's copied.
public enum SafeFileCopy {

    public enum Failure: Error, Equatable, CustomStringConvertible, LocalizedError {
        case cannotOpen(path: String, errno: Int32)
        case notRegularFile(path: String)
        case notExecutable(path: String)
        case cannotCreate(path: String, errno: Int32)
        case ioFailed(path: String, errno: Int32)

        public var errorDescription: String? { description }

        public var description: String {
            switch self {
            case .cannotOpen(let path, let err):
                return "couldn't open \(path): \(Self.reason(err))"
            case .notRegularFile(let path):
                return "\(path) isn't a regular file (a symlink, folder or other special file is never installed)"
            case .notExecutable(let path):
                return "\(path) isn't executable"
            case .cannotCreate(let path, let err):
                return "couldn't create \(path): \(Self.reason(err))"
            case .ioFailed(let path, let err):
                return "couldn't write \(path): \(Self.reason(err))"
            }
        }

        private static func reason(_ err: Int32) -> String {
            "\(String(cString: strerror(err))) (errno \(err))"
        }
    }

    public static func copyRegularFile(from source: String, to dest: String,
                                       requireExecutable: Bool = false, permissions: mode_t? = nil) throws {
        // O_NOFOLLOW: a symlink at `source` fails here instead of being followed.
        // O_NONBLOCK: a FIFO planted at `source` can't stall the open; it fails the
        // regular-file check below instead.
        let input = open(source, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard input >= 0 else {
            let err = errno
            throw err == ELOOP ? Failure.notRegularFile(path: source) : Failure.cannotOpen(path: source, errno: err)
        }
        defer { close(input) }

        var info = stat()
        guard fstat(input, &info) == 0 else { throw Failure.cannotOpen(path: source, errno: errno) }
        guard (info.st_mode & S_IFMT) == S_IFREG else { throw Failure.notRegularFile(path: source) }
        if requireExecutable && (info.st_mode & 0o111) == 0 { throw Failure.notExecutable(path: source) }

        // O_EXCL: never write through or over anything already at `dest`.
        let output = open(dest, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard output >= 0 else { throw Failure.cannotCreate(path: dest, errno: errno) }
        var finished = false
        defer {
            close(output)
            if !finished { unlink(dest) }
        }

        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let n = buffer.withUnsafeMutableBytes { read(input, $0.baseAddress, $0.count) }
            if n == 0 { break }
            if n < 0 {
                if errno == EINTR { continue }
                throw Failure.ioFailed(path: dest, errno: errno)
            }
            var written = 0
            while written < n {
                let w = buffer.withUnsafeBytes { write(output, $0.baseAddress! + written, n - written) }
                if w <= 0 {
                    if w < 0 && errno == EINTR { continue }
                    throw Failure.ioFailed(path: dest, errno: errno)
                }
                written += w
            }
        }

        // Keep the creator as owner. A privileged install must never briefly
        // hand its staged root executable to the owner of a Homebrew source.
        guard fchmod(output, permissions ?? (info.st_mode & 0o777)) == 0 else {
            throw Failure.ioFailed(path: dest, errno: errno)
        }
        finished = true
    }
}
