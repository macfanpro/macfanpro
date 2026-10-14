import Foundation

/// Clear an installed bundle's extended attributes without following symlinks
/// outside it. Uses the system tools, independent of the caller's PATH.
public enum AppBundleAttributes {
    struct CleanupError: LocalizedError {
        let path: String
        let status: Int32
        let output: String

        var errorDescription: String? {
            "Could not clear extended attributes in \(path) (\(SystemTools.exitDetail(tool: "find/xattr", status: status, output: output)))."
        }
    }

    public static func clear(in bundle: URL) throws {
        // find's default traversal does not follow symlinks. xattr -s also acts
        // on the link itself, so neither layer reaches a link's external target.
        switch SystemTools.run("/usr/bin/find", [bundle.path, "-exec", "/usr/bin/xattr", "-cs", "{}", "+"]) {
        case .exited(0, _): break
        case .exited(let status, let output):
            throw CleanupError(path: bundle.path, status: status, output: output)
        case .notLaunched(let reason):
            throw CleanupError(path: bundle.path, status: -1, output: reason)
        }
    }
}
