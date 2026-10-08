//
//  MenuBarView.swift
//  MacFanPro
//
//  Menu bar dropdown content.
//

import SwiftUI
import MacFanProCore
import MacFanProLocalization

struct MenuBarView: View {
    var onSettings: (() -> Void)? = nil
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var language: AppLanguageStore
    @State private var menuWindow = MenuWindowReader.Reference()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language.text("MacFanPro"))
                    .font(.headline)
                Spacer()
                stateIndicator
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            if appState.daemonUnreachable {
                // Daemon not answering — nothing in the app can touch the fans, so
                // this takes over the top of the menu and offers a one-click fix.
                // The version/hold banners are moot while it's unreachable.
                DaemonDownBanner(onRestart: { appState.restartDaemon() })
                Divider()
            } else {
                // Update-needed banner — shown whenever the daemon is out of sync.
                // Persistent (no dismiss): a stale daemon should keep nagging.
                if let daemonVersion = appState.daemonVersionMismatch {
                    DaemonUpdateBanner(daemonVersion: daemonVersion)
                    Divider()
                }

                // CLI-hold banner — the app is reflecting a hold set from the
                // terminal and won't adjust fans until the user takes over. The
                // Default button (or picking a profile) releases it.
                if let hold = appState.externalHold {
                    ExternalHoldBanner(hold: hold)
                    Divider()
                }
            }

            // Fan speeds
            if let status = appState.latestStatus {
                SectionHeader(title: language.text("FANS"))
                    .padding(.top, 4)
                ForEach(status.fans, id: \.index) { fan in
                    HStack {
                        Text(language.text("Fan {index}", ["index": String(fan.index)]))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(language.text("{rpm} RPM", ["rpm": String(fan.actualRPM)]))
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 1)
                }

                Divider().padding(.vertical, 4)

                // Temperatures
                SectionHeader(title: language.text("TEMPERATURES"))
                TemperatureRow(label: language.text("CPU"), value: appState.latestStatus?.displayedCPUTemp, fahrenheit: appState.useFahrenheit)
                TemperatureRow(label: language.text("GPU"), value: peakTemp(prefixes: ["TG", "Tg"]), fahrenheit: appState.useFahrenheit)
                TemperatureRow(label: language.text("RAM"), value: peakTemp(prefixes: ["TR", "Tm", "TM"]), fahrenheit: appState.useFahrenheit)
                TemperatureRow(label: language.text("SSD"), value: peakTemp(prefixes: ["TH"]), fahrenheit: appState.useFahrenheit)
                TemperatureRow(label: language.text("Ambient"), value: peakTemp(prefixes: ["TA"]), fahrenheit: appState.useFahrenheit)
            } else {
                Text(language.text("Reading sensors..."))
                    .foregroundStyle(.secondary)
                    .padding(12)
            }

            Divider().padding(.vertical, 4)

            // Profile picker
            SectionHeader(title: language.text("PROFILE"))
            Picker(language.text("Profile"), selection: Binding(
                get: { appState.activeProfile.id },
                set: { id in
                    if let profile = FanProfile.builtIn.first(where: { $0.id == id }) {
                        appState.selectProfile(profile)
                    }
                }
            )) {
                ForEach(FanProfile.builtIn) { profile in
                    HStack {
                        Text(language.text(profile.name))
                        Spacer()
                        if !profile.curve.handsOff {
                            let unit = appState.useFahrenheit ? "F" : "C"
                            if profile.curve.instantEngage {
                                // Max: show instant trigger temp
                                let startC = profile.curve.startTemp
                                let startDisp = appState.useFahrenheit ? startC * 9 / 5 + 32 : startC
                                Text(language.text("{temperature}°{unit} instant", ["temperature": String(Int(startDisp)), "unit": unit]))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                let startC = profile.curve.startTemp
                                let ceilC = profile.curve.ceilingTemp
                                let startDisp = appState.useFahrenheit ? startC * 9 / 5 + 32 : startC
                                let ceilDisp = appState.useFahrenheit ? ceilC * 9 / 5 + 32 : ceilC
                                Text("\(Int(startDisp))→\(Int(ceilDisp))°\(unit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tag(profile.id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 1)

            Divider().padding(.vertical, 4)

            // Quick actions
            HStack(spacing: 8) {
                // Toggle-as-button holds the system fill while Smart is the active
                // profile — Apple draws it, it honors .tint, and it adapts to light/dark.
                Toggle(isOn: Binding(
                    get: { appState.activeProfile.id == "smart" },
                    set: { isOn in
                        if isOn {
                            appState.setSmart()
                        } else {
                            // Turning Smart off returns fans to Apple's default (Silent),
                            // same as the Default button. Required so the toggle can turn
                            // off at all — otherwise `get` stays true and snaps it back on.
                            appState.resetAuto()
                        }
                    }
                )) {
                    IconLabel(title: language.text("Smart"), systemImage: "fan.fill")
                        .frame(maxWidth: .infinity)
                }
                .toggleStyle(.button)
                .tint(.orange)

                Button(action: { appState.resetAuto() }) {
                    IconLabel(title: language.text("Default"), systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider().padding(.vertical, 4)

            // Preferences (language, units, login item, version, updates and the
            // background service) live in the settings window. The panel keeps only
            // what is checked or changed often, plus an update offer while one exists.
            if let update = appState.availableUpdate {
                // One clickable row (no separate button), so long translations of
                // "View Update" never squeeze the version into a narrow column. It
                // opens settings, whose last section offers the update.
                Button {
                    menuWindow.window?.orderOut(nil)
                    onSettings?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text(language.text("{version} available", ["version": update.version]))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("io.github.macfanpro.update-status")
                        Spacer(minLength: 8)
                        Image(systemName: language.language.isRightToLeft ? "chevron.left" : "chevron.right")
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help(language.text("View Update"))
                .accessibilityIdentifier("io.github.macfanpro.view-update")
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                Divider().padding(.vertical, 4)
            }

            HStack {
                // A button like Settings…, so the two footer actions read as a pair.
                Button(action: { NSApp.terminate(nil) }) {
                    IconLabel(title: language.text("Quit"), systemImage: "rectangle.portrait.and.arrow.right")
                }
                .keyboardShortcut("q", modifiers: .command)
                .fixedSize()
                .accessibilityIdentifier("io.github.macfanpro.quit")
                Spacer()
                if let onSettings {
                    Button {
                        menuWindow.window?.orderOut(nil)
                        onSettings()
                    } label: {
                        HStack(spacing: 4) {
                            // A pending update also marks the way to its details.
                            if appState.availableUpdate != nil {
                                Circle().fill(Color.blue).frame(width: 6, height: 6)
                                    .accessibilityLabel(language.text("Update available"))
                            }
                            IconLabel(title: language.text("Settings"), systemImage: "gearshape")
                        }
                    }
                    .keyboardShortcut(",", modifiers: .command)
                    .fixedSize()
                    .accessibilityIdentifier("io.github.macfanpro.settings")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .frame(width: 260)
        // Measure the content's ideal height, including any temporary banners.
        .fixedSize(horizontal: false, vertical: true)
        // The language is chosen in the app, not taken from the system locale, so
        // mirror the panel for right-to-left languages here.
        .environment(\.layoutDirection, language.language.isRightToLeft ? .rightToLeft : .leftToRight)
        .background(MenuWindowReader { menuWindow.window = $0 })
    }

    // MARK: - Helpers

    @ViewBuilder
    private var stateIndicator: some View {
        switch appState.monitorState {
        case .safetyOverride:
            Label(language.text("SAFETY"), systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case .active(let name):
            Label(language.text(name), systemImage: "fan.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .idle:
            Label(language.text("Idle"), systemImage: "fan")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func peakTemp(prefixes: [String]) -> Float? {
        guard let temps = appState.latestStatus?.temperatures else { return nil }
        let values = temps.filter { key, _ in prefixes.contains(where: { key.hasPrefix($0) }) }.values
        return values.max()
    }
}

private struct MenuWindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    final class Reference {
        weak var window: NSWindow?
    }

    func makeNSView(context: Context) -> Reader {
        let view = Reader()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: Reader, context: Context) { view.onWindow = onWindow }

    final class Reader: NSView {
        var onWindow: (NSWindow?) -> Void = { _ in }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let window = window
            DispatchQueue.main.async { [weak self] in self?.onWindow(window) }
        }
    }
}

// MARK: - Subviews

/// Banner shown when a hold was set from the CLI. Explains what's pinned and how
/// to release it without needing to know any terminal commands.
private struct ExternalHoldBanner: View {
    @EnvironmentObject var language: AppLanguageStore
    let hold: DaemonHoldState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(language.text("Fans held from Terminal"), systemImage: "terminal.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            Text(describe(hold.command))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(language.text("Press Default below (or pick a profile) to release."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
    }

    private func describe(_ command: String?) -> String {
        let parts = (command ?? "").split(separator: " ").map(String.init)
        switch parts.first {
        // Approximate language on purpose: the held value is the fan's TARGET, but the
        // RPM shown in the fan rows is the actual tach, which hovers ~1% around it. Exact
        // wording ("pinned to 3500") next to a row reading 3488/3512 looks like a bug.
        case "max":
            return language.text("Fans are held at maximum. The app won't adjust them until you take over.")
        case "set" where parts.count > 1:
            return language.text("Fans are held at about {rpm} RPM. The app won't adjust them until you take over.", ["rpm": parts[1]])
        case "setfan" where parts.count > 2:
            return language.text("Fan {fan} is held at about {rpm} RPM. The app won't adjust fans until you take over.", ["fan": parts[1], "rpm": parts[2]])
        default:
            return language.text("Fans are held manually. The app won't adjust them until you take over.")
        }
    }
}

/// Non-modal in-menu banner telling the user the background daemon is out of
/// sync and exactly how to fix it. Command is selectable so it can be copied.
private struct DaemonUpdateBanner: View {
    @EnvironmentObject var language: AppLanguageStore
    let daemonVersion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(language.text("Update needed"), systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            Text(language.text("The background service is running {daemonVersion}, but the app is {appVersion}. Fan control may not match what you set until they're re-synced.", ["daemonVersion": daemonVersion, "appVersion": MacFanProVersion.current]))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(language.text("Run this in Terminal:"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)

            Text("sudo macfanpro install")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
    }
}

/// Shown when the daemon has stopped answering — fan control is impossible until
/// it's back. Offers a one-click restart (launchd kickstart via a macOS admin
/// prompt). The daemon's KeepAlive usually restarts it on its own, so this is the
/// manual nudge for the rare stuck case; it never asks the user to reinstall.
private struct DaemonDownBanner: View {
    @EnvironmentObject var language: AppLanguageStore
    let onRestart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(language.text("Fan control unavailable"), systemImage: "exclamationmark.octagon.fill")
                .font(.caption.bold())
                .foregroundStyle(.red)

            Text(language.text("The background service isn't responding, so profiles and Default can't change the fans right now."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onRestart) {
                Label(language.text("Restart daemon"), systemImage: "arrow.clockwise")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.top, 2)

            Text(language.text("Asks for your password once. If it doesn't come back right away, it will keep retrying on its own."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12))
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.bottom, 2)
    }
}

private struct TemperatureRow: View {
    let label: String
    let value: Float?
    var fahrenheit: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            if let tempC = value {
                let display = fahrenheit ? tempC * 9 / 5 + 32 : tempC
                let unit = fahrenheit ? "F" : "C"
                Text("\(String(format: "%.1f", display))°\(unit)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(tempColor(tempC))
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 1)
    }

    /// Color thresholds always based on °C
    private func tempColor(_ temp: Float) -> Color {
        if temp >= 90 { return .red }
        if temp >= 75 { return .orange }
        if temp >= 60 { return .yellow }
        return .primary
    }
}
