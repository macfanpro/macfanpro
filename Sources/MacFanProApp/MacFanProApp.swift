//
//  MacFanProApp.swift
//  MacFanPro
//
//  Menu bar app for fan control on Apple Silicon Macs with fans.
//

import SwiftUI
import MacFanProCore
import MacFanProLocalization

class AppDelegate: NSObject, NSApplicationDelegate {
    var supervisesFans = false
    private var duplicateInstance = false
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

    func applicationWillTerminate(_ notification: Notification) {
        // A setup-only or duplicate instance never acquired fan control.
        guard supervisesFans, !duplicateInstance else { return }
        // Reset fans on quit so the daemon doesn't hold stale APP settings — but
        // ONLY if the app owns the hold. A CLI hold (`sudo macfanpro max`) is the
        // user's deliberate, unsupervised choice; quitting the menu bar app must not
        // destroy it — that's the v0.1.7 arbitration feature. Synchronous on purpose:
        // the process is exiting, so an async write would be dropped; both calls are
        // bounded by the sendRaw timeout.
        let client = DaemonClient()
        if let state = try? client.readState(), state.owner == "app" {
            _ = try? client.execute(.releaseAppHold)
        }
        // owner == "cli" → leave the CLI hold alone; owner == "none" → nothing to reset.
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
            MenuBarView(onServiceSetup: {
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
                setup.onReady = { delegate.supervisesFans = true; appState.activateServices() }
                setup.beforeRemoval = { delegate.supervisesFans = false; await appState.pauseForServiceRemoval() }
                setup.afterCancelledRemoval = { appState.activateServices() }
                await setup.launch(language: language)
            }
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
    }
}
