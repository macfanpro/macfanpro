import AppKit
import Combine
import SwiftUI
import MacFanProCore
import MacFanProLocalization

@MainActor
final class UpdateDetailsModel: ObservableObject {
    enum LaunchState: Equatable { case idle, opening, opened, failed }

    let update: AvailableUpdate
    let homebrew: Bool
    @Published private(set) var launchState: LaunchState = .idle
    @Published private(set) var releasePageFailed = false
    private let launch: (String, Bool) async throws -> Void
    private let openURL: (URL) -> Bool

    init(update: AvailableUpdate, homebrew: Bool,
         launch: @escaping (String, Bool) async throws -> Void = UpdateScript.open,
         openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.update = update
        self.homebrew = homebrew
        self.launch = launch
        self.openURL = openURL
    }

    func openReleasePage() {
        guard let url = URL(string: update.url) else { releasePageFailed = true; return }
        releasePageFailed = !openURL(url)
    }

    func openTerminal() async {
        guard launchState != .opening, launchState != .opened else { return }
        launchState = .opening
        do {
            try await launch(update.version, homebrew)
            launchState = .opened
        } catch {
            launchState = .failed
        }
    }
}

/// The settings window's update rows: the installed version, and while a newer
/// release exists, how to install it. This replaced the separate update window, so
/// settings is the only window MacFanPro opens.
struct UpdateSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var language: AppLanguageStore
    /// Bumped when settings closes, so a Terminal hand-off resets for the next visit.
    let session: Int

    var body: some View {
        LabeledContent(language.text("Version")) {
            Text(MacFanProVersion.current).font(.system(.body, design: .monospaced)).textSelection(.enabled)
        }
        .accessibilityIdentifier("io.github.macfanpro.version")
        if let update = appState.availableUpdate {
            AvailableUpdateRows(model: UpdateDetailsModel(update: update, homebrew: appState.installedWithHomebrew))
                .id("\(update.version)-\(appState.installedWithHomebrew)-\(session)")
        } else {
            HStack {
                Text(status)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("io.github.macfanpro.update-status")
                Spacer(minLength: 8)
                Button(language.text(appState.manualUpdateCheck == .failed ? "Retry" : "Check for Updates")) {
                    appState.checkForUpdatesNow()
                }
                .fixedSize()
                .disabled(appState.manualUpdateCheck == .checking)
                .accessibilityIdentifier("io.github.macfanpro.check-updates")
            }
        }
    }

    private var status: String {
        switch appState.manualUpdateCheck {
        case .checking: return language.text("Checking…")
        case .upToDate: return language.text("Up to date")
        case .failed: return language.text("Couldn't reach GitHub")
        case .available(let version): return language.text("{version} available", ["version": version])
        case .idle: return language.text("Checked automatically every day")
        }
    }
}

/// One available release. The model lives in a StateObject so the Terminal hand-off
/// survives redraws; UpdateSection's id gives each release and visit a fresh one.
struct AvailableUpdateRows: View {
    @StateObject var model: UpdateDetailsModel
    @EnvironmentObject var language: AppLanguageStore

    init(model: @autoclosure @escaping () -> UpdateDetailsModel) {
        _model = StateObject(wrappedValue: model())
    }

    var body: some View {
        LabeledContent(language.text("New version")) {
            HStack(spacing: 10) {
                Button(language.text("What's new"), action: model.openReleasePage)
                    .buttonStyle(.link)
                    .accessibilityIdentifier("io.github.macfanpro.release-notes")
                Text(model.update.version)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("io.github.macfanpro.update-status")
            }
        }
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text(model.homebrew ? "Update with Homebrew" : "Download the new app"))
                Text(language.text(model.homebrew ?
                    "Opens Terminal to update. Administrator authorization is required." :
                    "Quit MacFanPro, replace it with the new app, then reopen it."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if model.homebrew {
                terminalButton.buttonStyle(.borderedProminent).fixedSize()
            } else {
                Button(language.text("Open download page"), action: model.openReleasePage)
                    .buttonStyle(.borderedProminent)
                    .fixedSize()
                    .accessibilityIdentifier("io.github.macfanpro.download-update")
            }
        }
        if model.releasePageFailed {
            Text(language.text("Could not open the release page. Try again."))
                .foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
        }
        if model.launchState == .failed {
            Text(language.text("Could not open Terminal. Try again or use the command below Other update methods."))
                .foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("io.github.macfanpro.update-error")
        } else if model.launchState == .opened {
            Text(language.text("Continue the update in Terminal. Close and reopen this window to try again."))
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("io.github.macfanpro.update-handoff")
        }
        DisclosureGroup(language.text("Other update methods")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("Run this in Terminal:")).foregroundStyle(.secondary)
                commandBlock(UpdateScript.installCommand(version: model.update.version, homebrew: model.homebrew))
                if !model.homebrew {
                    terminalButton
                }
                Text(language.text("Build from source")).font(.headline)
                commandBlock(UpdateScript.sourceCommand(directory:
                    Bundle.main.object(forInfoDictionaryKey: "MacFanProSourceDirectory") as? String))
            }
            .padding(.top, 6)
        }
        .accessibilityIdentifier("io.github.macfanpro.other-update-methods")
        DisclosureGroup(language.text("Download help")) {
            Text(language.text("If downloads fail, enable your system proxy and retry."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        }
    }

    private var terminalButton: some View {
        Button(language.text(model.launchState == .opening ? "Opening Terminal…" : "Update in Terminal")) {
            Task { await model.openTerminal() }
        }
        .disabled(model.launchState == .opening || model.launchState == .opened)
        .accessibilityIdentifier("io.github.macfanpro.update-in-terminal")
    }

    private func commandBlock(_ command: String) -> some View {
        Text(command)
            .environment(\.layoutDirection, .leftToRight)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12)))
    }
}
