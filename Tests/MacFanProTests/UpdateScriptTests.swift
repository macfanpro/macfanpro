import Foundation
import Testing
@testable import MacFanProApp

@Suite("Update in Terminal scripts — generated only, never run")
struct UpdateScriptTests {
    private func syntaxCheck(_ script: String) throws -> Int32 {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("macfanpro-update-\(UUID().uuidString).command")
        defer { try? FileManager.default.removeItem(at: url) }
        try script.write(to: url, atomically: true, encoding: .utf8)
        let zsh = Process()
        zsh.executableURL = URL(fileURLWithPath: "/bin/zsh")
        zsh.arguments = ["-n", url.path]
        try zsh.run()
        zsh.waitUntilExit()
        return zsh.terminationStatus
    }

    @Test("A release-package install downloads, verifies and installs that version")
    func packageScript() throws {
        let script = UpdateScript.contents(version: "1.2.3.4", homebrew: false)
        #expect(script.contains("releases/download/v1.2.3.4"))
        #expect(script.contains("MacFanPro-1.2.3.4-macos-arm64.tar.gz"))
        #expect(script.contains("shasum -a 256 -c SHA256SUMS"))
        #expect(script.contains("sudo \"$CLI\" install"))
        #expect(!script.contains("brew"))
        #expect(try syntaxCheck(script) == 0)
    }

    @Test("A Homebrew install trusts the tap, upgrades and syncs from the keg")
    func homebrewScript() throws {
        let script = UpdateScript.contents(version: "1.2.3.4", homebrew: true)
        #expect(script.contains("\"$BREW\" trust macfanpro/tap"))
        #expect(script.contains("\"$BREW\" upgrade macfanpro"))
        #expect(script.contains("--prefix macfanpro)/bin/macfanpro"))
        #expect(!script.contains("curl -fL"))
        #expect(try syntaxCheck(script) == 0)
    }

    @Test("Both use the system proxy unless one is already set")
    func proxy() {
        for homebrew in [false, true] {
            let script = UpdateScript.contents(version: "1.2.3.4", homebrew: homebrew)
            #expect(script.contains("scutil --proxy"))
            #expect(script.hasPrefix("#!/bin/zsh\n"))
        }
        // For a manual end-to-end run: MACFANPRO_UPDATE_SCRIPT_DIR=... swift test --filter UpdateScriptTests
        if let dir = ProcessInfo.processInfo.environment["MACFANPRO_UPDATE_SCRIPT_DIR"],
           let version = ProcessInfo.processInfo.environment["MACFANPRO_UPDATE_SCRIPT_VERSION"] {
            for homebrew in [false, true] {
                let url = URL(fileURLWithPath: dir).appendingPathComponent(homebrew ? "homebrew.command" : "package.command")
                try? UpdateScript.contents(version: version, homebrew: homebrew).write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
