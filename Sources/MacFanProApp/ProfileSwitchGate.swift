//
//  ProfileSwitchGate.swift
//  MacFanPro
//
//  Orders a profile switch against fan writes the monitor already made for the
//  previous profile. The monitor switches profile on its own queue and each write
//  hops to the main actor, so without this a stale write (a ramp step, or the old
//  profile's max) could land after the reset that ends a profile, and a slow
//  Default could overwrite a profile the user picked after pressing it.
//

import MacFanProCore

struct ProfileSwitchGate {
    private enum Phase: Equatable {
        /// Every write passes.
        case idle
        /// Default's reset is in flight; the token identifies that press.
        case awaitingReset(Int)
        /// A hands-off profile is chosen, but the monitor may still be running the
        /// previous one until it next reports.
        case awaitingMonitor
    }

    private var phase = Phase.idle
    private var presses = 0

    /// Default pressed. Returns the token its reset result must present.
    mutating func defaultPressed() -> Int {
        presses += 1
        phase = .awaitingReset(presses)
        return presses
    }

    /// Default's reset finished. False when a newer action superseded that press,
    /// in which case the caller must not apply the result.
    mutating func resetFinished(_ token: Int, ok: Bool) -> Bool {
        guard phase == .awaitingReset(token) else { return false }
        phase = ok ? .awaitingMonitor : .idle
        return true
    }

    /// A profile picked directly (the picker or Smart).
    mutating func picked(handsOff: Bool) {
        phase = handsOff ? .awaitingMonitor : .idle
    }

    /// The monitor reported the profile it now runs.
    mutating func monitorReported(handsOff: Bool) {
        if phase == .awaitingMonitor, handsOff { phase = .idle }
    }

    /// Whether a write from the monitor may go to the daemon. Only the reset passes
    /// while a switch is pending; until the monitor has switched, a max could be the
    /// old profile's, and macOS's own fan control covers the gap.
    func allows(_ command: FanCommand) -> Bool {
        phase == .idle || command == .resetAuto
    }
}
