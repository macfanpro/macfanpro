# Check for updates: development plan

Status: a reduced phase 1 shipped in 0.2.3.25 (2026-09-29): a Check for Updates button under the Version row, with an inline result. The user chose the simplest option for a single-developer project. The auto-check toggle, last-checked time, failure breakdown, release-notes window and one-click update below were not built. Networks that need a proxy for GitHub are covered by URLSession's use of the system proxy and a "Couldn't reach GitHub" message; no third-party mirror is used. During testing, the REST API returned 403 with `x-ratelimit-remaining: 0` through a shared proxy exit IP, so the check now follows the public `/releases/latest` redirect instead (a HEAD request; the tag is read from the final URL), which is not subject to the API's 60-per-hour limit.

Original plan (recorded 2026-09-26 against 0.2.3.19):

Goal: a user-facing "Check for Updates" feature comparable to clash-verge-rev and Macs Fan Control: a manual check button, visible check results, an automatic-check toggle and in-app release notes. The work extends the existing background check; it does not replace it.

## What already exists

| Location | Behavior |
|---|---|
| [`UpdateChecker.swift`](../Sources/MacFanProCore/UpdateChecker.swift) | Fetches GitHub `/releases/latest` and compares versions. Every failure returns `.failed` and shows nothing. `evaluate(...)` is pure and covered by `UpdateCheckerTests`. |
| [`AppState.swift`](../Sources/MacFanProApp/AppState.swift), `maybeCheckForUpdate()` | Runs off the 5-second heartbeat but reaches the network at most once a day, or about one hour after a failure. It persists `updateNextCheck`, `updateLatestVersion`, `updateLatestURL` and `updateDismissedVersion` in UserDefaults. A stored update shows at launch before any network call. |
| [`MenuBarView.swift`](../Sources/MacFanProApp/MenuBarView.swift), `UpdateAvailableBanner` | Blue "Update available" banner with the Homebrew and source upgrade commands, a "What's new" link and "Later", which dismisses that version until a newer one ships. The banner is hidden while the orange "Update needed" daemon-mismatch banner is shown. |
| Release flow | CI creates a **draft** release; it is published only after local acceptance. `/releases/latest` excludes drafts and prereleases, so an unaccepted build is never offered. The release body is `docs/releases/<version>.md`. |

Missing today:
- A manual "Check for Updates" action.
- Visible check states: checking, up to date or failed.
- A way to turn automatic checks off.
- The time of the last check.
- Release notes inside the app.
- Upgrade instructions that match how the app was installed.

## How the reference apps behave

- **clash-verge-rev** uses the Tauri updater. It checks on launch (a setting can turn this off) and has a manual check button in settings. A dialog shows the new version and its Markdown notes, and the user can update or ignore. Updating downloads the new version, replaces the app and restarts it.
- **Macs Fan Control** has a "Check for updates" menu item and an "Automatically check for updates" preference. A window shows the new version with its notes, and the user downloads and installs it from there.

Both can replace themselves in one click because each ships as a single signed app bundle.

## Why MacFanPro should not copy one-click install yet

1. **Three components.** MacFanPro consists of the menu bar app, the CLI in `/usr/local/bin` and a root launchd daemon. Replacing only the `.app` immediately causes a version mismatch and the "Update needed" banner. The daemon can only be re-synced with `sudo macfanpro install`.
2. **Homebrew owns the files.** Homebrew builds from source and owns its keg. If the app replaced files itself, `brew` would record the wrong version. `brew` also refuses to run as root, so `brew upgrade` cannot run inside a single administrator prompt.
3. **Signing.** Builds are ad-hoc signed and not notarized. Sparkle-style updaters also need an EdDSA signing key and an appcast.

Recommendation: deliver the work in phases and leave one-click install until last, limited to the release-archive channel.

## Phase 1: manual check, visible status and an auto-check toggle (recommended first)

This phase alone matches the reference apps' everyday behavior.

### Core (`UpdateChecker`)
- Decode `body` (release notes) and `published_at` in `Release`, and carry them on `AvailableUpdate`.
- Split failures into `offline`, `rateLimited` (HTTP 403 or 429; unauthenticated GitHub API requests are limited to 60 per hour per IP) and `other`. The automatic check stays silent on every failure. Only a manual check shows the reason.

### AppState
- Add `@Published var updateCheckState` with the states `idle`, `checking`, `upToDate(Date)` and `failed(reason)`.
- Add `checkForUpdatesNow()`:
  - It skips the daily gate.
  - It shares an in-flight flag with the automatic check, so the two never fetch at the same time.
  - Clicks closer together than about 10 seconds are ignored, to protect the rate limit.
  - A manual check **shows a version even if the user pressed "Later" on it**, because the user asked explicitly. It does not clear `updateDismissedVersion`, so automatic checks keep suppressing that version.
- Add an `autoCheckUpdates` preference in UserDefaults, on by default (today's behavior). When it is off, `maybeCheckForUpdate()` returns immediately.
- Persist `updateLastCheckedAt` and show it, for example "Last checked: today 14:02".

### Menu
Extend the existing MacFanPro-only language and version section; do not add a window.

```
Language                [System ▾]
Version                   0.2.3.19
Check automatically            [✓]
[Check for Updates]  Up to date · 14:02
```

- While a check runs, the button shows a spinner and "Checking…".
- The result reads "Up to date", "Version 0.2.3.20 available" or "Check failed (network / rate limit), retry".
- A found update still uses the existing blue banner at the top.
- The panel is 260 points wide. Confirm the English and Chinese strings fit, and keep the section's 6-point spacing.

### Localization
Add the new keys to `en.json` and `zh-Hans.json`, then regenerate `zh-Hant.json` with `swift Scripts/update-traditional.swift` (see [gui-localization.md](gui-localization.md)).

### Tests
- Test `check()` with a stubbed `URLProtocol`: 200 newer, 200 same version, 403, 429, 404, malformed JSON and offline.
- Test `applyUpdateCheck` for manual and automatic checks, with and without a dismissed version.
- Test that the in-flight flag and cooldown prevent a second fetch.
- Add checking, up-to-date and failed scenarios to `LocalizedPanelTests` in all three languages.

## Phase 2: update details and install-aware instructions

- Change the banner's "What's new" link to open a small window:
  - It renders `body` with `AttributedString(markdown:)`.
  - Its actions are "Copy update command", "Open release page", "Skip this version" and "Later".
- **Show only the upgrade commands for the user's install method.** Today the banner lists both the Homebrew and source commands.
  - Homebrew (`/opt/homebrew/opt/macfanpro` exists): `brew upgrade macfanpro`, then `sudo "$(brew --prefix macfanpro)/bin/macfanpro" install`.
  - Release archive: a direct link to the new `.tar.gz`, plus the archive install step.
  - Source: `git pull --ff-only && ./setup.sh`.
  - A more reliable alternative to detection: have `sudo macfanpro install` record the install method in `/Library/Application Support/MacFanPro/`. **Do not write it into the app's Info.plist**, because that invalidates the code signature.
- Optional: add a `macfanpro check-update` CLI subcommand that reuses `UpdateChecker`.
- Optional: show a small dot on the menu bar label when an update is available. Today the label is marked only for a daemon version mismatch.

## Phase 3 (optional, deferred): one-click update

- **Homebrew:** open Terminal through AppleScript with the full upgrade command filled in, and let the user confirm it. Never run `brew` silently in the background.
- **Release archive:**
  - Download the `.tar.gz` and `SHA256SUMS`, verify the checksum and extract the archive.
  - Run the new archive's own `./bin/macfanpro install` through an administrator prompt, the same way `restartDaemon()` uses `osascript`. Then relaunch the app.
- Before starting this phase, check how an un-notarized, ad-hoc-signed app behaves with quarantine attributes and Gatekeeper after download. Also decide how to guard against a tampered download, since `SHA256SUMS` comes from the same release. This phase carries much more risk and work than phases 1 and 2.

## Documents to update when this ships

- README "更新" section. It currently says the in-app notice only checks this repository's releases and never replaces the program.
- `CHANGELOG.md` and the version's `docs/releases/<version>.md`.
- [upstream-divergence.md](upstream-divergence.md): this is MacFanPro-only UI.
- The Notes handbook *MacFanPro 安装升级与温度核对手册*.
- A validation record for the release, like the existing `macfanpro-<version>-validation.md` files.

## Open decisions

1. **Scope:** phase 1 only in the next release, with phase 2 later (recommended), or phases 1 and 2 together? Is phase 3 wanted at all?
2. **Defaults:** keep automatic checks on by default, and let a manual check show a version the user dismissed with "Later"?
