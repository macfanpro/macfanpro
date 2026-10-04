import Foundation

/// Clear an installed bundle's extended attributes without following symlinks
/// outside it. Uses the system tools, independent of the caller's PATH.
public enum AppBundleAttributes {
    struct CleanupError: LocalizedError {
        let path: String
        let status: Int32

        var errorDescription: String? {
            "Could not clear extended attributes in \(path) (exit \(status))."
        }
    }

    public static func clear(in bundle: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        // find's default traversal does not follow symlinks. xattr -s also acts
        // on the link itself, so neither layer reaches a link's external target.
        process.arguments = [bundle.path, "-exec", "/usr/bin/xattr", "-cs", "{}", "+"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw CleanupError(path: bundle.path, status: process.terminationStatus)
        }
    }
}
