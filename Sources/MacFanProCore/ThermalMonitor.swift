//
//  ThermalMonitor.swift
//  MacFanPro
//
//  Polling engine that reads temperatures and applies fan profiles.
//
//  Dual-cadence design:
//  - Thermal tick (100ms): read temps, calculate curve, apply ramp governor, write fan speed
//  - Monitor tick (2s): process capture, anomaly detection, history logging
//

import Darwin
import Foundation

// MARK: - Fan Commands

public enum FanCommand: Equatable, Sendable {
    case setMax
    case setRPM(Float)
    case setFan(index: Int, rpm: Float)
    case resetAuto
    /// Background app release; the daemon refuses it while a CLI hold is active.
    case releaseAppHold

    /// A hold keeps fans at a manual setting (so an unsupervised one-shot could
    /// be reverted by the watchdog); resetAuto hands control back and isn't held.
    public var isHold: Bool {
        switch self {
        case .setMax, .setRPM, .setFan: return true
        case .resetAuto, .releaseAppHold: return false
        }
    }

    /// Per-fan commands need the 0.1.5 `setfan` socket verb; older daemons
    /// reject them, so the router must version-gate and fall back to direct SMC.
    public var isPerFan: Bool {
        if case .setFan = self { return true }
        return false
    }
}

// MARK: - Monitor State

public enum MonitorState: Equatable {
    case idle
    case active(profileName: String)
    case safetyOverride
}

// MARK: - Thermal Monitor

/// Control state is confined to `queue`; configure callbacks before starting.
public final class ThermalMonitor: @unchecked Sendable {
    private let fanControl: FanControl
    private let logger: TFLogger?
    private let loadCalibration: () -> CalibrationData?
    private let now: () -> Date
    private let captureProcesses: (() -> String)?
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "io.github.macfanpro.monitor")
    private let queueKey = DispatchSpecificKey<Bool>()

    public private(set) var activeProfile: FanProfile
    public private(set) var state: MonitorState = .idle
    public private(set) var latestStatus: ThermalStatus?

    // MARK: - Tick Timing

    /// Thermal tick interval in seconds. Fan control runs at this rate.
    /// Seconds per tick, for the sustained trigger and ramp rates. Set by start().
    private var tickInterval: Float

    /// Monitor cadence: process capture + anomaly detection every N thermal ticks.
    /// At 100ms thermal tick, 20 × 0.1s = 2 seconds.
    private static let monitorCadence = 20

    /// UI update cadence: onUpdate fires every N thermal ticks.
    /// At 100ms thermal tick, 5 × 0.1s = 500ms — smooth UI without excessive redraws.
    private static let uiUpdateCadence = 5

    private var tickCounter = 0

    // MARK: - Fan State

    private var lastAppliedRPMPercent: Float = 0
    /// Accumulates sub-threshold ramp steps independently of acknowledged writes.
    private var rampedRPMPercent: Float = 0
    /// Latch the temperature demand independently of a successful max write, so
    /// a failed/pending max is still retried in the 90–95°C hysteresis band.
    private var safetyDemand = false
    private var profileGeneration = 0
    private var pendingCommand = false
    /// False while a write is outstanding or failed: even an unchanged target must
    /// be re-established because the daemon may have recovered to auto meanwhile.
    private var commandConfirmed = false
    private var failedCommand: (command: FanCommand, attempts: Int, retryAfter: Date)?
    private var fansCurrentlyRunning = false
    /// A write may have acquired manual control, even if it failed or belongs to a
    /// previous profile. Keep its release obligation separate from profile engagement.
    private var needsRelease = false
    private var sustainedAboveSeconds: TimeInterval = 0

    // MARK: - Smart Profile State

    private var tempHistory: [Float] = []

    // MARK: - Anomaly Detection

    /// Tracks temps over 30 seconds (15 readings at 2s monitor cadence)
    private var anomalyHistory: [Float] = []
    private var isCalibrating = false

    // MARK: - Process Buffer

    /// Rolling buffer — captures what was running BEFORE a spike.
    /// 15 snapshots × 2 seconds = 30 seconds of pre-spike history.
    private var processBuffer: [(timestamp: String, processes: String)] = []
    private let isoFormatter = ISO8601DateFormatter()

    /// Call this to suppress anomaly logging during calibration
    public func setCalibrating(_ value: Bool) {
        queue.async { self.isCalibrating = value }
    }
    private var calibration: CalibrationData?

    /// Called on UI update cadence (every 500ms) with updated status.
    public var onUpdate: ((ThermalStatus, FanProfile, MonitorState) -> Void)?
    /// Synchronous execution, used by CLI watch. Throwing leaves the command pending
    /// in the control state so it is retried while still required.
    public var onFanCommand: ((FanCommand) throws -> Void)?
    /// GUI execution remains off-main. State is committed only after acknowledgement;
    /// at most one monitor write is outstanding, with bounded backoff on failure.
    public var onFanCommandAsync: ((FanCommand, @escaping @Sendable (Bool) -> Void) -> Void)?

    public convenience init(fanControl: FanControl, profile: FanProfile = .silent) {
        self.init(fanControl: fanControl, profile: profile, interval: 0.1, logger: .shared,
                  loadCalibration: CalibrationData.load, now: Date.init, captureProcesses: nil)
    }

    /// Injected log/clock/calibration/process capture keep control-loop tests isolated
    /// from the user's logs and calibration, while exercising the production loop.
    init(fanControl: FanControl, profile: FanProfile, interval: TimeInterval,
         logger: TFLogger?, loadCalibration: @escaping () -> CalibrationData?,
         now: @escaping () -> Date, captureProcesses: (() -> String)?) {
        self.fanControl = fanControl
        self.activeProfile = profile
        self.tickInterval = Float(interval)
        self.logger = logger
        self.loadCalibration = loadCalibration
        self.now = now
        self.captureProcesses = captureProcesses
        queue.setSpecific(key: queueKey, value: true)
        let loaded = loadCalibration()
        if let error = loaded?.validationError {
            logger?.error("Calibration data rejected: \(error)")
        } else {
            calibration = loaded
        }
    }

    /// A single serialized sample, without installing a timer.
    func pollOnce() { onQueue { tick() } }

    private func onQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) == true { return work() }
        return queue.sync(execute: work)
    }

    // MARK: - Lifecycle

    public func start(interval: TimeInterval = 0.1) {
        stop()
        onQueue {
            tickInterval = Float(interval)
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: interval)
            timer.setEventHandler { [weak self] in self?.tick() }
            timer.resume()
            self.timer = timer
        }
    }

    public func stop() {
        onQueue {
            timer?.cancel()
            timer = nil
        }
    }

    /// Update the active profile. `applied`, if given, runs on the monitor's queue once
    /// the switch has taken effect, after any command the previous profile issued.
    public func switchProfile(_ profile: FanProfile, applied: (@Sendable () -> Void)? = nil) {
        queue.async { [self] in
            activeProfile = profile
            profileGeneration += 1
            commandConfirmed = false
            failedCommand = nil
            lastAppliedRPMPercent = 0
            rampedRPMPercent = 0
            // Preserve needsRelease for an earlier write, but keep the new profile's
            // own sustained-start timing and engagement state.
            fansCurrentlyRunning = false
            sustainedAboveSeconds = 0
            tickCounter = 0

            if profile.id == "smart" {
                // Reset Smart state and reload calibration data
                tempHistory.removeAll()
                let loaded = loadCalibration()
                if let error = loaded?.validationError {
                    logger?.error("Calibration data rejected on reload: \(error)")
                    calibration = nil
                } else {
                    calibration = loaded
                }
            }

            state = .idle
            applied?()
        }
    }

    // MARK: - Polling

    private func tick() {
        guard let status = try? fanControl.status() else { return }
        latestStatus = status

        // Peak CPU (TC/Tp) + GPU (TG/Tg) — the shared safety-floor sensor extraction,
        // so the client monitor and the daemon's floor read the identical value.
        let maxTemp = status.safetyPeakTemp

        // Monitor cadence: process capture + anomaly detection (every 2 seconds)
        if tickCounter % Self.monitorCadence == 0 {
            monitorTick(status: status, maxTemp: maxTemp)
        }

        if maxTemp >= FanProfile.safetyTempThreshold { safetyDemand = true }
        if maxTemp < FanProfile.safetyTempThreshold - FanProfile.hysteresisDegrees { safetyDemand = false }
        if safetyDemand {
            if state != .safetyOverride || !commandConfirmed {
                applyCommand(.setMax) { [self] in
                    state = .safetyOverride
                    fansCurrentlyRunning = true
                    lastAppliedRPMPercent = 1.0
                    rampedRPMPercent = 1.0
                    logger?.safety("Override triggered: \(String(format: "%.1f", maxTemp))°C — fans maxed")
                }
            }
            if tickCounter % Self.uiUpdateCadence == 0 {
                onUpdate?(status, activeProfile, state)
            }
            tickCounter += 1
            return
        }

        // Sustained trigger: track consecutive ticks above start threshold.
        // Track elapsed seconds so custom intervals do not truncate the duration.
        let startThreshold = activeProfile.curve.startTemp
        if maxTemp >= startThreshold {
            sustainedAboveSeconds += TimeInterval(tickInterval)
        } else {
            sustainedAboveSeconds = 0
        }

        // Profile-specific logic
        if activeProfile.id == "smart" {
            tickSmart(status: status, peakTemp: maxTemp)
        } else {
            tickCurve(status: status, peakTemp: maxTemp)
        }

        // UI update at slower cadence (every 500ms)
        if tickCounter % Self.uiUpdateCadence == 0 {
            onUpdate?(status, activeProfile, state)
        }

        tickCounter += 1
    }

    // MARK: - Monitor Cadence (every 2 seconds)

    /// Heavy operations: process capture + anomaly detection.
    /// Runs at 2-second intervals to avoid sysctl overhead at 100ms.
    private func monitorTick(status: ThermalStatus, maxTemp: Float) {
        // Rolling process buffer — always capturing, like a security camera
        let currentProcs = captureProcesses?() ?? captureTopProcesses()
        let ts = isoFormatter.string(from: now())
        processBuffer.append((timestamp: ts, processes: currentProcs))
        if processBuffer.count > 15 { processBuffer.removeFirst() }

        // Anomaly detection: two tiers
        // Tier 1: instant spike — >5°C between consecutive readings (2 seconds)
        // Tier 2: sustained change — >10°C over 30 seconds
        if !isCalibrating {
            var spikeDetected = false

            // Tier 1: check against previous reading
            if let prevTemp = anomalyHistory.last {
                let instantDelta = maxTemp - prevTemp
                if abs(instantDelta) > 5 {
                    let direction = instantDelta > 0 ? "spike" : "drop"
                    let fan0 = status.fans.first
                    logger?.info(
                        "Instant \(direction): \(String(format: "%.1f", prevTemp))→\(String(format: "%.1f", maxTemp))°C " +
                        "(\(String(format: "%+.1f", instantDelta))°C in 2s) | " +
                        "Fan0: \(fan0?.actualRPM ?? 0) RPM (\(fan0?.mode ?? "?")) | " +
                        "Profile: \(activeProfile.name)"
                    )
                    spikeDetected = true
                }
            }

            // Tier 2: check over 30-second window
            if anomalyHistory.count >= 15 {
                let oldest = anomalyHistory.first!
                let sustainedDelta = maxTemp - oldest
                if abs(sustainedDelta) > 10 {
                    let direction = sustainedDelta > 0 ? "spike" : "drop"
                    let fan0 = status.fans.first
                    logger?.info(
                        "Sustained \(direction): \(String(format: "%.1f", oldest))→\(String(format: "%.1f", maxTemp))°C " +
                        "(\(String(format: "%+.1f", sustainedDelta))°C in 30s) | " +
                        "Fan0: \(fan0?.actualRPM ?? 0) RPM (\(fan0?.mode ?? "?")) | " +
                        "Profile: \(activeProfile.name)"
                    )
                    spikeDetected = true
                    anomalyHistory.removeAll()
                }
            }

            // Dump the rolling buffer on any spike — shows what was running BEFORE
            if spikeDetected {
                logger?.info("Pre-spike process history (last \(processBuffer.count * 2)s):")
                for entry in processBuffer {
                    logger?.info("  \(entry.timestamp): \(entry.processes)")
                }
            }
        }

        anomalyHistory.append(maxTemp)
        if anomalyHistory.count > 15 { anomalyHistory.removeFirst() }
    }

    // MARK: - Smart Profile

    /// Target temperature ceiling — keep below this to avoid any throttling
    private static let smartCeiling: Float = 85.0
    /// Smart starts earlier than other profiles to get ahead of rising temps
    private static let smartFloor: Float = 53.0

    /// All profiles share the same off threshold — 50°C matches Apple's observed stop range
    private static let smartStopTemp: Float = 50.0

    private func tickSmart(status: ThermalStatus, peakTemp: Float) {
        // Sample temperature history at monitor cadence (2s) for stable rate-of-change
        if tickCounter % Self.monitorCadence == 0 {
            tempHistory.append(peakTemp)
            if tempHistory.count > 4 { tempHistory.removeFirst() }
        }

        let maxRPM = status.fans.first.map { Float($0.maxRPM) } ?? 7826
        let minRPM = status.fans.first.map { Float($0.minRPM) } ?? 2317
        let minPct = minRPM / maxRPM

        // Below stop threshold and fans running: turn off (with hysteresis)
        if peakTemp < Self.smartStopTemp && needsRelease && rateOfChange() <= 0 {
            applyCommand(.resetAuto) { [self] in
                lastAppliedRPMPercent = 0
                rampedRPMPercent = 0
                fansCurrentlyRunning = false
                state = .idle
                logger?.fan("Smart fans off: \(String(format: "%.1f", peakTemp))°C below \(Int(Self.smartStopTemp))°C")
            }
            return
        }

        // Below floor and fans not running: stay off
        if peakTemp < Self.smartFloor && !fansCurrentlyRunning {
            return
        }

        // In hysteresis band (50-53°C): maintain current state
        if peakTemp >= Self.smartStopTemp && peakTemp < Self.smartFloor && !fansCurrentlyRunning {
            return
        }

        // Sustained trigger: per-profile duration
        if !fansCurrentlyRunning && sustainedAboveSeconds < TimeInterval(activeProfile.curve.sustainedTriggerSec) {
            return
        }

        let rate = rateOfChange()
        var targetPct: Float

        if let cal = calibration, let calPct = cal.fanPercentForTemp(peakTemp) {
            // Calibrated: use machine-specific temp→fan lookup
            targetPct = calPct

            if rate > 0 {
                // Rising: boost proportionally to rate and proximity to ceiling
                let urgency = min(max((peakTemp - Self.smartFloor) / (Self.smartCeiling - Self.smartFloor), 0), 1)
                targetPct = min(targetPct + rate * 0.15 * (1 + urgency), 1.0)
            }
        } else {
            // Uncalibrated: S-curve (matches profile curveShape)
            let range = Self.smartCeiling - Self.smartFloor
            let position = min(max((peakTemp - Self.smartFloor) / range, 0), 1)
            targetPct = position * position * (3 - 2 * position)

            if rate > 0 {
                targetPct = min(targetPct + rate * 0.2, 1.0)
            }
        }

        if peakTemp > Self.smartCeiling {
            targetPct = 1.0
        }

        // Clamp to valid range, enforce minimum RPM
        targetPct = min(max(targetPct, 0), 1.0)
        if targetPct > 0 && targetPct < minPct {
            targetPct = minPct
        }

        // Ramp governors — per-profile rates, per-tick amounts
        let rampUp = activeProfile.curve.rampUpPerSec * tickInterval
        let rampDown = activeProfile.curve.rampDownPerSec * tickInterval

        if targetPct > rampedRPMPercent {
            targetPct = min(targetPct, rampedRPMPercent + rampUp)
        } else if targetPct < rampedRPMPercent {
            targetPct = max(targetPct, rampedRPMPercent - rampDown)
        }

        rampedRPMPercent = targetPct
        // Accumulate even when this tick is too small to justify an SMC write.
        if !commandConfirmed || abs(targetPct - lastAppliedRPMPercent) > 0.002 {
            let targetRPM = max(maxRPM * targetPct, minRPM)
            let appliedPercent = targetPct
            applyCommand(.setRPM(targetRPM)) { [self] in
                if !fansCurrentlyRunning {
                    logger?.fan("Smart fans on: \(Int(targetRPM)) RPM at \(String(format: "%.1f", peakTemp))°C")
                }

                lastAppliedRPMPercent = appliedPercent
                fansCurrentlyRunning = true
                state = .active(profileName: "Smart")
            }
        } else if fansCurrentlyRunning {
            state = .active(profileName: "Smart")
        }
    }

    /// Temperature rate of change in °C per second (smoothed over history).
    /// History is sampled at monitor cadence (2s), so this covers ~8 seconds.
    private func rateOfChange() -> Float {
        guard tempHistory.count >= 2 else { return 0 }
        let oldest = tempHistory.first!
        let newest = tempHistory.last!
        // tempHistory sampled at monitor cadence (2s intervals)
        let seconds = Float(tempHistory.count - 1) * Float(Self.monitorCadence) * tickInterval
        return (newest - oldest) / seconds
    }

    // MARK: - Curve-Based Profiles

    private func tickCurve(status: ThermalStatus, peakTemp: Float) {
        let curve = activeProfile.curve
        let maxRPM = status.fans.first.map { Float($0.maxRPM) } ?? 7826
        let minRPM = status.fans.first.map { Float($0.minRPM) } ?? 2317

        // Hands-off profiles (Silent): don't control fans, just monitor
        if curve.handsOff {
            if needsRelease {
                applyCommand(.resetAuto) { [self] in
                    fansCurrentlyRunning = false
                    lastAppliedRPMPercent = 0
                    rampedRPMPercent = 0
                    state = .idle
                    logger?.fan("Fans returned to auto [\(activeProfile.name)]")
                }
            }
            return
        }

        // Get target from curve (now applies curve shape: easeIn, linear, easeOut, sCurve)
        guard let rawTarget = curve.targetPercent(at: peakTemp, fansCurrentlyRunning: fansCurrentlyRunning) else {
            // Curve says fans should be off
            if needsRelease {
                applyCommand(.resetAuto) { [self] in
                    fansCurrentlyRunning = false
                    lastAppliedRPMPercent = 0
                    rampedRPMPercent = 0
                    state = .idle
                    logger?.fan("Fans off: \(String(format: "%.1f", peakTemp))°C below \(Int(curve.stopTemp))°C [\(activeProfile.name)]")
                }
            }
            return
        }

        // Sustained trigger: per-profile duration.
        // Measured in seconds at the configured tick interval.
        if !fansCurrentlyRunning && sustainedAboveSeconds < TimeInterval(curve.sustainedTriggerSec) {
            return
        }

        // 0.001 signals "keep at minimum" (hysteresis band)
        var targetPct = rawTarget <= 0.001 ? minRPM / maxRPM : rawTarget

        // Clamp to valid range
        targetPct = min(max(targetPct, minRPM / maxRPM), curve.maxRPMPercent)

        // Ramp governors — per-profile rates, per-tick amounts
        let rampUp = curve.rampUpPerSec * tickInterval
        let rampDown = curve.rampDownPerSec * tickInterval

        if targetPct > rampedRPMPercent {
            if !curve.instantEngage {
                // Governed ramp-up
                targetPct = min(targetPct, rampedRPMPercent + rampUp)
            }
            // instantEngage: skip governor, jump directly to target
        } else if targetPct < rampedRPMPercent {
            // Ramp-down governor always applies (even for instantEngage profiles)
            targetPct = max(targetPct, rampedRPMPercent - rampDown)
        }

        rampedRPMPercent = targetPct
        // Accumulate even when this tick is too small to justify an SMC write.
        if !commandConfirmed || abs(targetPct - lastAppliedRPMPercent) > 0.002 {
            let targetRPM = max(maxRPM * targetPct, minRPM)
            let appliedPercent = targetPct
            applyCommand(.setRPM(targetRPM)) { [self] in
                if !fansCurrentlyRunning {
                    logger?.fan("Fans on: \(Int(targetRPM)) RPM at \(String(format: "%.1f", peakTemp))°C [\(activeProfile.name)]")
                }

                lastAppliedRPMPercent = appliedPercent
                fansCurrentlyRunning = true
                state = .active(profileName: activeProfile.name)
            }
        } else if fansCurrentlyRunning {
            state = .active(profileName: activeProfile.name)
        }
    }

    // MARK: - Process Capture

    /// Capture top 5 processes by CPU for anomaly logging
    private func captureTopProcesses() -> String {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return "unavailable" }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return "unavailable" }

        let actualCount = size / MemoryLayout<kinfo_proc>.stride
        var results: [(name: String, cpu: Double)] = []

        for i in 0..<actualCount {
            let proc = procs[i]
            let pid = proc.kp_proc.p_pid
            guard pid > 0 else { continue }

            let name = withUnsafePointer(to: proc.kp_proc.p_comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) {
                    String(cString: $0)
                }
            }

            guard !name.isEmpty, name != "kernel_task" else { continue }
            let cpuPct = Double(proc.kp_proc.p_pctcpu) / 100.0
            if cpuPct > 0.1 {
                results.append((name, cpuPct))
            }
        }

        let top5 = results.sorted { $0.cpu > $1.cpu }.prefix(5)
        if top5.isEmpty { return "idle" }
        return top5.map { "\($0.name)(\(String(format: "%.1f", $0.cpu))%)" }.joined(separator: ", ")
    }

    // MARK: - Helpers

    private func applyCommand(_ command: FanCommand, onSuccess: @escaping @Sendable () -> Void) {
        guard !pendingCommand else { return }
        if let failed = failedCommand, failed.command == command, now() < failed.retryAfter { return }
        let generation = profileGeneration
        if let execute = onFanCommandAsync {
            pendingCommand = true
            commandConfirmed = false
            if command.isHold { needsRelease = true }
            execute(command) { [weak self] ok in
                guard let self else { return }
                self.queue.async { [self] in
                    self.pendingCommand = false
                    // A later profile choice invalidates both the old acknowledgement
                    // and its retry; it must never restore the previous profile's state.
                    guard generation == self.profileGeneration else { return }
                    self.commandFinished(command, ok: ok, onSuccess: onSuccess)
                }
            }
        } else if let execute = onFanCommand {
            commandConfirmed = false
            if command.isHold { needsRelease = true }
            do {
                try execute(command)
                commandFinished(command, ok: true, onSuccess: onSuccess)
            } catch {
                logger?.error("Fan command failed: \(command) — \(error)")
                commandFinished(command, ok: false, onSuccess: onSuccess)
            }
        }
    }

    private func commandFinished(_ command: FanCommand, ok: Bool, onSuccess: () -> Void) {
        if ok {
            commandConfirmed = true
            if !command.isHold { needsRelease = false }
            failedCommand = nil
            onSuccess()
        } else {
            let attempts = failedCommand?.command == command ? (failedCommand?.attempts ?? 0) + 1 : 1
            failedCommand = (command, min(attempts, 15), now().addingTimeInterval(Double(min(attempts, 15) * 2)))
        }
    }
}
