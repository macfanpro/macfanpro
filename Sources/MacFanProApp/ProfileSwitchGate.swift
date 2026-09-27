//
//  ProfileSwitchGate.swift
//  MacFanPro
//
//  Orders a profile switch against fan writes the monitor already made for the
//  previous profile. The monitor switches profile on its own queue and each write
//  hops to the main actor, so without this a stale write (a ramp step, or the old
//  profile's max) could land after the reset that ends a profile, and a slow
//  Default could overwrite a profile the user picked after pressing it. The gate
//  reopens when the monitor reports, from its queue, that the switch took effect:
//  writes it made before that arrive first, and the new profile's writes after.
//

import MacFanProCore

struct ProfileSwitchGate {
    private enum Phase: Equatable {
        /// Every write passes.
        case idle
        /// Default's reset is in flight; the token identifies that press.
        case awaitingReset(Int)
        /// A hands-off profile is chosen; the monitor has not yet confirmed the switch
        /// identified by the token.
        case awaitingMonitor(Int)
    }

    private var phase = Phase.idle
    private var actions = 0

    /// Default pressed. Returns the token its reset result and the monitor's switch
    /// confirmation must present.
    mutating func defaultPressed() -> Int {
        actions += 1
        phase = .awaitingReset(actions)
        return actions
    }

    /// Default's reset finished. False when a newer action superseded that press,
    /// in which case the caller must not apply the result.
    mutating func resetFinished(_ token: Int, ok: Bool) -> Bool {
        guard phase == .awaitingReset(token) else { return false }
        phase = ok ? .awaitingMonitor(token) : .idle
        return true
    }

    /// A profile picked directly (the picker or Smart). Returns the token the
    /// monitor's switch confirmation must present.
    mutating func picked(handsOff: Bool) -> Int {
        actions += 1
        phase = handsOff ? .awaitingMonitor(actions) : .idle
        return actions
    }

    /// The monitor confirmed, from its queue, that the switch took effect.
    mutating func switchApplied(_ token: Int) {
        if phase == .awaitingMonitor(token) { phase = .idle }
    }

    /// Whether a write from the monitor may go to the daemon. Only the reset passes
    /// while a switch is pending: until the monitor has switched, a max could be the
    /// old profile's, and macOS's own fan control covers the gap.
    func allows(_ command: FanCommand) -> Bool {
        phase == .idle || command == .resetAuto
    }
}
