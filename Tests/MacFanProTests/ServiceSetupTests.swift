import AppKit
import Foundation
import SwiftUI
import Testing
@testable import MacFanProApp
@testable import MacFanProCore
import MacFanProLocalization

@Suite("Drag-install setup — isolated, no authorization or fan control", .serialized)
@MainActor
struct ServiceSetupTests {
    final class Fixture: @unchecked Sendable {
        var snapshot = ServiceSetup.Snapshot()
        var result: ServiceSetup.AuthorizationResult = .cancelled
        var becomesReady = false
        var authorizationCount = 0
        var probeCount = 0
        func environment(bundle: String = EmbeddedServiceInstallation.appPath, helper: Bool = true) -> ServiceSetup.Environment {
            .init(bundle: URL(fileURLWithPath: bundle), helperExists: { helper },
                  probe: { self.probeCount += 1; return self.snapshot },
                  authorize: { _ in
                      self.authorizationCount += 1
                      if self.becomesReady { self.snapshot.version = MacFanProVersion.current }
                      return self.result
                  })
        }
    }

    @Test("Existing, missing, conflicting and relocated installs select the right action without authorizing")
    func discovery() async {
        let cases: [(String, Bool, ServiceSetup.Snapshot, ServiceSetup.Phase)] = [
            ("/Volumes/MacFanPro/MacFanPro.app", true, .init(), .move),
            ("/Applications/MacFanPro.app", false, .init(), .blocked),
            ("/Applications/MacFanPro.app", true, .init(), .install),
            ("/Applications/MacFanPro.app", true, .init(version: "0.2.3.36"), .update),
            ("/Applications/MacFanPro.app", true, .init(version: MacFanProVersion.current), .ready),
            ("/Applications/MacFanPro.app", true, .init(version: MacFanProVersion.current, hasHomebrew: true), .ready),
            ("/Applications/MacFanPro.app", true, .init(hasHomebrew: true), .homebrew),
            ("/Applications/MacFanPro.app", true, .init(version: "99.0.0"), .blocked),
            ("/Applications/MacFanPro.app", true, .init(version: MacFanProVersion.current, validProtocol: false), .update),
            ("/Applications/MacFanPro.app", true, .init(version: "0.2.3.36", cliHold: true), .blocked),
            ("/Applications/MacFanPro.app", true, .init(otherOwner: true), .blocked),
        ]
        for (path, helper, snapshot, expected) in cases {
            let fixture = Fixture(); fixture.snapshot = snapshot
            let setup = ServiceSetup(environment: fixture.environment(bundle: path, helper: helper))
            var started = 0; setup.onReady = { started += 1 }
            await setup.check()
            #expect(setup.phase == expected)
            #expect(started == (expected == .ready ? 1 : 0))
            #expect(fixture.authorizationCount == 0)
            if path.hasPrefix("/Volumes") || !helper { #expect(fixture.probeCount == 0) }
        }
    }

    @Test("Cancellation, failure and false success retain retry; only a matching live service enables control")
    func authorization() async {
        let fixture = Fixture()
        let setup = ServiceSetup(environment: fixture.environment())
        var started = 0; setup.onReady = { started += 1 }
        await setup.check()
        await setup.perform(.install)
        #expect(setup.phase == .install && started == 0)
        #expect(setup.message == "Authorization was cancelled. You can try again.")
        fixture.result = .failed("denied")
        await setup.perform(.install)
        #expect(setup.phase == .install && started == 0)
        #expect(setup.diagnostics == "denied")
        fixture.result = .success
        await setup.perform(.install) // authorization succeeded, but nothing is listening
        #expect(setup.phase == .install && started == 0)
        fixture.becomesReady = true
        await setup.perform(.install)
        #expect(setup.phase == .ready && started == 1)
        #expect(setup.message == nil && setup.diagnostics.isEmpty)
        #expect(fixture.authorizationCount == 4)
        await setup.perform(.install) // a ready service is never reinstalled by this action
        #expect(fixture.authorizationCount == 4)
    }

    @Test("Cancelling removal never pauses monitoring; confirmed removal drains writes only after success")
    func removal() async {
        let fixture = Fixture(); fixture.snapshot.version = MacFanProVersion.current
        let setup = ServiceSetup(environment: fixture.environment())
        var paused = 0; setup.beforeRemoval = { paused += 1 }
        await setup.check()
        await setup.perform(.uninstall)
        #expect(setup.phase == .ready && paused == 0)
        fixture.result = .failed("failed")
        await setup.perform(.uninstall)
        #expect(setup.phase == .ready && paused == 0)
        fixture.result = .success
        await setup.perform(.uninstall)
        #expect(setup.phase == .removed && paused == 1)
        #expect(ServiceSetup.command(.install, owner: 501) == "'/Applications/MacFanPro.app/Contents/Helpers/macfanpro' install --embedded-owner-uid 501")
    }

    @Test("Settings window renders every language in light and dark without starting app services")
    func localizedWindow() async throws {
        let suite = "MacFanPro.SetupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let language = AppLanguageStore(defaults: defaults)
        let fixture = Fixture()
        let setup = ServiceSetup(environment: fixture.environment())
        await setup.check()
        for theme in [ColorScheme.light, .dark] {
            let view = NSHostingView(rootView: SettingsView(setup: setup)
                .environmentObject(AppState(startServices: false))
                .environmentObject(language).environment(\.colorScheme, theme)
                .background(theme == .dark ? Color.black : Color.white))
            view.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
            for choice in LocalizationCatalog.supportedLanguages {
                language.select(choice)
                try await Task.sleep(for: .milliseconds(20))
                view.setFrameSize(view.fittingSize); view.layoutSubtreeIfNeeded()
                #expect(view.frame.width == 460)
                #expect(view.frame.height > 300 && view.frame.height < 900)
                let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                #expect(png.count > 1000)
                if let dir = ProcessInfo.processInfo.environment["MACFANPRO_PREVIEW_DIR"] {
                    let url = URL(fileURLWithPath: dir)
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    try png.write(to: url.appendingPathComponent("setup-\(choice.rawValue)-\(theme).png"))
                }
            }
        }
        #expect(fixture.authorizationCount == 0)
    }
}

@Suite("Embedded service installation boundaries")
struct EmbeddedServiceInstallationTests {
    @Test("Reject other owners, unsupported paths, downgrade and CLI holds before any writes")
    func validation() throws {
        #expect(throws: EmbeddedServiceInstallation.Failure.account) {
            try EmbeddedServiceInstallation.validateOwner(0)
        }
        try EmbeddedServiceInstallation.validateOwner(getuid())
        #expect(throws: EmbeddedServiceInstallation.Failure.location) {
            try EmbeddedServiceInstallation.validateBundle(URL(fileURLWithPath: "/tmp/MacFanPro.app"),
                executable: URL(fileURLWithPath: "/tmp/macfanpro"), version: "0.2.3.37")
        }
        let plist: [String: Any] = ["Label": MacFanProDaemon.label,
            "ProgramArguments": [MacFanProDaemon.installPath, "daemon", "--owner-uid", "501"]]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try EmbeddedServiceInstallation.validateExistingPlist(data, owner: 501)
        try EmbeddedServiceInstallation.validateExistingPlist(nil, owner: 501)
        #expect(throws: EmbeddedServiceInstallation.Failure.otherOwner) {
            try EmbeddedServiceInstallation.validateExistingPlist(data, owner: 502)
        }
        #expect(throws: EmbeddedServiceInstallation.Failure.newerService) {
            try EmbeddedServiceInstallation.validateLiveService(version: "0.2.3.50", target: "0.2.3.37", state: nil)
        }
        #expect(throws: EmbeddedServiceInstallation.Failure.manualHold) {
            try EmbeddedServiceInstallation.validateLiveService(version: "0.2.3.36", target: "0.2.3.37",
                state: .init(command: "max", owner: "cli"))
        }
        try EmbeddedServiceInstallation.validateLiveService(version: "0.2.3.36", target: "0.2.3.37",
            state: .init(command: nil, owner: "none"))
    }

    @Test("Rollback restores old bytes and permissions; first install rollback removes new files; symlinks rejected")
    func rollbackFiles() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("macfanpro-service-test-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let binary = dir.appendingPathComponent("binary"), plist = dir.appendingPathComponent("service.plist")
        try ServiceFileSnapshot.replace(binary, data: Data("old".utf8), mode: 0o755)
        let snapshot = try ServiceFileSnapshot(paths: [(binary, 0o755), (plist, 0o644)])
        try ServiceFileSnapshot.replace(binary, data: Data("new".utf8), mode: 0o700)
        try ServiceFileSnapshot.replace(plist, data: Data("new plist".utf8), mode: 0o644)
        try snapshot.restore()
        #expect(try String(contentsOf: binary) == "old")
        #expect(try fm.attributesOfItem(atPath: binary.path)[.posixPermissions] as? Int == 0o755)
        #expect(!fm.fileExists(atPath: plist.path))
        try ServiceFileSnapshot.replace(binary, data: Data("broken upgrade".utf8), mode: 0o755)
        var started = false
        #expect(throws: ServiceFileSnapshot.RollbackFailure.self) {
            try snapshot.restoreService(stop: { throw CocoaError(.fileWriteNoPermission) }, start: { started = true })
        }
        #expect(try String(contentsOf: binary) == "old")
        #expect(!started)
        try fm.createSymbolicLink(at: plist, withDestinationURL: binary)
        #expect(throws: EmbeddedServiceInstallation.Failure.unsafePath) {
            _ = try ServiceFileSnapshot(paths: [(plist, 0o644)])
        }
        try ServiceFileSnapshot.replace(plist, data: Data("separate".utf8), mode: 0o644)
        #expect(try String(contentsOf: binary) == "old") // atomic write didn't follow the link
        #expect(try String(contentsOf: plist) == "separate")
        #expect(throws: EmbeddedServiceInstallation.Failure.unsafePath) {
            try EmbeddedServiceInstallation.validateDirectory(dir)
        }
    }
}
