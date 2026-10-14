//
//  ThermalStatus+Display.swift
//  MacFanPro
//
//  Which readings the menu shows as "CPU", and the menu bar's headline value.
//
//  Upstream groups the CPU row by the `TC`/`Tp` prefixes, which on M4 pulls in
//  keys that are not core temperatures. Compared against Stats on M4 Max:
//  - `TCDX`/`TCMb` are SoC-level hotspot keys. Under a GPU-only load `TCDX`
//    read 73.3°C while the hottest CPU core read 62–66°C, so GPU heat was
//    reported as CPU temperature.
//  - The `Tp*` keys come in groups of four per core; only one key per group is
//    the core temperature. `Tp02`/`Tp06`/`Tp0A` (read 0.0 when the core is
//    gated, 10–13°C above the core under load) are a different quantity —
//    `Tp06` read 75.2°C under that GPU load.
//  On the M4 generation the CPU row therefore uses the per-core keys Stats maps
//  for it (exelban/stats, Modules/Sensors/values.swift, `Platform.m4Gen`).
//  Other chips keep a prefix grouping. All keys stay in `status()` and in
//  `safetyPeakTemp`, so fan control and the safety floor still follow the
//  hottest point on the die exactly as upstream does.
//  See docs/thermal-sensor-calibration-20260924.md.
//

import Foundation

extension ThermalStatus {

    /// Per-core temperature keys for the M4 generation (M4 / Pro / Max),
    /// as mapped by Stats: efficiency cores `Te*`, performance cores `Tp*`.
    static let m4CoreKeys: Set<String> = [
        "Te05", "Te0S", "Te09", "Te0H",
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e",
    ]

    /// Validated core keys for this Mac's chip; empty when there is no table
    /// for it, which keeps the prefix grouping.
    static let validatedCoreKeys: Set<String> = {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var brand = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0) == 0 else { return [] }
        return String(cString: brand).hasPrefix("Apple M4") ? m4CoreKeys : []
    }()

    private func peak(_ prefixes: [String]) -> Float? {
        temperatures.filter { key, _ in prefixes.contains { key.hasPrefix($0) } }.values.max()
    }

    /// Hottest CPU core.
    public var displayedCPUTemp: Float? {
        cpuTemp(coreKeys: Self.validatedCoreKeys)
    }

    /// With a validated key table, the hottest of those keys. Otherwise — or if
    /// none of them is reporting — the per-core prefixes, then the upstream
    /// `TC*` keys, so the row is never emptier than it was upstream.
    func cpuTemp(coreKeys: Set<String>) -> Float? {
        if let validated = temperatures.filter({ coreKeys.contains($0.key) }).values.max() {
            return validated
        }
        return peak(["Tp", "Te"]) ?? peak(["TC"])
    }

    /// Hottest GPU sensor — the upstream grouping, unchanged.
    public var displayedGPUTemp: Float? {
        peak(["TG", "Tg"])
    }

    /// The menu bar headline: the hotter of the CPU and GPU rows, so the number
    /// beside the icon always matches a row in the panel.
    public var displayedPeakTemp: Float? {
        [displayedCPUTemp, displayedGPUTemp].compactMap { $0 }.max()
    }
}
