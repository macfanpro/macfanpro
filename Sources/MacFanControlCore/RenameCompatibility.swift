import Foundation

/// Installed-version contracts. Keep these aliases while older update scripts
/// verify the old application path after installing the new release.
public enum RenameCompatibility {
    public static let oldAppPath = "/Applications/MacFanPro.app"
    public static let commandPath = "/usr/local/bin/macfancontrol"
    public static let appProcessPattern = "(MacFanControlApp|MacFanProApp)"

    /// Called only after the new service and application have committed. Never
    /// remove an unrelated application or replace it with a dangling alias.
    public static func finish(app: URL, oldApp: URL, command: URL, service: URL,
                              hide: (URL) throws -> Void = { _ in }) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: app.path), fm.isExecutableFile(atPath: service.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let resolvedCommand = command.resolvingSymlinksInPath()
        let homebrewCommand = ["/opt/homebrew/Cellar/macfancontrol/", "/usr/local/Cellar/macfancontrol/"]
            .contains { resolvedCommand.path.hasPrefix($0) && resolvedCommand.path.hasSuffix("/bin/macfancontrol") }
        if resolvedCommand != service.resolvingSymlinksInPath(), !homebrewCommand,
           (try? fm.attributesOfItem(atPath: command.path)) != nil {
            throw CocoaError(.fileWriteFileExists)
        }
        if oldApp.resolvingSymlinksInPath() != app.resolvingSymlinksInPath(),
           fm.fileExists(atPath: oldApp.path) {
            let info = NSDictionary(contentsOf: oldApp.appendingPathComponent("Contents/Info.plist"))
            guard info?["CFBundleIdentifier"] as? String == "io.github.macfanpro.app" else {
                throw CocoaError(.fileWriteFileExists)
            }
        }
        let backup = oldApp.deletingLastPathComponent().appendingPathComponent(".MacFanPro-migration-\(UUID().uuidString)")
        let existed = (try? fm.attributesOfItem(atPath: oldApp.path)) != nil
        if existed { try fm.moveItem(at: oldApp, to: backup) }
        do {
            try fm.createSymbolicLink(at: oldApp, withDestinationURL: app)
            try hide(oldApp)
        } catch {
            try? fm.removeItem(at: oldApp)
            if existed { try fm.moveItem(at: backup, to: oldApp) }
            throw error
        }
        // The original app has a recoverable copy until alias creation succeeds.
        if existed { try fm.removeItem(at: backup) }
        if !homebrewCommand && command.resolvingSymlinksInPath() != service.resolvingSymlinksInPath() {
            // Do not overwrite another program that happens to use the new name.
            guard (try? fm.attributesOfItem(atPath: command.path)) == nil else {
                throw CocoaError(.fileWriteFileExists)
            }
            try fm.createSymbolicLink(at: command, withDestinationURL: service)
        }
    }
}
