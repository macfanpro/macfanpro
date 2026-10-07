# Temperature changes relative to upstream

What MacFanPro changes in upstream ThermalForge's temperature code, and how to
re-apply it after merging an upstream release. Scope: the 0.2.3.16 sensor
fixes only. The product rename and earlier fork changes are recorded in
`docs/upstream-followups-20260921.md` and the changelog.

For the latest connection and installer decisions, see the
[2026-10-04 upstream merge review](upstream-sync-20261004.md).

The logic lives in new files so merges touch as few upstream lines as possible:

| New file | Purpose |
|---|---|
| `Sources/MacFanProCore/SMCSensorFilter.swift` | Drops SMC keys that IOHID identifies as battery sensors, and die readings below 10°C |
| `Sources/MacFanProCore/ThermalStatus+Display.swift` | CPU row = per-core keys (Stats' M4 map on the M4 generation); headline = hotter of CPU and GPU rows |
| `Tests/MacFanProTests/SMCSensorFilterTests.swift`, `DisplayedTemperatureTests.swift` | Coverage for both |

## Upstream lines changed

| File | Change | Why |
|---|---|---|
| `Sources/MacFanProCore/FanControl.swift`, `readTemp` | +1 line: `guard SMCSensorFilter.accepts(key, temp) else { return nil }` after the 0–150°C range check | Single choke point shared by `status()` and the daemon's safety sweep |
| `Sources/MacFanProCore/FanControl.swift`, `thermalKeys` | +2 lines after the `Tp*` block: comment and `"Tp0V", "Tp0Y", "Tp0e", "Te05", "Te0S", "Te09", "Te0H"` | M4 core keys upstream does not probe |
| `Sources/MacFanProApp/MenuBarView.swift`, CPU `TemperatureRow` | `peakTemp(prefixes: ["TC", "Tp"])` → `appState.latestStatus?.displayedCPUTemp` | CPU row uses core keys, not hotspot keys |
| `Sources/MacFanProApp/AppState.swift`, `startMonitoring` `onUpdate` | The `displayPrefixes` filter → `self?.maxTemp = status.displayedPeakTemp` | Headline matches the panel |

Deliberately **not** changed: `ThermalStatus.safetyPeakTemp`,
`FanControl.safetyTempKeys`, the daemon's safety sweep, `ThermalMonitor`, the
profile curves and the 95°C threshold. Fan control keeps following the hottest
key, including `TCDX`/`TCMb`/`Tp06`.

## Re-applying after an upstream merge

1. Resolve conflicts in the four places above by keeping upstream's code and
   re-applying the listed one-line changes.
2. If upstream edits `thermalKeys`, keep the M4 key line; drop any key upstream
   now lists itself.
3. If upstream changes how the CPU row or headline is computed, compare with
   `ThermalStatus+Display.swift` and keep whichever matches the Stats key map;
   `DisplayedTemperatureTests` encodes the measured M4 Max case.
4. Run `bash Scripts/test.sh --all-configurations`, then compare the CPU
   and GPU rows with Stats under CPU and GPU load
   (`Scripts/thermal-calibration/`).

## Kept as upstream on purpose

### Per-step fan logging

Smart mode ramps the fans about ten steps a second, and `FanControl` logs
every write (`Set fan N to N RPM`), as upstream does. On an M4 Max the daemon
log reached about 100,000 lines in five hours, filling a 5 MB file within
hours. macOS also recorded `disk writes` diagnostic reports for `macfanpro`
(about 2 GB of dirtied file pages in 6 to 17 hours). Actual disk writes are
only a few MB a day, so in October 2026 `main` kept upstream's behavior.

A ready change is on branch
[`proposal/fan-log-throttle`](https://github.com/macfanpro/macfanpro/tree/proposal/fan-log-throttle):
at most one line per fan every 5 seconds, counting the skipped ramp steps;
max and reset still log at once. Merge it if the step lines get in the way of
diagnosing problems, or if upstream changes its fan logging.

### Daemon logging, user data and thermal-suspension watchdog

Since ThermalForge #31, upstream's daemon logs only to the unified log, and root
processes write no log files. Upstream also moved sudo user data into a
`UserData` module, and its watchdog hands a dead app's hold back to Apple even
while the thermal floor holds the fans at max. MacFanPro keeps its own bounded
file logs, its calibration and recording ownership code (audited in
[code-audit-20261007.md](code-audit-20261007.md)), and its watchdog keeps the
fans at max until cooldown in that case. The startup reconcile and SIGTERM
release from #31 are adopted as upstream wrote them (0.2.3.54). See
[upstream-sync-20261007.md](upstream-sync-20261007.md).
