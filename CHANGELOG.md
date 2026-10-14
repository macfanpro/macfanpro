# MacFanPro changelog

## 0.2.3.63

- Merge the update window into Settings. The **Updates** section moves to the bottom (General, Background service, Updates) and, when a release is available, shows the new version, **What's new** and the update action, with **Other update methods** and **Download help** collapsed. The panel's update row opens Settings; the separate update window is removed.
- Settings taller than the screen scroll inside the window.
- The Homebrew update text says administrator authorization is required, not that it may be.

## 0.2.3.62

- The service status in Settings (running or needs attention) uses the same compact, centered icon as the panel's buttons.
- Buttons no longer end in "…": **Remove background service**, **View Update** and **Open download page**. Messages for actions in progress, such as "Checking…", keep it.

## 0.2.3.61

- Give the **Smart** and **Default** buttons the same icon treatment as **Quit** and **Settings**: the symbol is one size smaller, matches the text height, sits centered on the text with 4 points of spacing. All four panel buttons now match.

## 0.2.3.60

- Align the icons in the **Quit** and **Settings** buttons: each symbol is one size smaller, matches the text height, sits centered on the text, and keeps 4 points of spacing. The tall exit symbol no longer looks larger than its label.
- The settings window now opens centered on the screen. It was centered before it grew to fit its content, so it appeared off to one side.

## 0.2.3.59

- Polish the panel's footer. **Quit** is now a button like **Settings**, with an exit icon and ⌘Q. The Settings button drops its trailing ellipsis, since its gear icon already marks it. The row has more space above it.

## 0.2.3.58

- Add a settings window and slim the menu bar panel. **Settings…** at the bottom of the panel (⌘,) opens a native window with three groups: General (language, temperature unit and Launch at Login), Updates (version and update checks), and Background service (status, setup and removal). The panel keeps the readings and profiles. When a release is available, it shows one "{version} available" row that opens the update details, and a dot on **Settings…**. First-run and service synchronization use the same window.

## 0.2.3.57

- The menu's background-service entry is now a row below Updates, with a **Manage…** button that matches **Check for Updates**, instead of a small link next to Quit. In Chinese its label is the two-character 服务 / 服務, like the rows above it.
- The setup window no longer has its own language picker. It follows the language chosen in the menu.

## 0.2.3.56

- Make the background service's diagnostics readable. Since the macOS 26 SDK, everything it wrote with `NSLog` appeared in the system log as `<private>`, which hid startup, fan release, thermal floor and wake messages. It now uses ThermalForge's `DaemonLog` channel, with public messages under the subsystem `io.github.macfanpro.daemon`. To read them, run `log show --last 1h --predicate 'subsystem == "io.github.macfanpro.daemon"'`. The bounded runtime log files are unchanged.

## 0.2.3.55

Version 0.2.3.54 was a candidate with the same changes; it was never published.

- Adopt ThermalForge's fan release on daemon start and stop. A starting background service returns fans left under manual control (by a crashed or killed service, or a direct write) to Apple's automatic control. The service releases the fans it controls when it is stopped (SIGTERM). Installation releases fans before restarting the service, also when upgrading from a version without this. MacFanPro keeps its own behavior when the app stops responding while the thermal floor holds the fans at maximum: the fans stay at maximum until the Mac cools down.
- Add contributor and AI-agent rules (`AGENTS.md`): one branch and pull request per change, one release at a time, and how upstream merges are recorded.

## 0.2.3.53

- Fix issues found in the 2026-10-07 review of MacFanPro and upstream ThermalForge. A failed Launch at Login change no longer retries itself in a loop. `watch` and calibration go through the installed service's ownership and protection. M4 efficiency-core sensors count toward thermal protection. Calibration stops cleanly on Ctrl-C or SIGTERM and never saves a cancelled result. Recording durations are validated, and recordings started with sudo belong to the invoking user. Calibration file access drops root's supplementary groups.

## 0.2.3.52

- Move release notices to a compact Updates row and a separate native window. Keep fan readings visible, provide installation-channel-specific actions, and show failed handoffs with retry in all 18 languages.
- Merge upstream installation improvements: verify matching app and CLI builds, prepare complete app bundles before atomic replacement, and wait for actual launchd state with actionable failures.
- Restore previous service files when installation fails after stopping the service. Stop uninstall when service shutdown or fan reset fails, and distinguish launchd query failures from an absent service.
- Fix a C buffer lifetime error in app staging exposed by optimized CI builds; verify the staging directory's parent, name, owner and permissions before it can be used or cleaned. Candidate 0.2.3.51 failed CI and was never published.
- Keep existing fan curves, safety thresholds, disconnect protection, logging, proxy support and installation channels. DMG updates replace the app without removing its background service first.

## 0.2.3.50

- Add a DMG with a self-contained app: drag it into Applications, open it, and authorize background service setup through a macOS dialog. The setup window supports all 18 app languages, service synchronization, retry after cancellation, and service removal while retaining settings and logs. Existing Homebrew, online script and source installation remain available.
- Validate the service owner, app identity, signature and installation paths before graphical setup. Serialize service changes and restore previous service files if graphical installation fails. Preserve Homebrew management and explicit CLI fan holds.
- Merge upstream connection identity checks and accept/log limits, plus app attribute cleanup that does not follow symlinks outside the bundle. Retain MacFanPro's disconnect protection and hardware-operation timeout handling. Thermal curves and the 95/90°C safety thresholds are unchanged.
- Launch the 18-language project website at https://macfanpro.github.io/macfanpro/ and reorganize the English and Chinese README for installation, everyday use and technical reference. The website shows a DMG download when the latest release includes the asset.
- Continue ad-hoc signing without Apple notarization. This release's verification record distinguishes automated/package checks from real administrator installation and hardware testing.

## 0.2.3.37

- Installation and updates can use a local HTTP or SOCKS5 proxy. The online installer detects macOS system proxy settings, while the README gives a command that also proxies the initial script download. The in-app update flow explains how to handle GitHub connectivity problems; Homebrew refreshes only the MacFanPro tap where possible.
- Remove the soft glow from the fan logo and its extra halo in the repository previews. The app icon keeps its cyan-to-violet gradient and smooth outline. Fan control and protection thresholds are unchanged.

## 0.2.3.36

- New app icon in a tech palette: the fan now has a cyan to violet gradient and a soft glow, on a deep navy tile with a thin cyan edge. It shows in the Dock, Finder and Launchpad. The social preview images use the same style. Menu bar and panel colors are unchanged.

## 0.2.3.35

- The update banner now shows two labelled options. **Option 1 (recommended)** is the one-click **Update in Terminal** for how you installed, Homebrew or the release package, with its command. **Option 2** is building from source, for developers. Commands stay left to right in Arabic.
- The "Built from source?" line in the update banner now shows a complete command you can copy and run. An app built with `setup.sh` remembers its source folder and shows `cd <folder> && git pull --ff-only && ./setup.sh`. Apps from a release package or Homebrew show a command that clones the source into `~/macfanpro` if needed, then pulls and runs `setup.sh`.

## 0.2.3.34

- Homebrew updates from **Update in Terminal** or the online installer no longer stop at Homebrew 7's y/n confirmation, which was easy to miss among the update output. Running the update is the confirmation.
- They refresh only the MacFanPro tap instead of running `brew update`, which fetched every tap. That was slower, printed errors from unrelated taps or mirrors, and was skipped by people who set `HOMEBREW_NO_AUTO_UPDATE`. If the tap can't be refreshed, `brew update` is still used.
- `macfanpro auto --stop-app` no longer shows the "Version mismatch" warning. It runs right before `sudo macfanpro install` during an update, where that mismatch is expected. Other commands still warn.

## 0.2.3.33

- Add a one-command online installer: `curl -fsSL https://github.com/macfanpro/macfanpro/releases/latest/download/install.sh | bash`. It downloads the release package, verifies its checksum, archive contents, app identity, version and code signature, then asks for your password once to install. Homebrew installs stay with Homebrew. Downgrades are refused, and configuration and calibration are kept. Each release now also attaches `install.sh` and `install.sh.sha256`.
- **Update in Terminal** now runs the same installer, bundled inside the app, so updates get the same checks. It confirms the new background service is running before reopening the app.
- `sudo macfanpro install` now asks the running background service for its version and fails if it is not the one just installed, instead of reporting success for a stale service.
- The "Built from source?" hint in the update banner shows `git pull && ./setup.sh` as a separate, selectable command.

## 0.2.3.32

- Add an **Update in Terminal** button to the "Update available" banner. It opens Terminal with the update steps for how MacFanPro was installed, so updating takes one click and your password. For a release-package install it downloads the new version, verifies its checksum and installs it; for Homebrew it trusts the tap, upgrades and syncs the background service. It uses the system proxy when no proxy is set in the shell, since Terminal tools don't follow the macOS proxy settings.
- Homebrew releases are now published automatically: after a release is published, the tap updates its formula and prebuilt bottle, and checks that it installs, without manual steps.

## 0.2.3.31

- The "Update available" banner now shows the steps for how MacFanPro was installed. Release-package installs are told to download the new version and run `sudo ./bin/macfanpro install` in its folder, with a Download link; they were previously shown a Homebrew command that fails without a Homebrew install. Homebrew installs get `brew trust macfanpro/tap && brew upgrade macfanpro && sudo macfanpro install`, which now includes the `brew trust` step Homebrew 7 requires.

## 0.2.3.30

- Add Arabic, the 18th interface language. The panel is mirrored for right-to-left text: labels on the right, values and buttons on the left, while commands, RPM and temperatures stay left to right.

## 0.2.3.29

- Add 14 interface languages: Japanese, Korean, German, French, Spanish, Italian, Brazilian Portuguese, Russian, Ukrainian, Polish, Dutch, Turkish, Vietnamese and Indonesian, for 17 in total. Follow System picks the first supported language in your system order; the Language menu lists each language under its own name. Every language was checked in all panel states.
- The README is now in English, with the Chinese version in `README.zh-CN.md`. Release notes are bilingual from this release.

## 0.2.3.28

- Clear the update-check result when the menu closes, so the next time it opens the row reads "Updates" again instead of an old "Up to date". A found update's banner stays. A check still running keeps its state and shows its result when it finishes.

## 0.2.3.27

- Name the update button "Check for Updates" / "检查更新" / "檢查更新" in all languages instead of "Check" / "检查". A result too long to fit beside it on one line (in English, "Couldn't reach GitHub" or "0.2.3.28 available") wraps and the row grows, so no text is cut short; the button keeps its full width.

## 0.2.3.26

- Lay out the update row like the Language row, in the same font and control size: an "Updates" label that shows the check's result once there is one, and a Check button. The 0.2.3.25 row used small text and a small button.

## 0.2.3.25

- Add a Check for Updates button under the Version row. It checks GitHub now instead of waiting for the daily check, and shows "Checking…", "Up to date", the new version, or "Couldn't reach GitHub". A found version shows its banner even if "Later" dismissed it; the daily check still honours the dismissal. The check uses the system proxy settings.
- Check for updates through the public releases page (`/releases/latest` redirects to the newest tag) instead of the GitHub REST API. The unauthenticated API allows 60 requests an hour per IP; proxy exit IPs shared by many users often have none left, so every check failed. This also affects the daily automatic check.

## 0.2.3.24

- While the thermal floor holds the fans at max, a fan command that fails (for example on a transient SMC read, before anything is written) no longer ends the override and hands hot fans back to auto. The background service re-asserts max and keeps the override until cooldown, falling back to auto only if max cannot be written. An explicit auto still hands control back.

## 0.2.3.23

- Recover failed fan writes even when a previous CLI or app hold exists. A partly applied low-speed command can no longer leave an old max label suppressing recovery. Failed releases remain pending until they succeed, and new writes cannot discard that recovery.
- Decide watchdog expiry and thermal suspension under the same hardware lock. A watchdog waiting behind thermal max no longer resets the fans using an obsolete suspension snapshot.
- Automatic app releases now ask the daemon to preserve CLI ownership at execution time. Background retries, launch recovery and shutdown cannot clear a newer CLI hold; explicit Default and CLI auto remain unconditional.
- Share acknowledgement and retry handling between the app and CLI watch. Failed writes do not report success, stale profile completions are ignored, and a failed safety max is retried through the hysteresis band.
- Accumulate small ramp steps at short watch intervals. Balanced and Smart now ramp in both directions at 0.01, 0.1 and 1 second intervals while keeping their sustained-start timing.
- Return and display each fan's accepted target after clamping. All-fan requests use each fan's own limits on both daemon and direct paths.
- Add 20 regression tests, including simulated hardware failures, controlled watchdog interleavings and asynchronous command acknowledgements. Smart's curve and the 95/90°C protection thresholds are unchanged.

## 0.2.3.22

- A max or set that fails part-way through taking manual control no longer leaves fans manual (or Apple's thermal control suppressed) with nothing recorded. The background service resets them to auto, and keeps retrying every 5 seconds if the SMC is not ready, for example during dark wake.
- The thermal floor marks its override in the same step as it raises the fans, so a command arriving in between can no longer lower them while it believes they are at max. The watchdog no longer clears a hold while the floor is restoring it.
- The 95°C safety override now holds until the temperature is below 90°C, as intended. Previously Silent handed the fans back at 94°C.
- Choosing Silent or pressing Default no longer drops Silent's own first safety max. 0.2.3.21 waited for a later status report before letting writes through.
- If handing the fans back to macOS fails when Smart or a curve cools down, the app retries until it succeeds, instead of leaving them manual.
- `sudo macfanpro calibrate` quits the menu bar app while it runs and reopens it afterwards, so the app can't override the fan levels being measured. A result that fails validation is not saved, so a failed run keeps the previous calibration, and the file is written atomically.
- Setting all fans to one speed keeps each fan inside its own range.
- `sudo macfanpro install` run from the installed copy after `brew upgrade` now finds the newer Homebrew app bundle and re-syncs from it, instead of stopping with "No matching MacFanPro.app".
- `macfanpro watch --interval` now scales ramp rates and trigger times to the chosen interval, and rejects intervals that are not positive.

## 0.2.3.21

- Security: `sudo macfanpro calibrate` now reads and writes your calibration files with your own permissions. In 0.2.3.20 it wrote them as root and then changed their owner, so a link planted in `~/Library/Application Support/MacFanPro/` by another program running as you could make root overwrite a system file and give it to you.
- When the thermal floor ends, it re-checks the fan setting under the same lock it restores with, so it no longer restores a speed that `auto` had just cancelled.
- The heartbeat watchdog clears an expired hold in the same step as it re-checks it, so a heartbeat arriving during the reset can no longer leave a manual hold on record over fans that are back on auto.
- A slow Default no longer switches you back to Silent after you picked another profile, and no write from the previous profile, including its max, can land after the reset.

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
