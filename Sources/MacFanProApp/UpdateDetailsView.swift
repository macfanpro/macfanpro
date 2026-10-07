import AppKit
import Combine
import SwiftUI
import MacFanProCore
import MacFanProLocalization

@MainActor
final class UpdateDetailsWindow: NSObject, ObservableObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private var languageSubscription: AnyCancellable?

    func present(appState: AppState, language: AppLanguageStore) {
        guard let update = appState.availableUpdate else { return }
        if window == nil {
            let model = UpdateDetailsModel(update: update, homebrew: appState.installedWithHomebrew)
            let view = UpdateDetailsView(model: model, onClose: { [weak self] in self?.close() })
                .environmentObject(language)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = language.text("MacFanPro update")
            window.identifier = NSUserInterfaceItemIdentifier("io.github.macfanpro.update-window")
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize(NSSize(width: 440, height: 430))
            window.center()
            self.window = window
            languageSubscription = language.$language.receive(on: DispatchQueue.main).sink { [weak self, weak language] _ in
                guard let language else { return }
                self?.window?.title = language.text("MacFanPro update")
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        languageSubscription = nil
        window = nil
    }
}

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

struct UpdateDetailsView: View {
    @ObservedObject var model: UpdateDetailsModel
    @EnvironmentObject var language: AppLanguageStore
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(language.text("Update available")).foregroundStyle(.secondary)
                        Text("MacFanPro \(model.update.version)").font(.title2.bold())
                            .textSelection(.enabled)
                        Text(language.text("Current version: {version}", ["version": MacFanProVersion.current]))
                            .foregroundStyle(.secondary)
                        Button(language.text("What's new"), action: model.openReleasePage)
                            .buttonStyle(.link)
                            .accessibilityIdentifier("io.github.macfanpro.release-notes")
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(language.text(model.homebrew ? "Update with Homebrew" : "Download the new app"))
                            .font(.headline)
                        Text(language.text(model.homebrew ?
                            "Opens Terminal to update. Administrator authorization may be required." :
                            "Quit MacFanPro, replace it with the new app, then reopen it."))
                            .foregroundStyle(.secondary)
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
                        .padding(.top, 8)
                    }
                    .accessibilityIdentifier("io.github.macfanpro.other-update-methods")
                    DisclosureGroup(language.text("Download help")) {
                        Text(language.text("If downloads fail, enable your system proxy and retry."))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if model.releasePageFailed {
                    Text(language.text("Could not open the release page. Try again."))
                        .foregroundStyle(.red)
                }
                if model.launchState == .failed {
                    Text(language.text("Could not open Terminal. Try again or use the command below Other update methods."))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("io.github.macfanpro.update-error")
                } else if model.launchState == .opened {
                    Text(language.text("Continue the update in Terminal. Close and reopen this window to try again."))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("io.github.macfanpro.update-handoff")
                }
                HStack {
                    Spacer()
                    Button(language.text("Close"), action: onClose)
                        .keyboardShortcut(.cancelAction)
                    if model.homebrew {
                        terminalButton.buttonStyle(.borderedProminent)
                    } else {
                        Button(language.text("Open download page…"), action: model.openReleasePage)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("io.github.macfanpro.download-update")
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 420, idealWidth: 440, minHeight: 360, idealHeight: 430)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.layoutDirection, language.language.isRightToLeft ? .rightToLeft : .leftToRight)
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
