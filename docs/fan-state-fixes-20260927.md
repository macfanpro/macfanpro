# Fan-state and calibration fixes (audit of 2026-09-27)

An external code audit reported six defects. Each was checked against the code and against upstream ThermalForge `main` (compared with names normalized). All six are real, and all six are in upstream code that MacFanPro inherited unchanged. None crashes the app. They can leave fans in a state that differs from what the menu and the daemon report. The first two can leave fans pinned at a manual speed.

Two MacFanPro changes make a race window wider:
- **#2:** the M4 fan handoff can make a reset take seconds.
- **#5:** heartbeats no longer wait for `smcLock` (`DaemonRequestPolicy`). That change fixed spurious watchdog resets during slow handoffs, so it stays.

Status: shipped in 0.2.3.20. A follow-up review found four gaps, fixed in 0.2.3.21 (see the last section).

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

## Follow-up review (0.2.3.21)

A second review of 0.2.3.20 found four gaps. All four were confirmed.

| # | Gap | Fix |
|---|---|---|
| 1 | **Security, introduced by fix #4.** `calibrate` wrote into the user's home as root. `Data.write(to:)` follows links, and the `setAttributes` ownership change follows them too. A link planted at `calibration.json` therefore made root overwrite the target and hand it to the user: a privilege escalation path, provided another program running as the user plants the link and the user then runs `sudo macfanpro calibrate`. | `CalibrationData.asInvokingUser` switches the effective uid and gid to the sudo user around every file access in their home: save, CSV creation and load. The kernel then applies the user's own permissions, new files belong to the user, and the ownership change is gone. The real ids stay root, so switching back always works. The switch is process-wide, so it runs only while calibration's stress threads are stopped. |
| 2 | The floor's restore read the hold before taking `smcLock`. An `auto` completing in between left the restore replaying the cancelled command and clearing the suspension, with no hold on record. | The hold and the suspension are read, applied and updated all under `smcLock`. If `auto` already ended the suspension, nothing is restored. |
| 3 | The watchdog released `stateLock` after its re-check. A heartbeat (which needs no `smcLock`) could renew the hold during the reset, which left a manual hold on record over fans that were back on auto. | The expired hold is cleared in the same critical section as the re-check, before the reset. If the reset fails, the hold is put back so the next tick retries. |
| 4 | Default's success callback applied Silent even after the user had picked another profile. The 0.2.3.20 filter also still let the old profile's `setMax` land after the reset. | New `ProfileSwitchGate` (`Sources/MacFanProApp/ProfileSwitchGate.swift`). Each Default press gets a token, and only the latest press's result applies; a pick in between wins. While a switch is pending, only `resetAuto` passes. The gate reopens when the monitor reports the hands-off profile, after which Silent's own safety max passes. It replaces the 0.2.3.20 `dropRampWrites` flag. While the gate is shut, a dropped max leaves the fans on macOS's own control. |

Tests:
- 123 tests pass in Debug and Release, with no warnings.
- `AuditFixTests` now covers the gate's orderings: stale writes during Default, a newer pick winning, repeated presses, a failed reset, and picking Silent.
- The daemon changes still have no unit harness (see above).

Hardware checks (M4 Max, candidate installed with `./setup.sh`):
- **Link attack, run under sudo.** A standalone program that copies `asInvokingUser` planted a link from a user-owned directory to a root-owned file.
  - The 0.2.3.20 approach (root write, then ownership change) overwrote the file and gave it uid 501.
  - The new approach was refused with a permission error. The root file was unchanged, a normal save was owned by the user, and euid was back to 0 afterwards.
- **Default then Smart.** Under load, Default and then Smart were pressed within a second. Smart stayed selected and kept control. The reset had already finished before the Smart press, so the late-result ordering itself is covered only by the unit tests.
- **Calibration** (`--mode quick --stress gpu`, with the app quit via `macfanpro auto --stop-app`):
  - It read the existing file for the downgrade check.
  - It wrote the CSV and `calibration.json` as the user, with 6 valid measurements.
  - After reopening, the app ran Smart with it.

Found while testing, not caused by these fixes:
- **Calibration and the app fight over the fans.** The first rerun had the app running Smart. The app kept rewriting fan targets, so calibration's "100 %" level ran at about 3600 RPM and hit the 84 °C ceiling at once. The result was a calibration with no measurements, which overwrote the previous one. The app rejects such a file ("No measurements") and falls back to the default curve, so it is safe, but the run is wasted. `calibrate` should stop the app first, as `auto --stop-app` does. It should also refuse to save a result that fails validation. Both are upstream behaviour and are left for a separate change.
- **The thermal floor worked under combined load.** During one Default check, a local-model server was running alongside the test load. Peaks reached 96–100 °C, and the safety override held the fans at max until the load stopped.

## Third review (0.2.3.22)

A third review of 0.2.3.21 reported ten findings, F1–F10. All ten were confirmed against the code.

| # | Finding | Origin | Fix |
|---|---|---|---|
| F1 | While the floor held max, the watchdog cleared an expired hold using only `stateLock`. That could happen between the floor's restore reading the hold and applying it, leaving the old speed pinned with no hold. | upstream | The watchdog's suspended branch takes `smcLock`, then re-checks the suspension and the heartbeat. |
| F2 | The floor's engage path released `smcLock` after `setMax` and only then set `safetySuspended`. A `set` in between saw no suspension and lowered the fans, and later commands then skipped their writes. | upstream | The suspension is set inside the same `smcLock` section as the write. |
| F3 | Taking manual control can fail part-way, after Ftst or a fan mode was already written, and the daemon recorded no hold. This was observed during dark wake on 2026-09-27. | upstream | If a max/set/setfan fails with no hold to keep, the daemon resets to auto. If that fails too, `releasePending` makes the watchdog loop retry every 5 s. |
| F4 | 0.2.3.21's gate reopened on the monitor's next status report. Silent's first safety `setMax` arrives before that report, so it was dropped. | this fork (0.2.3.21) | `ThermalMonitor.switchProfile(_:applied:)` calls back from the monitor's queue once the switch took effect, and the gate reopens on that token. Writes queued before the switch arrive first and are dropped; the new profile's writes pass. |
| F5 | The monitor treats a sent `resetAuto` as done, and the pump never reported failures back. A failed cooldown reset left the fans manual under a hold the heartbeat kept alive. | upstream | AppState retries a failed monitor reset with backoff (2–30 s) until it lands or a newer write exists. |
| F6 | Between 90 and 95 °C, the safety override fell through to the profile logic, so Silent reset to auto at 94 °C. | upstream | The override is kept until the temperature is below 90 °C. |
| F7 | `setAllFans` and the daemon clamp checked only fan 0's range. | upstream | Each fan's target is clamped to that fan's own range. |
| F8 | An invalid (empty) calibration overwrote a valid one, and the app could fight calibration over the fans. | upstream | Merged from the separate calibrate session: `calibrate` quits the app for the run and reopens it, and `save` refuses results that fail validation. The save is also atomic. |
| F9 | The install precheck required an app bundle matching the running CLI. Run from the stale `/usr/local/bin` copy after `brew upgrade` (sudo's `secure_path`), it failed before reaching the keg re-sync. | this fork | The keg to re-sync from is resolved first. The precheck and the bundle copy use the version being installed. |
| F10 | `watch --interval` changed the timer, but the control maths stayed at 0.1 s per tick. | upstream | `start(interval:)` sets the tick interval, and `watch` rejects non-positive intervals. |

Tests:
- 125 tests pass in Debug and Release, with no warnings.
- `AuditFixTests` covers the token-based switch confirmation and invalid calibration saves.
- `FanRangeTests` drives `FanControl` against a simulated SMC. The daemon and an end-to-end `ThermalMonitor` loop still have no harness; the monitor would write to the user's real log.

## Fourth review: recovery and acknowledgement (working tree, 2026-09-27)

Status: fixes based on `705f48e` / 0.2.3.22 were committed as `f3849d4` and shipped in 0.2.3.23. This section records the source repair and simulated regression checks; see the separate [0.2.3.23 release and installation acceptance record](macfanpro-0.2.3.23-validation.md) for CI, downloaded artifacts and the installed runtime.

The `macfanpro-main` Claude Code session was read from local session
`220788e8-f2c0-4892-b6bb-1450d9474d0b`. Its last delivery described 0.2.3.22 and acknowledged that daemon failure interleavings had not been forced. The subsequent review found six remaining defects (R1–R6). The user then asked Codex to implement and verify their repair.

| Review | Repair | Regression evidence |
|---|---|---|
| R1: a failed multi-fan write retained an old `max` hold | Any failed hardware command invalidates the old hold and attempts automatic release. A failed release remains pending and is retried by the watchdog. New manual commands must finish pending recovery first, including single-fan commands. A failed wake replay uses the same recovery path. | Simulated second-fan failure after both CLI and app max holds, with successful and failed rollback; a later single-fan command cannot abandon another fan's recovery. |
| R2: watchdog selected its suspension branch before locking | One `watchdogTick` takes the SMC lock, then checks expiry and suspension together. It clears an expired app hold but preserves thermal max until cooldown. | Pause a real floor write, start the watchdog behind it, then release the write: fans stay manual at max, the hold clears, and cooldown returns them to auto. A heartbeat during reset cannot recreate a hold. |
| R3: delayed app reset erased a newer CLI hold | Add the distinct `auto-if-app` request (`releaseAppHold` in the client). The daemon rejects it over CLI ownership in the same SMC critical section as the write. Monitor resets, launch recovery and app shutdown use it; explicit Default/CLI auto still clears any hold. Remove AppState's delayed reset tasks. | A real monitor plus `FanCommandPump` retries a failed reset after a newer CLI max arrives, without any UI state poll: CLI max survives. Explicit auto still releases it. |
| R4: short intervals never accumulated a ramp step | Track the accumulated ramp separately from the last acknowledged target. Sustained triggers count elapsed seconds rather than a truncated number of ticks. | Balanced and Smart ramp up and down at 0.01, 0.1 and 1 second intervals. |
| R5: watch treated failed reset as successful | Shared `ThermalMonitor` handles synchronous CLI execution and asynchronous GUI acknowledgement. It commits successful commands only, retains recovery on failure and retries while still needed, with 2–30 second backoff. A profile generation rejects old completions; only one monitor command is outstanding. | Failed resets in Balanced, Smart and Silent retry; async resets do not complete early; profile changes reject stale acknowledgement; a failed first direct hold still releases partially acquired fans on cooldown. |
| R6: CLI repeated fan 0's RPM for all fans | Return each clamped target from `FanControl`, carry it through the daemon/router and print it per fan. Resolve all-fan requests against each fan's own range, including the direct path. The legacy scalar is present only for a common target. | Both fan orderings (maxima 6000/4000 and 4000/6000) produce matching SMC writes and response arrays, including after thermal restore; protocol round-trip and old-response decoding pass. |

Related conditions covered while repairing these paths:

- The thermal floor rechecks its hold after temperature sampling, so a concurrent auto cannot be followed by an orphan max write.
- A partly failed cooldown restore re-establishes max before retaining the suspension. If max cannot be restored either, tracked automatic release takes over.
- Safety demand remains latched through 90–95°C even when the initial max failed. A failed reset invalidates confidence in the previous command, so a later hot tick reissues max.
- The existing Smart curve, 95°C trigger and below-90°C clearance thresholds are unchanged.

### Reproducible validation

`Tests/MacFanProTests/ControlLoopRecoveryTests.swift` drives the production dispatcher, watchdog, thermal floor, command pump and monitor. The daemon has an internal constructor without a bound socket and an injected clock; the monitor has injected clock, calibration, logger and process capture. `FanControl` uses a dictionary-backed `SMCConnection` and disables file logging for that injected path. No sudo, installed daemon connection, stress load or physical fan write is needed.

Final validation on 2026-09-27:

| Command | Result |
|---|---|
| `bash Scripts/test.sh` | 145 tests in 23 suites passed; 108 abandoned-reply checks plus a subsequent request passed. |
| `bash Scripts/test.sh -c release` | 145 tests in 23 suites passed; the disconnect process fixture passed again. |
| `swift build -c release` | CLI and menu bar app built successfully. |
| `bash Scripts/check-localization-package.sh "$(swift build -c release --show-bin-path)"` | Bundle identity, license, all three locale resources and rejection of missing resources passed. |
| `git diff --check` | Passed. |

Compiler logs for the final Debug/Release runs contain zero warnings or errors. Compared with the 125-test baseline, this adds 20 tests (including parameterized fault/interval cases). Logs from this run are `/tmp/macfanpro-fix-debug-tests.log`, `/tmp/macfanpro-fix-release-tests.log`, `/tmp/macfanpro-fix-release-build.log` and `/tmp/macfanpro-fix-package.log`.

### Compatibility and remaining acceptance scope

- The new conditional release uses a distinct verb. Old daemons reject it instead of silently interpreting it as unconditional auto. Install the matching app and daemon together when shipping this change.
- Older daemon responses remain decodable. The new CLI reports unknown all-fan targets if a daemon supplies only the old scalar, rather than claiming that scalar was applied to every fan.
- The all-fan direct path now clamps each fan independently, matching the daemon; per-fan direct requests still validate their requested RPM.
- The table above contains source/build/simulated-failure checks. Release 0.2.3.23 was subsequently published and installed through Homebrew, with separate acceptance evidence linked above. It has not been validated through a real sleep/wake or thermal stress cycle in this review. Earlier hardware and release evidence in this document applies to its named historical versions.
