# Update checks and the Updates section

Status: implemented. Since 0.2.3.63 the update details live in the **Updates** section of the settings window; the separate update window (0.2.3.52–62) was removed (2026-10-08). The original multi-phase proposal is superseded by the behavior below; this is not a release announcement.

## Current behavior

- The app checks GitHub's public `/releases/latest` redirect daily, retrying about one hour after a failed automatic check. Drafts and prereleases are excluded. It does not download or install an update without a user action.
- The panel shows one "{version} available" row and a dot on **Settings**. A normal release never inserts installation instructions above the temperatures or fan controls. Daemon-unavailable, daemon-version and external-control warnings keep their existing priority.
- With no known update, **Check for Updates** runs a manual check. Checking disables the action; a definitive result displays **Up to date**, an available version, or a network failure with **Retry**. Automatic failures preserve the last known offer without presenting an error window.
- The row closes the menu and opens the settings window, whose last section, **Updates**, holds the offer. Settings is the only window; opening it again brings it forward. Switching application language updates the content and window title; all 18 catalogs are covered, including Arabic layout direction. Content taller than the screen scrolls inside the window.
- The section shows the current and new version, a **What's new** link and one primary action. Homebrew installations use **Update in Terminal**; other installations use **Open download page**. The latter opens the release page, not an automatic DMG download. DMG updates replace the app without uninstalling the background service.
- **Other update methods** contains selectable installer and source-build commands. Non-Homebrew installations can also use the bundled Terminal installer there. The copyable Homebrew command and Terminal button both pass `--homebrew`.
- Network/proxy help is collapsed under **Download help**. Direct access is the normal path; no proxy or mirror is silently added.
- Closing settings only closes the window. The offer remains in the menu. A legacy `updateDismissedVersion` written by an older app remains respected by automatic checks; a manual check can show that release again. This UI never writes a new dismissal.
- A successful Terminal launch means only that the handoff succeeded, not that installation completed. The launch action is disabled while launching and after handoff; closing and reopening settings allows another attempt. Failure is visible and can be retried. Failed release-page navigation is also visible.

## Scope and implementation

| Location | Responsibility |
|---|---|
| [MenuBarView](../Sources/MacFanProApp/MenuBarView.swift) | Compact status and action; only the menu's focus loss clears its transient check result. |
| [UpdateSection](../Sources/MacFanProApp/UpdateSection.swift) | The settings window's Updates rows, localized details and guarded handoff state. |
| [UpdateScript](../Sources/MacFanProApp/UpdateScript.swift) | Bundled installer launcher; propagates startup failures and removes temporary files on failure. |
| [AppState](../Sources/MacFanProApp/AppState.swift) | Existing cadence, persisted offers, manual results and install-channel detection. |
| [UpdateChecker](../Sources/MacFanProCore/UpdateChecker.swift) | Release-redirect validation and numeric version comparison. |

The fan-control path, background service lifecycle, installed app, user preferences and release pipeline are outside this UI change. No new dependency is required. Embedded release notes, background installation, installer progress, an automatic-check preference and last-checked timestamps are not implemented by this change.

## Verification

```bash
swift build --product MacFanProApp
MACFANPRO_PREVIEW_DIR="$PWD/.build/update-ui-evidence/previews" \
  swift test --no-parallel --filter 'LocalizedPanelTests|UpdateScriptTests|UpdateCheckerTests|LocalizationTests'
bash Scripts/test.sh
bash Scripts/check-localization-package.sh
```

The presentation tests render the retained menu and the settings window with an available update without starting services or contacting SMC. They cover both install channels, all languages, light/dark appearance, the height cap, window reuse/reopen and retention of the available offer. Launcher tests exercise literal shell arguments, failure cleanup, injection rejection, retry and duplicate handoff prevention. Native interaction acceptance uses an isolated test window; it does not install an update on the running machine.
