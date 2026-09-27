# MacFanPro changelog

## 0.2.3.20

- Default now reliably returns the fans to macOS control when pressed while a profile is ramping. Previously a ramp write from the old profile could land after the reset, which left the fans manual while the menu showed Silent.
- After wake, the background service no longer replays a fan setting that was released or replaced during its 2-second delay, or while the thermal floor holds the fans at max.
- The heartbeat watchdog re-checks that the app has really stopped checking in before it resets the fans. The thermal floor keeps retrying until a restore write succeeds, instead of reporting the override as over while the fans stay at max.
- `sudo macfanpro calibrate` now saves to your own `~/Library/Application Support/MacFanPro/` instead of root's, so the Smart profile actually uses the calibration. It also watches GPU temperatures as well as CPU, which is the same reading Smart looks up. Earlier calibrations were saved where the app could not read them; run calibration again to use it.

## 0.2.3.19

- Size the language pop-up to its choices instead of stretching it across the row. It takes the native pop-up width (its longest choice), stays the same width when the selection changes, and lines up with the version value below.

## 0.2.3.18

- Group the language picker and a new Version row in their own section, between two dividers, directly above Quit. The version shown is the one the app was built as. The °F/°C and Launch at Login toggles stay where upstream has them.

## 0.2.3.17

- Write runtime log lines without rescanning the log directory. Each line previously listed the directory twice and cost 0.7–1.1 ms in the background, growing with the number of log files; it now costs about 57 µs regardless of file count. The background service writes up to ~22 lines per second while fans ramp. Size and retention limits are unchanged.
- `sudo macfanpro uninstall --purge-data` also removes the background service's logs in `/var/root/Library/Logs/MacFanPro/`, which were previously left behind. Plain `uninstall` still keeps logs.
- README: how to read the background service log, when runtime logs are pruned, and why unmarked captures from earlier versions are kept.

## 0.2.3.16

- Show the hottest CPU core in the CPU row. On M4 the row also picked up SoC hotspot keys (`TCDX`, `TCMb`) and per-core keys that are not the core temperature (`Tp02`, `Tp06`, `Tp0A`), so under GPU load it read 73–75°C while every CPU core read 60–63°C. It now uses the per-core keys Stats maps for the M4 generation; under GPU load MacFanPro and Stats now agree within 0.5°C. Other chips keep the previous grouping.
- The menu bar reading is now the hotter of the CPU and GPU rows, so it always matches the panel.
- Stop reporting the battery gas-gauge sensors as GPU temperatures. On M4 Max the SMC keys `TG0B`, `TG0H` and `TG0V` are battery sensors; MacFanPro asks the system's thermal sensor services which keys are batteries and leaves them out.
- Drop placeholder readings (below 10°C) from CPU/GPU die keys in `macfanpro status` and recorded logs.
- Fan control and the 95°C safety floor are unchanged: they still follow the hottest point on the chip, including the hotspot keys.

## 0.2.3.15

- Simplify installation by removing the retired product's migration flag and product-selection layer.
- Remove the old Homebrew package-name mapping; maintain MacFanPro's current version ordering.
- Present MacFanPro installation, usage and updates consistently across documentation and release notes.
- Keep upstream attribution and copyright notices.

## 0.2.3.14

- Provide the MacFanPro menu bar app, `macfanpro` CLI and background service for Apple Silicon Macs.
- Publish releases through `macfanpro/macfanpro` and Homebrew packages through `macfanpro/tap`.
- Include English, Simplified Chinese and Traditional Chinese interfaces, with immediate language switching.
- Keep the native menu, automatic panel height, centered minimum-width temperature label and localized Quit footer.
- Document installation, updates and removal, with a screenshot of the installed app in the README.
