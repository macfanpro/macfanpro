import AppKit
import SwiftUI
import Testing
@testable import MacFanProApp
@testable import MacFanProCore
import MacFanProLocalization

@Suite("Localized panels — no services", .serialized)
@MainActor
struct LocalizedPanelTests {
    @Test("One retained panel refreshes in every language with all warning layouts")
    func panelLayouts() async throws {
        let name = "MacFanPro.PanelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let language = AppLanguageStore(defaults: defaults, preferredLanguages: { ["en"] })
        let state = AppState(startServices: false)
        state.activeProfile = .smart
        state.monitorState = .active(profileName: "Smart")
        state.latestStatus = ThermalStatus(fans: [
            .init(index: 0, actualRPM: 5777, targetRPM: 5777, minRPM: 1350, maxRPM: 5777, mode: "manual"),
            .init(index: 1, actualRPM: 5756, targetRPM: 5777, minRPM: 1350, maxRPM: 5777, mode: "manual"),
        ], temperatures: ["TCMb": 100, "Tg05": 73.7, "TRDX": 43.4, "TH0x": 26.3, "TAOL": 24.4])
        let identity = ObjectIdentifier(state)
        let panel = NSHostingView(rootView: MenuBarView(onSettings: {}).environmentObject(state).environmentObject(language)
            .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .light))
        var normalHeights: [AppLanguage: CGFloat] = [:]
        for scenario in ["normal", "held-update", "update-brew", "mismatch-safety", "daemon-down", "up-to-date", "normal"] {
            state.externalHold = scenario == "held-update" ? DaemonHoldState(command: "setfan 1 5777", owner: "cli") : nil
            // Available releases use the same compact row for both install methods.
            state.installedWithHomebrew = scenario == "update-brew"
            state.availableUpdate = ["held-update", "update-brew"].contains(scenario) ? AvailableUpdate(version: "99.99.99", url: "https://github.com/macfanpro/macfanpro/releases") : nil
            state.daemonVersionMismatch = scenario == "mismatch-safety" ? "0.2.3.5" : nil
            state.daemonUnreachable = scenario == "daemon-down"
            // Long localized results must wrap within the fixed menu width.
            state.manualUpdateCheck = switch scenario {
            case "held-update": .available("99.99.99")
            case "mismatch-safety": .failed
            case "daemon-down": .checking
            case "up-to-date": .upToDate
            default: .idle
            }
            state.monitorState = scenario == "mismatch-safety" ? .safetyOverride : .active(profileName: "Smart")
            let hold = state.externalHold
            let monitor = state.monitorState
            for choice in LocalizationCatalog.supportedLanguages {
                language.select(choice)
                try await Task.sleep(for: .milliseconds(30))
                panel.setFrameSize(panel.fittingSize)
                panel.layoutSubtreeIfNeeded()
                #expect(panel.frame.width == 260)
                #expect(panel.frame.height > 300 && panel.frame.height < 1000)
                if scenario == "update-brew", let normalHeight = normalHeights[choice] {
                    #expect(panel.frame.height <= normalHeight + 48, "Update row must not restore a tall banner: \(choice)")
                }
                if scenario == "normal" {
                    if let firstHeight = normalHeights[choice] {
                        #expect(panel.frame.height == firstHeight)
                    } else {
                        normalHeights[choice] = panel.frame.height
                    }
                }
                #expect(ObjectIdentifier(state) == identity)
                #expect(state.activeProfile == .smart)
                #expect(state.monitorState == monitor)
                #expect(state.externalHold == hold)
                let bitmap = try #require(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
                panel.cacheDisplay(in: panel.bounds, to: bitmap)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                #expect(png.count > 1000)
                if let directory = ProcessInfo.processInfo.environment["MACFANPRO_PREVIEW_DIR"] {
                    let url = URL(fileURLWithPath: directory)
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    try png.write(to: url.appendingPathComponent("\(scenario)-\(choice.rawValue).png"))
                }
            }
        }
    }

    @Test("Update details render both install channels in every language and appearance")
    func updateDetailsLayouts() async throws {
        let name = "MacFanPro.UpdatePanelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let language = AppLanguageStore(defaults: defaults, preferredLanguages: { ["en"] })
        for homebrew in [false, true] {
            let model = UpdateDetailsModel(update: .init(version: "99.99.99", url: UpdateChecker.releasesPageURL),
                homebrew: homebrew, launch: { _, _ in Issue.record("Rendering must not install") },
                openURL: { _ in Issue.record("Rendering must not open a browser"); return false })
            for dark in [false, true] {
                let panel = NSHostingView(rootView: UpdateDetailsView(model: model, onClose: {})
                    .environmentObject(language).environment(\.colorScheme, dark ? .dark : .light))
                for choice in LocalizationCatalog.supportedLanguages {
                    language.select(choice)
                    try await Task.sleep(for: .milliseconds(30))
                    panel.setFrameSize(NSSize(width: 440, height: 430))
                    panel.layoutSubtreeIfNeeded()
                    #expect(panel.fittingSize.width <= 440)
                    let bitmap = try #require(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
                    panel.cacheDisplay(in: panel.bounds, to: bitmap)
                    let png = try #require(bitmap.representation(using: .png, properties: [:]))
                    if let directory = ProcessInfo.processInfo.environment["MACFANPRO_PREVIEW_DIR"] {
                        let url = URL(fileURLWithPath: directory)
                        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        try png.write(to: url.appendingPathComponent("update-detail-\(homebrew ? "brew" : "dmg")-\(dark ? "dark" : "light")-\(choice.rawValue).png"))
                    }
                }
            }
        }
    }

    @Test("Closing or refocusing update details preserves the offer and reuses only an open window")
    func updateWindowLifecycle() async throws {
        let name = "MacFanPro.UpdateWindowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let language = AppLanguageStore(defaults: defaults, preferredLanguages: { ["en"] })
        let state = AppState(startServices: false)
        let update = AvailableUpdate(version: "99.99.99", url: UpdateChecker.releasesPageURL)
        state.availableUpdate = update
        state.manualUpdateCheck = .available(update.version)
        let controller = UpdateDetailsWindow()
        defer { controller.close() }
        controller.present(appState: state, language: language)
        let first = try #require(controller.window)
        controller.present(appState: state, language: language)
        #expect(controller.window === first)
        language.select(.simplifiedChinese)
        try await Task.sleep(for: .milliseconds(50))
        #expect(first.title == language.text("MacFanPro update"))
        controller.close()
        #expect(controller.window == nil)
        #expect(!first.isVisible)
        #expect(state.availableUpdate == update)
        #expect(state.manualUpdateCheck == .available(update.version))
        controller.present(appState: state, language: language)
        #expect(controller.window !== first)
        #expect(controller.window?.isVisible == true)
        #expect(state.availableUpdate == update)
    }
}
