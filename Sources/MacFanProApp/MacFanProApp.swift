//
//  MacFanProApp.swift
//  MacFanPro
//
//  Menu bar app for fan control on Apple Silicon Macs with fans.
//

import SwiftUI
import MacFanProCore
import MacFanProLocalization

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var supervisesFans = false
    private var duplicateInstance = false
    var prepareForTermination: ((@escaping @Sendable () -> Void) -> Void)?
    private var terminating = false
    private var terminationReplied = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Prevent duplicate instances
        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.macfanpro.app"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            duplicateInstance = true
            TFLogger.shared.error("Another instance already running — quitting")
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // A setup-only or duplicate instance never acquired fan control.
        guard supervisesFans, !duplicateInstance, let prepareForTermination else { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true
        // A wedged daemon must not hold up logout behind several 30s requests.
        // Stop heartbeats/admission now; on timeout the daemon watchdog recovers
        // any supervised hold. Both paths share the same one-shot reply.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, !self.terminationReplied else { return }
            TFLogger.shared.error("App exit drain timed out; daemon watchdog will recover app-owned control")
            self.finishTermination()
        }
        prepareForTermination { [weak self] in
            Task { @MainActor in self?.finishTermination() }
        }
        return .terminateLater
    }

    private func finishTermination() {
        guard !terminationReplied else { return }
        terminationReplied = true
        NSApp.reply(toApplicationShouldTerminate: true)
    }
}

@main
struct MacFanProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState(startServices: false)
    @StateObject private var setup = ServiceSetup()
    @StateObject private var language = AppLanguageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(onSettings: {
                setup.present(language: language)
                Task { if setup.phase != .removed { await setup.check() } }
            })
                .environmentObject(appState)
                .environmentObject(language)
        } label: {
            MenuBarLabel(
                state: appState.monitorState,
                maxTemp: appState.maxTemp,
                fahrenheit: appState.useFahrenheit,
                needsDaemonUpdate: appState.daemonVersionMismatch != nil
            )
            .environmentObject(language)
            .task {
                setup.onReady = {
                    delegate.prepareForTermination = { completion in appState.prepareForTermination(completion) }
                    delegate.supervisesFans = true
                    appState.activateServices()
                }
                setup.beforeRemoval = { delegate.supervisesFans = false; await appState.pauseForServiceRemoval() }
                setup.afterCancelledRemoval = { delegate.supervisesFans = true; appState.activateServices() }
                setup.windowContent = {
                    AnyView(SettingsView(setup: setup)
                    .environmentObject(appState)
                    .environmentObject(language))
                }
                await setup.launch(language: language)
            }
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
    }
}
