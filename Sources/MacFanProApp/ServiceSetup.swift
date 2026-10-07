import AppKit
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
    private var window: NSWindow?
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

    func present(language: AppLanguageStore) {
        if window == nil {
            let controller = NSHostingController(rootView: ServiceSetupView(setup: self).environmentObject(language))
            let window = NSWindow(contentViewController: controller)
            window.title = "MacFanPro"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
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

struct ServiceSetupView: View {
    @ObservedObject var setup: ServiceSetup
    @EnvironmentObject var language: AppLanguageStore
    @State private var confirmRemoval = false

    private var description: String {
        switch setup.phase {
        case .move: return "Drag MacFanPro into Applications, then open it from there."
        case .homebrew: return "Homebrew manages this installation. Update or repair it using the existing Homebrew instructions."
        case .update: return "The app and background service need to be synchronized. macOS will ask for administrator authorization."
        case .ready: return "The background service is ready. You can use MacFanPro from the menu bar."
        case .working: return "Complete the macOS authorization dialog. Installing or removing the service may take a moment."
        case .removed: return "The service was removed. Fans now use macOS automatic control. You can move MacFanPro to the Trash. Your settings and logs were kept."
        case .checking: return "Checking the background service…"
        case .blocked: return "Setup needs your attention."
        case .install: return "MacFanPro needs a background service to control fans. macOS will ask for administrator authorization."
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "fanblades.fill").font(.system(size: 44)).foregroundStyle(.blue).accessibilityHidden(true)
            Text(language.text("MacFanPro setup")).font(.title2.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(language.text(description)).fixedSize(horizontal: false, vertical: true)
                    if setup.phase == .update {
                        Text(language.text("The service will restart briefly. Your saved profile will resume afterwards."))
                            .font(.callout).foregroundStyle(.secondary)
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
                    if setup.phase == .ready {
                        Button(language.text("Remove background service…"), role: .destructive) { confirmRemoval = true }
                    }
                    if setup.phase == .homebrew {
                        Link(language.text("Installation guide"), destination: URL(string: "https://macfanpro.github.io/macfanpro/" + (language.language == .simplifiedChinese ? "?lang=zh-Hans" : language.language.rawValue + "/") + "#install")!)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 150)
            // The language is chosen in the menu bar panel; this window follows it.
            HStack {
                Button(language.text(setup.phase == .ready ? "Close" : "Later")) { setup.close() }
                    .disabled(setup.phase == .working)
                Spacer()
                if setup.phase == .working || setup.phase == .checking { ProgressView().controlSize(.small) }
                if [.install, .update].contains(setup.phase) {
                    Button(language.text("Check again")) { Task { await setup.check() } }
                    Button(language.text("Install and enable")) { Task { await setup.perform(.install) } }
                        .buttonStyle(.borderedProminent)
                } else if setup.phase == .removed {
                    Button(language.text("Quit")) { NSApp.terminate(nil) }
                } else if setup.phase != .working && setup.phase != .checking && setup.phase != .ready {
                    Button(language.text("Check again")) { Task { await setup.check() } }
                }
            }
        }
        .padding(24).frame(width: 480)
        .background(.background)
        .environment(\.layoutDirection, language.language.isRightToLeft ? .rightToLeft : .leftToRight)
        .alert(language.text("Remove background service?"), isPresented: $confirmRemoval) {
            Button(language.text("Cancel"), role: .cancel) {}
            Button(language.text("Remove"), role: .destructive) { Task { await setup.perform(.uninstall) } }
        } message: {
            Text(language.text("This stops fan control and returns fans to macOS automatic control. Your settings and logs will be kept."))
        }
    }
}
