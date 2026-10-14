import Darwin
import Foundation
import Testing
@testable import MacFanProCore

private final class InstallationTestBundle: NSObject {}

@Suite("Installation reliability — temporary files and simulated launchd")
struct InstallationReliabilityTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mfp-install-tests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Bundle preparation failures preserve the old app; success swaps complete bundles and cleans staging")
    func bundleReplacement() throws {
        let fm = FileManager.default, root = try temporaryDirectory()
        defer { try? fm.removeItem(at: root) }
        let destination = root.appendingPathComponent("App with spaces.app")
        #expect(throws: CocoaError.self) {
            try AppBundleReplacement.replace(at: URL(string: "https://example.invalid/App.app")!) { _ in
                Issue.record("Non-file destinations must fail before preparation")
            }
        }
        try AppBundleReplacement.replace(at: destination) { staged in
            try fm.createDirectory(at: staged, withIntermediateDirectories: true)
            try Data("old".utf8).write(to: staged.appendingPathComponent("old.txt"))
        }
        #expect(throws: CocoaError.self) {
            try AppBundleReplacement.replace(at: destination) { staged in
                try fm.createDirectory(at: staged, withIntermediateDirectories: true)
                try Data("partial".utf8).write(to: staged.appendingPathComponent("new.txt"))
                throw CocoaError(.fileWriteOutOfSpace)
            }
        }
        #expect(try String(contentsOf: destination.appendingPathComponent("old.txt")) == "old")
        try AppBundleReplacement.replace(at: destination) { staged in
            try #require(staged.isFileURL && staged.path.hasPrefix("/"))
            try #require(staged.deletingLastPathComponent().deletingLastPathComponent().path == root.path)
            try #require(staged.deletingLastPathComponent().lastPathComponent.hasPrefix(".macfanpro-install-"))
            let mode = try fm.attributesOfItem(atPath: staged.deletingLastPathComponent().path)[.posixPermissions] as? Int
            try #require(mode == 0o700)
            try fm.createDirectory(at: staged, withIntermediateDirectories: true)
            try Data("new".utf8).write(to: staged.appendingPathComponent("new.txt"))
            try AppBundleReplacement.handOver(staged, uid: getuid(), gid: getgid())
        }
        #expect(try fm.contentsOfDirectory(atPath: destination.path) == ["new.txt"])
        #expect(try fm.contentsOfDirectory(atPath: root.path) == ["App with spaces.app"])

        // A destination symlink is replaced as an entry; its target is not removed.
        let link = root.appendingPathComponent("Linked.app")
        try fm.createSymbolicLink(at: link, withDestinationURL: destination)
        try AppBundleReplacement.replace(at: link) { staged in
            try fm.createDirectory(at: staged, withIntermediateDirectories: true)
        }
        #expect(try String(contentsOf: destination.appendingPathComponent("new.txt")) == "new")
    }

    @Test("Copy rejects symlinks, FIFOs and existing destinations; permissions never inherit setuid or writable root modes")
    func safeCopy() throws {
        let fm = FileManager.default, root = try temporaryDirectory()
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("source"), dest = root.appendingPathComponent("dest")
        try Data("bytes".utf8).write(to: source)
        try fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: source.path)
        try SafeFileCopy.copyRegularFile(from: source.path, to: dest.path, requireExecutable: true, permissions: 0o755)
        #expect(try Data(contentsOf: source) == Data(contentsOf: dest))
        #expect(try fm.attributesOfItem(atPath: dest.path)[.posixPermissions] as? Int == 0o755)
        #expect(throws: SafeFileCopy.Failure.self) {
            try SafeFileCopy.copyRegularFile(from: source.path, to: dest.path)
        }
        let link = root.appendingPathComponent("link"), fifo = root.appendingPathComponent("fifo")
        try fm.createSymbolicLink(at: link, withDestinationURL: source)
        try #require(mkfifo(fifo.path, 0o600) == 0)
        for invalid in [link, fifo, root] {
            #expect(throws: SafeFileCopy.Failure.self) {
                try SafeFileCopy.copyRegularFile(from: invalid.path, to: root.appendingPathComponent("never").path)
            }
        }
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: source.path)
        #expect(throws: SafeFileCopy.Failure.self) {
            try SafeFileCopy.copyRegularFile(from: source.path, to: root.appendingPathComponent("never").path, requireExecutable: true)
        }
        #expect(!fm.fileExists(atPath: root.appendingPathComponent("never").path))
        try fm.setAttributes([.posixPermissions: 0o4755], ofItemAtPath: source.path)
        let stripped = root.appendingPathComponent("without-setuid")
        try SafeFileCopy.copyRegularFile(from: source.path, to: stripped.path)
        #expect(try fm.attributesOfItem(atPath: stripped.path)[.posixPermissions] as? Int == 0o755)
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: source.path)
        // Giving the staging copy to its user must not follow its external link.
        let bundle = root.appendingPathComponent("Stage.app")
        try fm.createDirectory(at: bundle, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: bundle.appendingPathComponent("external"), withDestinationURL: source)
        try AppBundleReplacement.handOver(bundle, uid: getuid(), gid: getgid())
        #expect(try fm.attributesOfItem(atPath: source.path)[.posixPermissions] as? Int == 0o644)
    }

    @Test("Source matching distinguishes builds while allowing signing changes; corrupt headers fail closed")
    func buildMatching() throws {
        let fm = FileManager.default, root = try temporaryDirectory()
        defer { try? fm.removeItem(at: root) }
        let binary = root.appendingPathComponent("macfanpro"), app = root.appendingPathComponent("MacFanPro.app")
        let helper = app.appendingPathComponent(EmbeddedServiceInstallation.helperRelativePath)
        try fm.createDirectory(at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "io.github.macfanpro.app", "CFBundleShortVersionString": "1.2.3"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        var macho = Data()
        for value: UInt32 in [0xfeedfacf, 0x0100000c, 0, 2, 1, 24, 0, 0, 0x1b, 24] {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { macho.append(contentsOf: $0) }
        }
        macho.append(contentsOf: 1...16)
        try macho.write(to: binary)
        try (macho + Data("different signature".utf8)).write(to: helper)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        #expect(AppInstallSource.matches(app, binary: binary, version: "1.2.3"))
        #expect(!AppInstallSource.matches(app, binary: binary, version: "1.2.4"))
        var other = macho; other[40] = 99
        try other.write(to: helper)
        #expect(!AppInstallSource.matches(app, binary: binary, version: "1.2.3"))
        for bad in [Data(), Data(macho.prefix(12)), Data(macho.prefix(55))] {
            try bad.write(to: helper)
            #expect(AppInstallSource.buildIdentity(helper) == nil)
        }
        var bad = macho; bad[36] = 0xff // load command overruns the header
        try bad.write(to: helper)
        #expect(AppInstallSource.buildIdentity(helper) == nil)

        // Exercise real Mach-O bytes and re-signing, as release packaging does.
        let cli = Bundle(for: InstallationTestBundle.self).bundleURL.deletingLastPathComponent().appendingPathComponent("macfanpro")
        try #require(AppInstallSource.buildIdentity(cli) != nil)
        try fm.removeItem(at: helper)
        try fm.copyItem(at: cli, to: helper)
        let signed = SystemTools.run("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", "installation-fixture", helper.path])
        guard case .exited(0, _) = signed else { Issue.record("Signing failed: \(signed)"); return }
        #expect(!fm.contentsEqual(atPath: helper.path, andPath: cli.path))
        #expect(AppInstallSource.matches(app, binary: cli, version: "1.2.3"))
    }

    @Test("launchd teardown waits for removal, propagates errors and stops at its deadline")
    func teardown() throws {
        var elapsed: TimeInterval = 0, calls = [[String]]()
        var control = LaunchdControl(launchctl: { calls.append($0); return (0, "") },
            isRegistered: { elapsed < 0.4 }, now: { elapsed },
            pause: { elapsed += $0 }, teardownLimit: 1)
        try control.bootoutIfRegistered(label: "fixture", rerun: "retry")
        #expect(calls == [["bootout", "system/fixture"]] && elapsed >= 0.4)
        calls = []; control.isRegistered = { false }
        try control.bootoutIfRegistered(label: "fixture", rerun: "retry")
        #expect(calls.isEmpty)
        control.isRegistered = { true }
        control.launchctl = { _ in (5, "permission denied") }
        #expect(throws: LaunchdError.bootoutFailed(exitStatus: 5, detail: "permission denied", rerun: "retry")) {
            try control.bootoutIfRegistered(label: "fixture", rerun: "retry")
        }
        elapsed = 0; control.launchctl = { _ in (0, "") }
        #expect(throws: LaunchdError.stillRegistered(seconds: 1, rerun: "retry")) {
            try control.bootoutIfRegistered(label: "fixture", rerun: "retry")
        }
        #expect(elapsed >= 1 && elapsed < 1.5)
        #expect(try LaunchdControl.registrationStatus(.exited(0, output: "loaded")))
        #expect(try !LaunchdControl.registrationStatus(.exited(113, output: "missing")))
        for run in [SystemTools.ToolRun.exited(5, output: "denied"), .notLaunched("missing tool")] {
            calls = []
            control.isRegistered = { try LaunchdControl.registrationStatus(run) }
            control.launchctl = { calls.append($0); return (0, "") }
            #expect(throws: LaunchdError.self) {
                try control.bootoutIfRegistered(label: "fixture", rerun: "retry")
            }
            #expect(calls.isEmpty)
        }
    }

    @Test("Bootstrap retries once only when unregistered; readiness polling tolerates a slow service")
    func startup() throws {
        var attempts = 0, notes = [String](), elapsed: TimeInterval = 0
        var control = LaunchdControl(launchctl: { _ in attempts += 1; return (attempts == 1 ? 5 : 0, "busy") },
            isRegistered: { false }, now: { elapsed }, pause: { elapsed += $0 })
        try control.bootstrap(plist: "fixture", rerun: "retry", note: { notes.append($0) })
        #expect(attempts == 2 && notes.count == 1 && notes[0].contains("busy"))
        attempts = 0; control.isRegistered = { true }
        try control.bootstrap(plist: "fixture", rerun: "retry", note: { _ in })
        #expect(attempts == 1)
        attempts = 0
        control.launchctl = { _ in attempts += 1; return (5, "loaded despite error") }
        control.isRegistered = { attempts == 2 }
        try control.bootstrap(plist: "fixture", rerun: "retry", note: { _ in })
        #expect(attempts == 2)
        control.isRegistered = { false }; control.launchctl = { _ in (5, "denied") }
        #expect(throws: LaunchdError.bootstrapFailed(exitStatus: 5, detail: "denied", rerun: "retry")) {
            try control.bootstrap(plist: "fixture", rerun: "retry", note: { _ in })
        }
        #expect(control.waitUntil(limit: 1) { elapsed >= 0.6 })
        elapsed = 0
        #expect(!control.waitUntil(limit: 1) { false })
        #expect(elapsed >= 1 && elapsed < 1.5)
    }

    @Test("Every installation failure preserves the app and restores service files on upgrades and first installs")
    func installationRecovery() throws {
        enum Failure: Error { case injected }
        let fm = FileManager.default, root = try temporaryDirectory()
        defer { try? fm.removeItem(at: root) }
        for existing in [true, false] {
            for failure in ["none", "stop", "files", "start", "verify", "commit"] {
                let run = root.appendingPathComponent("\(existing)-\(failure)")
                try fm.createDirectory(at: run, withIntermediateDirectories: true)
                let cli = run.appendingPathComponent("cli"), plist = run.appendingPathComponent("daemon.plist")
                let app = run.appendingPathComponent("MacFanPro.app")
                if existing {
                    try ServiceFileSnapshot.replace(cli, data: Data("old CLI".utf8), mode: 0o755)
                    try ServiceFileSnapshot.replace(plist, data: Data("old plist".utf8), mode: 0o644)
                    try fm.createDirectory(at: app, withIntermediateDirectories: true)
                    try Data("old app".utf8).write(to: app.appendingPathComponent("content"))
                }
                let snapshot = try ServiceFileSnapshot(paths: [(cli, 0o755), (plist, 0o644)])
                var prepared: AppBundleReplacement.Prepared? = try .init(at: app) { staged in
                    try fm.createDirectory(at: staged, withIntermediateDirectories: true)
                    try Data("new app".utf8).write(to: staged.appendingPathComponent("content"))
                }
                var events = [String]()
                func step(_ name: String) throws {
                    events.append(name)
                    if name == failure { throw Failure.injected }
                }
                func install() throws {
                    try ServiceLifecycle.install(stop: { try step("stop") }, replaceFiles: {
                        try ServiceFileSnapshot.replace(cli, data: Data("new CLI".utf8), mode: 0o755)
                        try step("files") // failure after a partial replacement
                        try ServiceFileSnapshot.replace(plist, data: Data("new plist".utf8), mode: 0o644)
                    }, start: { try step("start") }, verify: { try step("verify") }, commitApp: {
                        // Exercise a real rename failure after service startup.
                        if failure == "commit" { try fm.removeItem(at: prepared!.staged) }
                        events.append("commit")
                        try prepared!.commit()
                    }, recover: {
                        try snapshot.restoreService(stop: { events.append("recover-stop") }, start: {
                            if existing { events.append("recover-start") }
                        })
                    })
                }
                if failure == "none" {
                    try install()
                    #expect(events == ["stop", "files", "start", "verify", "commit"])
                    #expect(try String(contentsOf: cli) == "new CLI")
                    #expect(try String(contentsOf: app.appendingPathComponent("content")) == "new app")
                } else {
                    #expect(throws: (any Error).self) { try install() }
                    if failure == "stop" { #expect(events == ["stop"]) }
                    else { #expect(events.contains("recover-stop")) }
                    if existing {
                        #expect(try String(contentsOf: cli) == "old CLI")
                        #expect(try String(contentsOf: plist) == "old plist")
                        #expect(try String(contentsOf: app.appendingPathComponent("content")) == "old app")
                    } else {
                        #expect(!fm.fileExists(atPath: cli.path))
                        #expect(!fm.fileExists(atPath: plist.path))
                        #expect(!fm.fileExists(atPath: app.path))
                    }
                }
                prepared = nil
                #expect(try fm.contentsOfDirectory(atPath: run.path).allSatisfy { !$0.hasPrefix(".macfanpro-install-") })
            }
        }
        #expect(throws: ServiceLifecycle.RecoveryFailure.self) {
            try ServiceLifecycle.install(stop: {}, replaceFiles: {}, start: { throw Failure.injected },
                verify: {}, commitApp: {}, recover: { throw CocoaError(.fileWriteNoPermission) })
        }
    }

    @Test("Uninstall never resets or removes after a stop failure and reports removal failures")
    func uninstallFailureBoundaries() throws {
        enum Failure: Error { case injected }
        for failure in ["none", "stop", "reset", "remove"] {
            var events = [String]()
            func step(_ name: String) throws {
                events.append(name)
                if name == failure { throw Failure.injected }
            }
            func uninstall() throws {
                try ServiceLifecycle.uninstall(stop: { try step("stop") },
                    resetFans: { try step("reset") }, removeFiles: { try step("remove") })
            }
            if failure == "none" { try uninstall() }
            else { #expect(throws: Failure.self) { try uninstall() } }
            let expected = failure == "stop" ? ["stop"] : failure == "reset" ? ["stop", "reset"] : ["stop", "reset", "remove"]
            #expect(events == expected)
        }
    }

    @Test("Tool failures and large output are captured; stopping reports actual process state")
    func toolsAndStopping() throws {
        #expect(SystemTools.run("/bin/sh", ["-c", "echo out; echo err >&2; exit 3"]) == .exited(3, output: "out\nerr"))
        if case .notLaunched = SystemTools.run("/nonexistent-mfp-tool", []) {} else { Issue.record("Expected launch failure") }
        guard case .exited(0, let output) = SystemTools.run("/bin/sh", ["-c", "yes x | head -c 200000"]) else {
            Issue.record("Expected complete pipe output"); return
        }
        #expect(output.count > 190_000)
        #expect(SystemTools.currentExecutablePath()?.hasPrefix("/") == true)
        let cases: [([Bool?], SystemTools.ToolRun, SystemTools.AppStop)] = [
            ([true, false], .exited(0, output: ""), .stopped),
            ([false, false], .exited(1, output: "none"), .notRunning),
            ([true, true], .exited(0, output: ""), .failed("the menu bar app is still running (killall exit 0)")),
            ([true, nil], .notLaunched("missing"), .failed("couldn't confirm the menu bar app stopped (killall didn't run: missing)"))
        ]
        for (answers, kill, expected) in cases {
            var states = answers
            let actual = SystemTools.stopApp(isRunning: { states.count > 1 ? states.removeFirst() : states[0] },
                kill: { kill }, waitLimit: 0.2, sleep: { _ in })
            #expect(actual == expected)
        }
    }
}
