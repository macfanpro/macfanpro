import Foundation
import Testing
@testable import MacFanProApp
import MacFanProCore

@Suite("Update in Terminal launcher")
struct UpdateScriptTests {
    @Test("A failed Terminal handoff can retry; concurrent and completed handoffs cannot launch twice")
    @MainActor
    func terminalHandoffRecovery() async {
        var attempts: [(String, Bool)] = []
        var completion: CheckedContinuation<Void, Error>?
        let model = UpdateDetailsModel(update: .init(version: "1.2.3.4", url: UpdateChecker.releasesPageURL),
                                       homebrew: true, launch: { version, homebrew in
            attempts.append((version, homebrew))
            if attempts.count == 1 {
                try await withCheckedThrowingContinuation { completion = $0 }
            }
        })
        let first = Task { await model.openTerminal() }
        while completion == nil { await Task.yield() }
        #expect(model.launchState == .opening)
        await model.openTerminal()
        #expect(attempts.count == 1)
        completion?.resume(throwing: UpdateScript.ScriptError.missingInstaller)
        await first.value
        #expect(model.launchState == .failed)
        await model.openTerminal()
        #expect(model.launchState == .opened)
        await model.openTerminal()
        #expect(attempts.count == 2)
        #expect(attempts.allSatisfy { $0.0 == "1.2.3.4" && $0.1 })
    }

    @Test("Download navigation reports failure and retries without invoking an installer")
    @MainActor
    func downloadNavigationRecovery() {
        let release = "https://github.com/macfanpro/macfanpro/releases/tag/v1.2.3.4"
        var opened: [URL] = []
        let model = UpdateDetailsModel(update: .init(version: "1.2.3.4", url: release), homebrew: false,
            launch: { _, _ in Issue.record("Downloading must not launch an installer") },
            openURL: { url in opened.append(url); return opened.count > 1 })
        model.openReleasePage()
        #expect(model.releasePageFailed)
        model.openReleasePage()
        #expect(!model.releasePageFailed)
        #expect(opened.map(\.absoluteString) == [release, release])
        #expect(model.launchState == .idle)
    }

    @Test("The shared installer receives literal arguments and the private directory is cleaned")
    func literalArguments() throws {
        for homebrew in [false, true] {
            let fm = FileManager.default
            let directory = fm.temporaryDirectory.appendingPathComponent("update-test-\(UUID().uuidString) ' $(touch SHOULD_NOT_EXIST)")
            try fm.createDirectory(at: directory, withIntermediateDirectories: false)
            defer { try? fm.removeItem(at: directory) }
            let result = fm.temporaryDirectory.appendingPathComponent("update-result-\(UUID().uuidString)")
            defer { try? fm.removeItem(at: result) }
            let installer = directory.appendingPathComponent("install.sh")
            try "printf '%s\\n' \"$@\" > \"$RESULT\"\nexit \"${FAIL:-0}\"\n".write(to: installer, atomically: true, encoding: .utf8)
            let command = directory.appendingPathComponent("update.command")
            try UpdateScript.contents(version: "1.2.3.4", homebrew: homebrew, installerPath: installer.path)
                .write(to: command, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [command.path]
            // Also exercise a failed child installer: the launcher must propagate failure.
            process.environment = ["PATH": "/usr/bin:/bin", "RESULT": result.path, "FAIL": homebrew ? "7" : "0"]
            try process.run()
            process.waitUntilExit()
            #expect(process.terminationStatus == (homebrew ? 7 : 0))
            #expect(try String(contentsOf: result) == "--version\n1.2.3.4\n" + (homebrew ? "--homebrew\n" : ""))
            #expect(!fm.fileExists(atPath: directory.path))
        }
    }

    @Test("The from-source command is complete and quotes unusual checkout paths")
    func sourceCommand() {
        #expect(UpdateScript.sourceCommand(directory: "/Users/me/Code/macfanpro")
                == "cd /Users/me/Code/macfanpro && git pull --ff-only && ./setup.sh")
        #expect(UpdateScript.sourceCommand(directory: "/Users/me/My Code/it's")
                == "cd '/Users/me/My Code/it'\\''s' && git pull --ff-only && ./setup.sh")
        for missing in [nil, ""] as [String?] {
            #expect(UpdateScript.sourceCommand(directory: missing)
                    == "git clone https://github.com/macfanpro/macfanpro.git ~/macfanpro 2>/dev/null; cd ~/macfanpro && git pull --ff-only && ./setup.sh")
        }
    }

    @Test("Versions cannot inject shell commands")
    func invalidVersion() {
        for version in ["1.2.3; touch bad", "$(id)", "1.2.3\n", "", "v1.2.3"] {
            #expect(throws: UpdateScript.ScriptError.self) {
                try UpdateScript.contents(version: version, homebrew: false, installerPath: "/tmp/test/install.sh")
            }
        }
    }
}
