# MacFanControl 0.2.3.64 validation

## Scope

Rename the application, executable, CLI, Swift package/modules, distribution files, current documentation and 18-language website. Keep the existing repository during the transition. Stable installed identity/data contracts and explicit old-name update aliases support existing users.

## Local automated checks

- Debug and Release: 169 tests across 32 suites passed using simulated SMC, temporary sockets/files and isolated defaults.
- Disconnected-client regressions, 17 installer cases and 6 Gitee mirror cases passed.
- Localization packaging passed: 18 resources, new display/bundle names, service helper, installer and missing-resource protection; strict ad-hoc signature verification passed.
- After the final log-compatibility adjustment, 14 logging cases passed in both configurations; old-name log retention is covered. Rename alias tests cover repeated upgrades, unrelated app rejection and restoration after a failed alias operation.
- All 18 website languages built. Headless Chrome checked 1440, 390, 360 and 320 px widths (72 combinations), with no page overflow or header overlap after the narrow-header correction.
- Native UI renders: all languages, panel states and settings in light/dark completed without starting application services. New website images render the actual SwiftUI view with sample readings; they are not hardware measurements.
- Locally built compatibility archive passed the unmodified v0.2.3.63 installer’s archive and package verification. Its old/new CLI copies match, and the canonical app displays MacFanControl.
- `git diff --check` passed.

## Upgrade contracts

- Canonical app: `/Applications/MacFanControl.app`; canonical command: `macfancontrol`.
- The old app path becomes a hidden link only after the new service/app installation succeeds; unrelated apps are rejected. Old executable and Homebrew names remain compatibility entry points.
- Only one fan daemon runs. Existing bundle/service/socket/data identifiers keep old update scripts, preferences and login items working.
- The new release parser accepts exact old/new GitHub repository paths and rejects other repositories/hosts.
- The new archive has `MacFanControl-SHA256SUMS`; old `SHA256SUMS` remains legacy-archive-only for deployed scripts.

## Not performed locally

No installation, privileged authorization, service replacement, fan-control operation, load or sleep test was performed on the maintainer’s Mac. No fresh macOS user/VM installation was performed. Packages remain ad-hoc signed and not Apple-notarized. Full installed-runtime migration is covered by isolated checks, not claimed as a local hardware acceptance.

## Release gates

Draft asset download/verification and Homebrew migration acceptance are recorded below after execution. The repository transfer is deferred; this release must not claim it already happened.
