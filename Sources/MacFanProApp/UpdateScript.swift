// The menu bar and the online entry point share the bundled installer.
import AppKit
import MacFanProCore

enum UpdateScript {
    enum ScriptError: Error { case invalidVersion, missingInstaller }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func contents(version: String, homebrew: Bool, installerPath: String) throws -> String {
        guard version.range(of: #"^[0-9]+(\.[0-9]+){2,3}$"#, options: .regularExpression) != nil,
              !version.contains("\n") else { throw ScriptError.invalidVersion }
        return """
            #!/bin/bash
            set -euo pipefail
            WORK=\(quote(URL(fileURLWithPath: installerPath).deletingLastPathComponent().path))
            trap 'rm -rf -- "$WORK"' EXIT
            trap 'echo "The update did not finish. See the error above." >&2' ERR
            /bin/bash \(quote(installerPath)) --version \(quote(version))\(homebrew ? " --homebrew" : "")
            echo "MacFanPro is up to date. You can close this window."

            """
    }

    static func open(version: String, homebrew: Bool) {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("macfanpro-update-\(UUID().uuidString)")
        do {
            guard let source = Bundle.main.url(forResource: "install", withExtension: "sh") else {
                throw ScriptError.missingInstaller
            }
            try fm.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let installer = directory.appendingPathComponent("install.sh")
            try fm.copyItem(at: source, to: installer)
            let command = directory.appendingPathComponent("MacFanPro Update.command")
            try contents(version: version, homebrew: homebrew, installerPath: installer.path)
                .write(to: command, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: command.path)
            let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            NSWorkspace.shared.open([command], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error {
                    try? fm.removeItem(at: directory)
                    TFLogger.shared.error("Could not open the update script: \(error)")
                }
            }
        } catch {
            try? fm.removeItem(at: directory)
            TFLogger.shared.error("Could not write the update script: \(error)")
        }
    }
}
