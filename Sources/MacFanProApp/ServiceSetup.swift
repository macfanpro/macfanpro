import AppKit
import Combine
import SwiftUI
import MacFanProCore
import MacFanProLocalization

/// Separate from thermal control: checking setup never writes to the daemon.
@MainActor
final class ServiceSetup: ObservableObject {
    enum Phase: Equatable { case checking, move, homebrew, install, update, ready, working, removed, blocked }
    enum Operation: String, Sendable { case install, uninstall }
    enum AuthorizationResult: Sendable { case success, cancelled, failed(String) }
    struct Snapshot: Sendable {
        var version: String?
        var validProtocol = true
        var cliHold = false
        var hasHomebrew = false
        var otherOwner = false
    }
    struct Environment {
        var bundle: URL
        var helperExists: () -> Bool
        var probe: @Sendable () -> Snapshot
        var authorize: @Sendable (Operation) -> AuthorizationResult
        static var live: Environment {
            Environment(bundle: Bundle.main.bundleURL,
                helperExists: { FileManager.default.isExecutableFile(atPath: EmbeddedServiceInstallation.helperPath) },
                probe: {
                    let client = DaemonClient()
                    let response = try? client.request(DaemonRequest(verb: .version))
                    let version = response?.version
                    let state = try? client.readState()
                    var otherOwner = false
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: MacFanProDaemon.plistPath)) {
                        otherOwner = (try? EmbeddedServiceInstallation.validateExistingPlist(data, owner: getuid())) == nil
                    }
                    return Snapshot(version: version, validProtocol: response?.ok == true, cliHold: state?.isCLIHold == true,
                        hasHomebrew: EmbeddedServiceInstallation.homebrewPaths.contains(where: FileManager.default.fileExists(atPath:)),
                        otherOwner: otherOwner)
                }, authorize: { operation in ServiceSetup.authorize(operation, owner: getuid()) })
        }
    }

    @Published private(set) var phase: Phase = .checking
    @Published private(set) var message: String?
    @Published private(set) var diagnostics = ""
    private let environment: Environment
    private(set) var window: NSWindow?
    private var checkedAtLaunch = false
    private var checkInFlight = false
    var onReady: () -> Void = {}
    var beforeRemoval: () async -> Void = {}
    var afterCancelledRemoval: () -> Void = {}

    init(environment: Environment = .live) { self.environment = environment }

    func launch(language: AppLanguageStore) async {
        guard !checkedAtLaunch else { return }
        checkedAtLaunch = true
        await check()
        if phase != .ready { present(language: language) }
    }

    /// The settings window's content. The app supplies it, since the window also
    /// shows AppState's preferences; tests render SettingsView directly.
    var windowContent: () -> AnyView = { AnyView(EmptyView()) }
    private var titleSubscription: AnyCancellable?

    func present(language: AppLanguageStore) {
        if window == nil {
            let controller = NSHostingController(rootView: windowContent())
            // Phases change the service section's height; follow the content.
            controller.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: controller)
            window.title = language.text("MacFanPro setup")
            window.identifier = NSUserInterfaceItemIdentifier("io.github.macfanpro.settings-window")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            // Size to the content before centering: preferredContentSize only takes
            // effect after layout, so centering the initial frame left the grown
            // window off-center. Later opens in a session keep wherever it was moved.
            controller.view.layoutSubtreeIfNeeded()
            window.setContentSize(controller.view.fittingSize)
            window.center()
            self.window = window
            titleSubscription = language.$language.receive(on: DispatchQueue.main).sink { [weak self, weak language] _ in
                guard let language else { return }
                self?.window?.title = language.text("MacFanPro setup")
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.orderOut(nil) }

    func check() async {
        guard phase != .working, !checkInFlight else { return }
        checkInFlight = true
        defer { checkInFlight = false }
        phase = .checking; message = nil; diagnostics = ""
        guard environment.bundle.standardizedFileURL.path == EmbeddedServiceInstallation.appPath,
              environment.bundle.resolvingSymlinksInPath().path == EmbeddedServiceInstallation.appPath else {
            phase = .move; return
        }
        guard environment.helperExists() else {
            phase = .blocked; message = "The app is incomplete. Download a fresh copy of MacFanPro."; return
        }
        let probe = environment.probe
        let snapshot = await Task.detached(priority: .userInitiated) { probe() }.value
        apply(snapshot)
    }

    private func apply(_ snapshot: Snapshot) {
        if snapshot.otherOwner {
            phase = .blocked; message = "The background service belongs to another user account."; return
        }
        if snapshot.version == MacFanProVersion.current && snapshot.validProtocol {
            phase = .ready; onReady(); return
        }
        if snapshot.hasHomebrew { phase = .homebrew; return }
        if let version = snapshot.version, MacFanProVersion.isNewerRelease(version, than: MacFanProVersion.current) {
            phase = .blocked; message = "A newer background service is installed. Download the latest app."; return
        }
        if snapshot.cliHold {
            phase = .blocked; message = "Terminal currently controls the fans. Finish manual control before replacing the service."; return
        }
        phase = snapshot.version == nil ? .install : .update
    }

    func perform(_ operation: Operation) async {
        guard (operation == .install && [.install, .update].contains(phase)) ||
              (operation == .uninstall && phase == .ready) else { return }
        let previous = phase
        phase = .working; message = nil; diagnostics = ""
        let authorize = environment.authorize
        let result = await Task.detached(priority: .userInitiated) { authorize(operation) }.value
        switch result {
        case .cancelled:
            phase = previous; message = "Authorization was cancelled. You can try again."
            if operation == .uninstall { afterCancelledRemoval() }
        case .failed(let details):
            phase = previous; message = "Setup did not finish. Please retry or view the details."
            diagnostics = String(details.prefix(8000))
            if operation == .uninstall { afterCancelledRemoval() }
        case .success:
            if operation == .uninstall {
                // Keep heartbeats running while the user decides in the auth dialog.
                // Once removal completes, drain app writes (the daemon is now gone).
                await beforeRemoval()
                phase = .removed
            } else {
                // A successful authorization is not proof that the service works.
                let probe = environment.probe
                let result = await Task.detached(priority: .userInitiated) { probe() }.value
                if result.version == MacFanProVersion.current && result.validProtocol && !result.otherOwner {
                    phase = .ready; onReady()
                } else {
                    phase = previous; message = "Setup did not finish. Please retry or view the details."
                }
            }
        }
    }

    nonisolated static func command(_ operation: Operation, owner: UInt32) -> String {
        // Both the executable and the verb are fixed; the only variable is an integer.
        "'/Applications/MacFanPro.app/Contents/Helpers/macfanpro' \(operation.rawValue) --embedded-owner-uid \(owner)"
    }

    nonisolated static func authorize(_ operation: Operation, owner: UInt32) -> AuthorizationResult {
        let script = """
        on run argv
            try
                do shell script (item 1 of argv) with administrator privileges
                return "MACFANPRO_OK"
            on error detail number code
                if code is -128 then return "MACFANPRO_CANCELLED"
                error detail number code
            end try
        end run
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, command(operation, owner: owner)]
        let output = Pipe()
        process.standardOutput = output; process.standardError = output
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if process.terminationStatus == 0 && text == "MACFANPRO_CANCELLED" { return .cancelled }
            if process.terminationStatus == 0 && text == "MACFANPRO_OK" { return .success }
            return .failed(text)
        } catch { return .failed(error.localizedDescription) }
    }
}

/// The settings window: everyday preferences moved out of the menu bar panel, plus
/// the background service, which also drives first-run and synchronization.
struct SettingsView: View {
    @ObservedObject var setup: ServiceSetup
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var language: AppLanguageStore
    var onViewUpdate: () -> Void = {}

    var body: some View {
        Form {
            Section(language.text("General")) {
                Picker(language.text("Language"), selection: Binding(get: { language.selection }, set: { language.select($0) })) {
                    ForEach(AppLanguage.allCases) { choice in Text(language.title(for: choice)).tag(choice) }
                }
                .accessibilityIdentifier("io.github.macfanpro.language")
                Picker(language.text("Temperature unit"), selection: $appState.useFahrenheit) {
                    Text("°C").tag(false)
                    Text("°F").tag(true)
                }
                Toggle(language.text("Launch at Login"), isOn: $appState.launchAtLogin)
            }
            Section(language.text("Updates")) {
                LabeledContent(language.text("Version")) {
                    Text(MacFanProVersion.current).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                }
                .accessibilityIdentifier("io.github.macfanpro.version")
                HStack {
                    Text(updateStatus)
                        .foregroundStyle(appState.availableUpdate == nil ? Color.secondary : Color.blue)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("io.github.macfanpro.update-status")
                    Spacer(minLength: 8)
                    Button(language.text(appState.availableUpdate != nil ? "View Update…" :
                        appState.manualUpdateCheck == .failed ? "Retry" : "Check for Updates")) {
                        if appState.availableUpdate != nil { onViewUpdate() } else { appState.checkForUpdatesNow() }
                    }
                    .fixedSize()
                    .disabled(appState.manualUpdateCheck == .checking)
                    .accessibilityIdentifier(appState.availableUpdate == nil ?
                        "io.github.macfanpro.check-updates" : "io.github.macfanpro.view-update")
                }
            }
            Section(language.text("Background service")) {
                ServiceSection(setup: setup)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.layoutDirection, language.language.isRightToLeft ? .rightToLeft : .leftToRight)
        // A manual check's result is transient: closing settings returns the row
        // to "checked automatically" instead of showing a stale "Up to date".
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard (notification.object as? NSWindow)?.identifier?.rawValue == "io.github.macfanpro.settings-window" else { return }
            appState.clearManualUpdateResult()
        }
    }

    private var updateStatus: String {
        if appState.manualUpdateCheck == .checking { return language.text("Checking…") }
        if let update = appState.availableUpdate { return language.text("{version} available", ["version": update.version]) }
        switch appState.manualUpdateCheck {
        case .upToDate: return language.text("Up to date")
        case .failed: return language.text("Couldn't reach GitHub")
        case .available(let version): return language.text("{version} available", ["version": version])
        case .idle, .checking: return language.text("Checked automatically every day")
        }
    }
}

/// The background service: its state, and the setup actions that state allows.
private struct ServiceSection: View {
    @ObservedObject var setup: ServiceSetup
    @EnvironmentObject var language: AppLanguageStore
    @State private var confirmRemoval = false

    private var description: String? {
        switch setup.phase {
        case .move: return "Drag MacFanPro into Applications, then open it from there."
        case .homebrew: return "Homebrew manages this installation. Update or repair it using the existing Homebrew instructions."
        case .update: return "The app and background service need to be synchronized. macOS will ask for administrator authorization."
        case .working: return "Complete the macOS authorization dialog. Installing or removing the service may take a moment."
        case .removed: return "The service was removed. Fans now use macOS automatic control. You can move MacFanPro to the Trash. Your settings and logs were kept."
        case .blocked: return "Setup needs your attention."
        case .install: return "MacFanPro needs a background service to control fans. macOS will ask for administrator authorization."
        case .ready, .checking: return nil
        }
    }

    var body: some View {
        LabeledContent(language.text("Status")) {
            HStack(spacing: 6) {
                switch setup.phase {
                case .ready:
                    Label(language.text("Running {version}", ["version": MacFanProVersion.current]), systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                case .checking, .working:
                    ProgressView().controlSize(.small)
                    Text(language.text(setup.phase == .checking ? "Checking the background service…" : "Working…"))
                        .foregroundStyle(.secondary)
                case .removed:
                    Text(language.text("Removed")).foregroundStyle(.secondary)
                default:
                    Label(language.text("Needs attention"), systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                }
            }
        }
        .accessibilityIdentifier("io.github.macfanpro.service-status")
        if let description {
            Text(language.text(description)).fixedSize(horizontal: false, vertical: true)
        }
        if setup.phase == .update {
            Text(language.text("The service will restart briefly. Your saved profile will resume afterwards."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        if let message = setup.message {
            Text(language.text(message)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
        if !setup.diagnostics.isEmpty {
            DisclosureGroup(language.text("Details")) {
                Text(setup.diagnostics).font(.caption.monospaced()).textSelection(.enabled)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        if setup.phase == .homebrew {
            Link(language.text("Installation guide"), destination: URL(string: "https://macfanpro.github.io/macfanpro/" + (language.language == .simplifiedChinese ? "?lang=zh-Hans" : language.language.rawValue + "/") + "#install")!)
        }
        actions
            .alert(language.text("Remove background service?"), isPresented: $confirmRemoval) {
                Button(language.text("Cancel"), role: .cancel) {}
                Button(language.text("Remove"), role: .destructive) { Task { await setup.perform(.uninstall) } }
            } message: {
                Text(language.text("This stops fan control and returns fans to macOS automatic control. Your settings and logs will be kept."))
            }
    }

    @ViewBuilder
    private var actions: some View {
        switch setup.phase {
        case .ready:
            HStack {
                Text(language.text("Removing it returns the fans to macOS automatic control."))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(language.text("Remove background service…"), role: .destructive) { confirmRemoval = true }
                    .fixedSize()
            }
        case .install, .update:
            HStack {
                Spacer()
                Button(language.text("Check again")) { Task { await setup.check() } }
                Button(language.text("Install and enable")) { Task { await setup.perform(.install) } }
                    .buttonStyle(.borderedProminent)
            }
        case .removed:
            HStack { Spacer(); Button(language.text("Quit")) { NSApp.terminate(nil) } }
        case .move, .homebrew, .blocked:
            HStack { Spacer(); Button(language.text("Check again")) { Task { await setup.check() } } }
        case .checking, .working:
            EmptyView()
        }
    }
}
