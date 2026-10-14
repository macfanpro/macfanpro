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

## Verified release and Homebrew evidence

- Source tag `v0.2.3.64`: `7d8549613b15461ad9e4bc2e92c50f2dc28c5b63`.
- [Main CI](https://github.com/macfanpro/macfanpro/actions/runs/38489705341) and [release CI](https://github.com/macfanpro/macfanpro/actions/runs/38489709385) passed.
- All eight GitHub draft assets were downloaded. Both archive manifests, DMG checksum and installer checksum passed. App/helper signatures, CLI 0.2.3.64, new display/executable names, stable bundle ID, macOS 14 minimum, 18 localization tables and embedded installer identity passed. The read-only mounted DMG app and both tar copies match. Its Applications link points to `/Applications`.
- The unmodified 0.2.3.63 installer accepted the downloaded legacy archive. No install function was called.
- Real macOS temporary-file check confirmed `chflags -h hidden` hides only the compatibility link, not the new application directory.
- [Homebrew acceptance](https://github.com/macfanpro/homebrew-tap/actions/runs/38489722878) built/poured the new bottle, installed the real old 0.2.3.63 bottle, then successfully ran `brew upgrade macfanpro`. Homebrew migrated the formula to `macfancontrol`, poured 0.2.3.64, resolved both formula names to the same prefix and passed `brew test`, including both command names. No daemon was installed on the runner.
- Independent formula CI initially failed because it lacked Homebrew tap trust. The workflow now trusts the tap and uses the canonical formula; [rerun](https://github.com/macfanpro/homebrew-tap/actions/runs/38490007541) passed.
- The source-only `uninstall.sh` helper was subsequently updated on main in `565553d` to choose the canonical command and fall back to the legacy command. This helper is not part of the release app, DMG or tar assets.

### Downloaded draft checksums

```
801be1f79d62f98fb90b0cd49129f6db3591dc43128ca684ceb175d3a7047702  MacFanControl-0.2.3.64-macos-arm64.tar.gz
ebf344016453bc67fcd85b0b02ba1267ddd15857424d10671eb7bd58e5f77118  MacFanPro-0.2.3.64-macos-arm64.tar.gz
3bf6ccd68c72f222dd30cdeaa8e427bebe1a439bf1255b6ef39c5119e7e91c34  MacFanControl-0.2.3.64-macos-arm64.dmg
85de210437c8cdea72d7e27507f555d95b344774ffe5925dc0f4938d212a6ad1  install.sh
```
