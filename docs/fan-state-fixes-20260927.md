# Fan-state and calibration fixes (audit of 2026-09-27)

An external code audit reported six defects. Each was checked against the code and against upstream ThermalForge `main` (compared with names normalized). All six are real, and all six are in upstream code that MacFanPro inherited unchanged. None crashes the app. They can leave fans in a state that differs from what the menu and the daemon report. The first two can leave fans pinned at a manual speed.

Two MacFanPro changes make a race window wider:
- **#2:** the M4 fan handoff can make a reset take seconds.
- **#5:** heartbeats no longer wait for `smcLock` (`DaemonRequestPolicy`). That change fixed spurious watchdog resets during slow handoffs, so it stays.

Status: fixed and validated on an M4 Max on 2026-09-27 (results below). Shipped in 0.2.3.20.

## Findings and fixes

| # | Where | Defect | Fix |
|---|---|---|---|
| 1 | `Daemon.swift`, `handleWake` | The re-apply 2 s after wake replays the command captured at wake. If an `auto`, a watchdog reset or a new command lands in those 2 s, the stale manual speed is written while the daemon records no hold, so neither the watchdog nor the thermal floor ever corrects it. After a sleep longer than 15 s the watchdog itself often clears the hold inside that window. | Under `smcLock`, re-read the hold. Skip the replay if the command changed or the thermal floor is holding max. |
| 2 | `AppState.swift`, `resetAuto` / `onFanCommand` | Pressing Default while fans ramp: the previous profile's `setRPM` writes can queue behind the reset. The success path then switches the monitor to Silent, which clears `fansCurrentlyRunning`, so Silent never resets again. The menu shows Silent while fans stay manual, and the watchdog does not step in because heartbeats continue. | New `dropRampWrites` flag. It is set when Default is pressed or a hands-off profile (Silent) is picked, and cleared when the user picks a ramping profile, picks Smart, or the reset fails. While it is set, `setRPM` and `setFan` are dropped. `setMax` (safety override) and `resetAuto` always pass. |
| 3 | `Calibration.swift`, `peakCPUTemp` | Calibration read only `TC`/`Tp`. `--stress gpu` lowers the fans under GPU load while its 90 °C abort cannot see the GPU. Smart looks up calibration data with the CPU+GPU peak (`safetyPeakTemp`), so CPU-only measurements never matched what Smart compares them against. | Renamed to `peakSafetyTemp`, which returns `status.safetyPeakTemp`. |
| 4 | `Calibration.swift`, `CalibrationData.filePath` | `calibrate` requires sudo, but the file was written to the current user's home, which under sudo is `/var/root`. The app reads the invoking user's home, so **Smart never used any calibration**. The downgrade check read root's file as well. | Under sudo, resolve the invoking user from `SUDO_UID`, the same way `uninstall --purge-data` does. After writing, hand the JSON, the CSV log and the directory back to that user. Without sudo the behavior is unchanged. |
| 5 | `Daemon.swift`, heartbeat watchdog | The expiry is judged before waiting for `smcLock`. A heartbeat can renew the hold during that wait, and the watchdog still resets fans to auto while the hold stays recorded. The result is safe (macOS controls the fans) but reported wrongly until the app's next command. | Re-check the same supervised hold and heartbeat once `smcLock` is held. |
| 6 | `Daemon.swift`, `thermalTick` `.restore` | A failed restore write was ignored, yet `safetySuspended` was cleared. Fans stayed at max with the override reported as over, and no retry followed. | Clear the flag only after the write succeeds, as the engage path already does. Staying suspended retries every second. |

Upstream lines changed: the six locations above only; no structure moved. When merging upstream, keep upstream's code and re-apply each guard.

Existing calibration files: none were usable (they sat in `/var/root`). Old ones there can be removed with `sudo rm "/var/root/Library/Application Support/MacFanPro/calibration"*`, after looking at them first.

## Tests

`Tests/MacFanProTests/AuditFixTests.swift` covers:
- which commands count as ramp writes;
- resolving the sudo user's home;
- the non-sudo fallbacks: no sudo, and a root or malformed `SUDO_UID`.

The daemon fixes (1, 5, 6) have no unit tests. `DaemonServer` binds the root socket and drives the real SMC, and the repository has no test double for it. Those three are verified by review and on hardware.

## Validation (M4 Max, 2026-09-27)

Tests:
- `bash Scripts/test.sh` and `bash Scripts/test.sh -c release` both passed: 119 tests, including the 3 new ones, with no compiler warnings.

Install:
- Installed with `./setup.sh`. The CLI and app hashes match the new build, and the daemon restarted on it.

Checks. Fan mode, RPM and the CPU/GPU peak were logged every second from `macfanpro status`. The Default and Smart presses were real accessibility presses on the panel buttons.

- **#2 Default while ramping: passed.** 16 busy loops kept Smart ramping (manual, ~2800–3100 RPM, peak 65–76 °C). Default was pressed at 13:05:30.
  - One more manual write followed at 13:05:31. It had been queued before the press.
  - The handoff went through `auto` and reached `system` at 13:05:34.
  - Fans stayed `system` for the remaining ~70 s of load, with peaks up to 77.8 °C. The app logged "Reset to Default" and the saved profile became `silent`.
- **#3/#4 calibration: passed.** `sudo macfanpro calibrate --mode quick --stress gpu`:
  - It wrote `calibration.json` and its CSV to `~/Library/Application Support/MacFanPro/`, owned by the user.
  - CSV temperatures equal the CPU/GPU peak at the same moment (74.5 °C).
  - At the 60 % level the peak reached the 84 °C ceiling, the lower levels were skipped as designed, and fans returned to macOS control.
  - After switching to Smart, the app logged no "Calibration data rejected".
  - On this M4 Max the CPU hotspot keys stayed hotter than the GPU keys even under GPU-only load (72.5 °C against 65.4 °C). The old CPU-only reading would therefore have missed little here; the fix matters on machines whose GPU runs hotter.
- **#1 wake: no stale replay observed.** Smart held the fans manually (~1800–2200 RPM) under load, then `pmset sleepnow` was run.
  - The system sat in dark wake until 13:21:21, slept 31 s, dark-woke at 13:21:52 and fully woke at 13:22:18.
  - From 13:21:52 the fans were `system`. They did not return to the pre-sleep manual speed (~1770 RPM) during the replay window.
  - At full wake the app took control again and the fans followed the live Smart curve (3448 RPM falling as the load ended), then returned to auto.
  - The daemon's "re-applied" or "skipped" line is an `NSLog` whose text the unified log keeps private, so which branch ran was not directly visible. The specific race (an `auto` inside the 2 s window) was not forced.
- **#5/#6:** not forceable. No unexpected watchdog reset appeared while the app ran.

Observed in passing, not caused by these fixes: during dark wake the app's first ramp write failed with "Fan unlock failed: Timed out setting fan 0 to manual mode. Run with sudo." The M4 manual-mode handoff times out while the system is in dark wake. The app retried on its own after full wake. The "Run with sudo" hint in that message is misleading. This is the first occurrence in the logs from 09-22 to 09-27.
