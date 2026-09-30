# MacFanPro

[![CI](https://github.com/macfanpro/macfanpro/actions/workflows/ci.yml/badge.svg)](https://github.com/macfanpro/macfanpro/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/macfanpro/macfanpro?sort=date)](https://github.com/macfanpro/macfanpro/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**English** | [简体中文](README.zh-CN.md)

**Fan control for Apple Silicon Macs — free, open source, native.**

See CPU and GPU temperatures and fan speeds in the menu bar, let the fans follow the temperature with smart curves, or take full control from the command line. Works on M1 to M5 Macs with fans, on macOS 14 or later.

<img src="docs/images/menu-bar-en.png" alt="MacFanPro menu in English: fan speeds, temperatures, profiles, language setting, version and the update check, and Quit" width="320"> <img src="docs/images/menu-bar-zh-CN.png" alt="MacFanPro 菜单（简体中文）：风扇转速、温度、控制模式、语言设置、版本与检查更新、退出按钮" width="320">

### Quick install

```bash
brew tap macfanpro/tap && brew trust macfanpro/tap
brew install macfanpro
sudo "$(brew --prefix macfanpro)/bin/macfanpro" install
open /Applications/MacFanPro.app
```

Or [download the app](https://github.com/macfanpro/macfanpro/releases/latest) — see [Install](#install) for all options.

[Install](#install) · [Usage](#usage) · [Updating](#updating) · [Uninstall](#uninstall) · [Logs and data](#logs-and-data) · [FAQ](#faq) · [Development](#development) · [Contributing](#contributing)

## Why MacFanPro

- **Free and open source** under the MIT license — no paid tier, no license key.
- **Private**: the only network request is a daily update check against this GitHub repository. No analytics, no accounts.
- **Native and light**: a Swift menu bar app and a small background service; no Electron, no Dock icon.
- **Safe by design**: a 95°C safety override, a background thermal floor that works even if the app quits, and a watchdog that hands the fans back to macOS if the app stops responding.
- **Scriptable**: a `macfanpro` CLI to set speeds, read JSON status and record CSV samples.
- **18 languages**, following your system language, including right-to-left Arabic.

An open-source alternative to tools like Macs Fan Control for people who want transparent, scriptable fan control on Apple Silicon.

## Features

- **Temperature and fan monitoring**: CPU, GPU, memory, SSD and ambient temperatures, and each fan's actual speed. Which readings appear depends on the sensors your Mac provides.
- **Automatic fan control**: Smart, Silent, Balanced, Performance and Max profiles, plus a one-click return to Apple's automatic control.
- **Native menu bar app**: the panel sizes itself to its content; the temperature label reserves room for "icon + two digits + °", stays centered, and widens for three digits.
- **18 interface languages**: English, Simplified Chinese, Traditional Chinese, Japanese, Korean, German, French, Spanish, Italian, Brazilian Portuguese, Russian, Ukrainian, Polish, Dutch, Turkish, Vietnamese, Indonesian and Arabic (laid out right to left), following the system language by default. You can also switch between °C and °F and launch at login.
- **Command line and background service**: set speeds, read status and record CSV samples. Once installed, the app and everyday commands control the fans through the background service.

The screenshots above are MacFanPro 0.2.3.27 running on an M4 Max MacBook Pro.

## Requirements

- An Apple Silicon Mac with macOS 14 or later. Intel Macs are not supported.
- Fan control needs a Mac with fans; fanless models cannot use it.
- Installing or updating the background service needs administrator rights. Building from source needs Xcode 16 or later.

Hardware testing so far has been mainly on an M4 Max MacBook Pro. Treat other models, macOS versions and display setups as untested; see the [0.2.3.34 validation record](docs/macfanpro-0.2.3.34-validation.md) (in Chinese) for the exact scope.

## Install

**Pick one of the methods below; you don't need more than one.** If MacFanPro is already running, choose Quit in its menu first.

| Method | Best for | Builds on your Mac? |
| --- | --- | --- |
| Online installer | One command; downloads and verifies a release | No, no Xcode needed |
| Homebrew | Installing and managing versions with Homebrew | No, prebuilt |
| Release download | Using the prebuilt app and CLI | No, no Xcode needed |
| From source | Changing the code, debugging, or building yourself | Yes, needs Xcode |

### Online installer

```bash
curl -fsSL https://github.com/macfanpro/macfanpro/releases/latest/download/install.sh | bash
```

Run as your normal login user. The script downloads and verifies the prebuilt package, then asks for your administrator password to install the app and background service. Existing Homebrew installations use `brew update` / `brew upgrade` and keep Homebrew ownership; the requested version must be available in the tap. Other installations use the release package. Configuration and calibration data are retained; downgrades are refused. Running it again reinstalls/checks the selected version.

To inspect the script first, download `install.sh` and `install.sh.sha256` from the **same release**, then run:

```bash
shasum -a 256 -c install.sh.sha256
less install.sh
bash install.sh
```

Use `bash install.sh --check` to download and validate without installing, `--no-open` to leave the app closed, or `--version 0.2.3.34` to select a package version (a minimum version on Homebrew). The script bundled in each release defaults to that exact release. See [installer details and verification](docs/online-installer.md).

### Option 1: Homebrew

You need [Homebrew](https://brew.sh/). Homebrew installs a prebuilt version, so no Xcode is needed; only if Homebrew can't use it (for example, when installed outside `/opt/homebrew`) does it build from source, which needs Xcode 16 or later.

Run in Terminal:

```bash
brew tap macfanpro/tap
brew trust macfanpro/tap
brew install macfanpro
sudo "$(brew --prefix macfanpro)/bin/macfanpro" install
open /Applications/MacFanPro.app
```

Since Homebrew 7, formulae from third-party taps are not loaded until you trust the tap with `brew trust` (once). Homebrew downloads, builds and manages the version; the `sudo` command installs that version's app and background service. The formula lives in [macfanpro/homebrew-tap](https://github.com/macfanpro/homebrew-tap).

### Option 2: Release download

No Homebrew or Xcode needed.

1. Go to [Releases](https://github.com/macfanpro/macfanpro/releases/latest) and download `MacFanPro-<version>-macos-arm64.tar.gz`. Choose this package, not GitHub's automatic `Source code` archives.
2. Double-click to extract it. Keep `MacFanPro.app` and the `bin` folder together.
3. In Terminal, go into the extracted folder, install, and open the app.

For example, with `0.2.3.34` extracted in Downloads:

```bash
cd ~/Downloads/MacFanPro-0.2.3.34-macos-arm64
sudo ./bin/macfanpro install
open /Applications/MacFanPro.app
```

For another version or location, change the folder path. After a successful install you can delete the archive and the extracted folder.

Dragging `MacFanPro.app` into Applications alone does not install the background service. Release packages are ad-hoc signed and not yet notarized by Apple, so macOS may warn you the first time; see the [FAQ](#faq).

### Option 3: From source

You need Xcode 16 or later.

```bash
git clone https://github.com/macfanpro/macfanpro.git
cd macfanpro
./setup.sh
```

`setup.sh` builds the code, assembles the app, asks for your administrator password to install, and opens MacFanPro. No further install command is needed.

This builds the repository's `main` branch, which may include unreleased changes. To build a specific release, run `git checkout v0.2.3.34` (with the version you want) before `./setup.sh`.

### After installing

The app is installed at `/Applications/MacFanPro.app`. It lives in the menu bar and has no Dock icon. To start it automatically, turn on Launch at Login in the app.

Terminal shows nothing while you type your administrator password; press Return when done. The app works with the installed background service, so everyday use doesn't ask for your password again.

## Usage

### Menu bar

Click the fan icon in the menu bar to open the panel, check the sensor readings and choose a profile.

| Profile or button | Behavior |
| --- | --- |
| Silent (Apple Default) | Leaves normal temperatures to Apple's automatic control; it does not force the fans off |
| Balanced | Raises fan speed gradually with temperature, on a gentler curve |
| Performance | Responds faster to rising temperature and allows higher target speeds |
| Max | Runs at full speed once its temperature and duration trigger is met; not always at full speed |
| Smart | Follows temperature and its trend; uses valid calibration data when present, and works without calibrating first |
| Default | Releases the current control and returns to Apple's automatic control |

Overheating protection can override the current profile.

The menu also switches the temperature unit, Launch at Login and the language, shows the current version, and checks for updates on demand.

### Common commands

Run these individually as needed. With a normal install and the background service running, none of them needs `sudo`.

| Command | Purpose |
| --- | --- |
| `macfanpro --version` | Show the CLI version |
| `macfanpro status` | Print fan speeds and temperatures as JSON |
| `macfanpro max` | Set all fans to maximum now |
| `macfanpro set 3000` | Request 3000 RPM on all fans, within each fan's hardware range |
| `macfanpro set 3000 --fan 0` | Set only fan 0 |
| `macfanpro auto` | Return to Apple's automatic control; the menu bar app keeps running |
| `macfanpro auto --stop-app` | Quit the menu bar app and return to Apple's automatic control |
| `macfanpro log --duration 60s` | Record 60 seconds of sensor data to CSV |
| `macfanpro --help` | List all commands; add `--help` to any command for details |

`max` and `set` create a speed held from Terminal; the app shows a notice and pauses its own control. Press Default, pick a profile, or run `macfanpro auto` to release it. Quitting the menu bar app alone does not release a speed held from Terminal.

`macfanpro auto` does not quit the app, and the app's automatic profiles may take over again. To hand control back to macOS completely, use `macfanpro auto --stop-app`.

The advanced `watch` command keeps controlling the fans by profile (it is not read-only), and `calibrate` runs a load while changing fan speeds. Both need administrator rights; read their `--help` first. Neither is needed for everyday use.

## Updating

The online installer above also upgrades existing installations. The app’s “Update in Terminal” uses the same bundled installer.

The app checks this repository's releases once a day, and you can check now with Check for Updates at the bottom of the menu. When a new version is out it shows the upgrade steps for how you installed, and an **Update in Terminal** button that runs them for you: Terminal opens, downloads or upgrades, and asks for your password once. It never replaces the program without you. The check needs access to GitHub and uses your system proxy settings; if it says it couldn't reach GitHub, check your network or proxy. Update the same way you installed, and quit the app before replacing the background service.

### Homebrew

```bash
brew update
brew upgrade macfanpro
macfanpro auto --stop-app
sudo "$(brew --prefix macfanpro)/bin/macfanpro" install
open /Applications/MacFanPro.app
```

`brew upgrade` updates Homebrew's copy; the background service and the app in `/Applications` still need syncing afterwards. If Homebrew reports an `untrusted tap`, run `brew trust macfanpro/tap` once. `brew --prefix` points at the version you just upgraded to, instead of an older system copy.

### Release download

Download and extract the new version, quit the running app, go into the **new version's extracted folder**, and repeat the release install steps. The installer replaces the app and the background service; you don't need to uninstall first, and your data is kept.

### From source

If you cloned the `main` branch as above, save your own changes, quit the app, and run in the source folder:

```bash
git pull --ff-only
./setup.sh
```

If you checked out a release tag, run `git fetch origin --tags`, check out the new tag, and run `./setup.sh`.

## Uninstall

Remove the app, the command-line tool and the background service, keeping your data:

```bash
sudo macfanpro uninstall
```

To also delete your profiles, calibration data, samples and runtime logs, and the background service's logs, run this **instead**:

```bash
sudo macfanpro uninstall --purge-data
```

If you installed with Homebrew, also run afterwards:

```bash
brew uninstall macfanpro
```

`--purge-data` removes your `~/Library/Application Support/MacFanPro/` and `~/Library/Logs/MacFanPro/`, and the background service's `/var/root/Library/Logs/MacFanPro/`. It does not delete custom export folders or separately stored interface preferences. Dragging the app to the Trash or running only `brew uninstall` does not remove the background service.

## Logs and data

Runtime logs and manual samples are kept under different rules:

| Data | Default location | Retention |
| --- | --- | --- |
| App runtime logs | `~/Library/Logs/MacFanPro/` | Up to 7 calendar days (including today), 5 MiB per file, 50 MiB in total for managed logs in the folder |
| Background service logs | `/var/root/Library/Logs/MacFanPro/` | Same as the app's, counted separately |
| Temporary CSV samples | `~/Library/Application Support/MacFanPro/logs/` | Up to 100 MiB per recording, kept 24 hours after it ends normally |
| Profiles and calibration | `~/Library/Application Support/MacFanPro/` | Not cleaned up by the log rules |

Runtime logs are pruned at launch, when a new file starts (size limit or a new day) and hourly while running; together the two managed log folders hold at most 100 MiB by default. If writing to disk fails, file logging pauses and retries later, with a bounded queue.

Background service logs belong to root and need administrator rights to read, for example the last 50 lines of today's log:

```bash
sudo tail -n 50 "/var/root/Library/Logs/MacFanPro/macfanpro-$(date +%F).log"
```

A temporary sample stops and keeps its data when it reaches its size limit. Its expiry is set when it ends normally, on Ctrl-C or on SIGTERM; an abnormal exit also leaves a marker so it can be cleaned up. Expired samples that are no longer being written are removed at app launch, hourly while the app runs, and when the next sample starts. While the app isn't running, your samples stay until the next cleanup. Sample folders left by older versions without an expiry marker can't be told apart from manual exports, so they are never deleted automatically; remove them yourself if you don't need them.

**The 100 MiB limit applies to each recording, not to the sample folder as a whole.** Samples made with `--output <folder>` or `--no-expire` are kept permanently without that limit; manage them yourself. Older samples without an expiry marker and other files are not deleted automatically.

## FAQ

### The background service is unavailable or its version doesn't match

The app, the CLI and the background service must come from the same version. Quit the app, then repeat the install or sync steps for how you installed: Homebrew users use the formula's CLI, release-download users use `./bin/macfanpro` in the extracted folder. Then reopen the app. If it still fails, keep the Terminal error and the logs from that time for troubleshooting.

### macOS says it can't verify the developer

Release packages are not yet notarized by Apple. If you're sure the file came from this repository and hasn't been tampered with, follow [Apple's instructions](https://support.apple.com/102445): after trying to open it, go to System Settings → Privacy & Security and look for Open Anyway.

Each release includes `SHA256SUMS`. Put it in the same folder as the archive and run `shasum -a 256 -c SHA256SUMS` to verify the download. A checksum is not the same as Apple notarization.

### Temperatures or fan readings differ from another Mac

Models differ in their sensors, number of fans and speed ranges. When reporting an issue, include your Mac model, macOS version, MacFanPro version, install method, steps to reproduce, and the relevant status output or log excerpt. Report issues at [Issues](https://github.com/macfanpro/macfanpro/issues).

### Temperatures don't match Stats or similar tools

MacFanPro's CPU and GPU rows show the **highest** reading of their sensors. Compare them with Stats' "Hottest CPU / Hottest GPU", not "Average". On the M4 family, the CPU row uses the same core sensors as Stats; other chips group sensors by prefix, which may differ from other tools. Fan control and the 95°C safety threshold follow the chip's hottest point, including hotspot sensors that the CPU row doesn't show, so the fans may speed up before the CPU or GPU rows reach the threshold. The comparison method and measurements are in the [sensor calibration record](docs/thermal-sensor-calibration-20260924.md).

## Development

### Project layout

| Path | Contents |
| --- | --- |
| [`Sources/MacFanProApp/`](Sources/MacFanProApp/) | SwiftUI menu bar app, UI state and interaction |
| [`Sources/MacFanProCore/`](Sources/MacFanProCore/) | SMC access, fan control, background service communication, profiles and logging |
| [`Sources/MacFanProLocalization/`](Sources/MacFanProLocalization/) | Language selection and translations |
| [`Sources/macfanpro/`](Sources/macfanpro/) | CLI, app assembly, install and uninstall |
| [`Tests/MacFanProTests/`](Tests/MacFanProTests/) | Automated tests |
| [`Scripts/`](Scripts/) | Test, localization check and release packaging scripts |

### Build and test

From the repository root:

```bash
swift build
bash Scripts/test.sh
bash Scripts/test.sh -c release
bash Scripts/check-localization-package.sh
```

These build and test the project without installing anything. `Scripts/test.sh` runs the Swift tests and then the client-disconnect check; CI also covers Debug, Release and localization packaging.

To build a release package locally:

```bash
bash Scripts/package-release.sh
```

Output goes to `dist/`: a `.tar.gz` with the app and CLI, and `SHA256SUMS`. Packaging doesn't replace the installed app; run `./setup.sh` when you want to install a development build.

When opening a [Pull Request](https://github.com/macfanpro/macfanpro/pulls), describe the problem, the scope of the change and how you verified it. Changes to fan control, background service communication or native menu behavior should include matching hardware checks, keeping automated tests, isolated rendering tests and real hardware results distinct.

### Documentation

- [Changelog](CHANGELOG.md): the main changes in each release.
- [GUI localization](docs/gui-localization.md): the 18 interface languages, how to add a language, and the layout and packaging checks.
- [Release notes guide and template](docs/releases/README.md) (in Chinese): per-release notes, downloads, upgrade notes and evidence.
- Per-release validation records (in Chinese): `docs/macfanpro-<version>-validation.md`, for example [0.2.3.34](docs/macfanpro-0.2.3.34-validation.md).
- [Fan state and calibration fixes](docs/fan-state-fixes-20260927.md): the audits behind 0.2.3.20 to 0.2.3.24.
- [Temperature changes relative to upstream](docs/upstream-divergence.md): changes to reapply when merging upstream.
- [Menu bar label validation](docs/menu-bar-label-validation.md): minimum width, digit changes and isolated rendering tests.
- [M4 fan handoff repair](docs/m4-handoff-repair.md): the hardware behavior and the reasoning behind the fix.

`docs/upstream/` and early acceptance documents are kept as history; they are not test conclusions for the current release or for every model.

Versions are **the upstream version plus a fourth revision number**, defined in [`Version.swift`](Sources/MacFanProCore/Version.swift). For example, `0.2.3.15` is based on upstream `0.2.3`; the first three parts change only after a new upstream release is merged. The app and CLI compare versions part by part numerically, treating missing parts as 0, with no special cases for older versions.

## Contributing

All kinds of contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for details. For questions and ideas, use [Discussions](https://github.com/macfanpro/macfanpro/discussions); report security problems privately as described in [SECURITY.md](SECURITY.md).

- **Bug reports**: report problems or submit a compatibility report in [Issues](https://github.com/macfanpro/macfanpro/issues), with your Mac model, macOS version, MacFanPro version and `macfanpro status` output.
- **Code**: build and test as described in [Development](#development), then open a [Pull Request](https://github.com/macfanpro/macfanpro/pulls).
- **Translations**: the interface translations were made by the maintainer; native speakers are welcome to correct them or add a language. See [GUI localization](docs/gui-localization.md).

### Contributors

<a href="https://github.com/macfanpro/macfanpro/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=macfanpro/macfanpro" alt="MacFanPro contributors">
</a>

## Credits and license

MacFanPro is maintained by [@hongyukeji](https://github.com/hongyukeji) under the [MIT License](LICENSE). It is independently maintained on top of [ThermalForge](https://github.com/ProducerGuy/ThermalForge), with its own versions, install names and update channel; it is not an official upstream release. The ThermalForge upstream copyright and license are kept in full; see [NOTICE.md](NOTICE.md) and [ThirdPartyNotices/](ThirdPartyNotices/) for the derivation and third-party dependencies.
