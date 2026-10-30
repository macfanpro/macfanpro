# MacFanPro 0.2.3.68 validation

## Scope

- Change the normal update interval from 24 hours to six hours.
- Keep the one-hour failure retry, manual checks, and persisted next-check timestamp.
- Synchronize English and Chinese documentation. Thermal/fan-control behavior is unchanged.

## Acceptance

Local release-source checks passed:

- `bash Scripts/test.sh --all-configurations`: Debug and Release each passed 182 tests in 33 suites.
- Disconnect integration: 108 abandoned replies followed by a successful request, and 300 vanished-daemon failures handled cleanly.
- Installer fixtures: 17 tests; Gitee mirror fixtures: seven tests.
- `bash Scripts/check-localization-package.sh .build/release`: passed.
- `git diff --check`: passed.

## Release source and build

- Source commit: `426202ef62a3c77a63b1555765188deb50877cbc`.
- Annotated tag `v0.2.3.68`: `61752e428587af3deb4bb54f836508051a6f0ee3`, verified against GitHub and resolved to the source commit.
- Built locally using `RELEASE_TAG=v0.2.3.68 bash Scripts/package-release.sh dist/release-0.2.3.68` on macOS 27.0.1 (26A434), Xcode 27.1 (27A9275).
- Hosted [Release run](https://github.com/macfanpro/macfanpro/actions/runs/41092350943) was cancelled while queued, before any steps ran, because no macOS runner was assigned. Local artifacts use the same checked-in packaging script.
- Independent [CI run](https://github.com/macfanpro/macfanpro/actions/runs/41092351583) was still queued at publication preparation; hosted tests are not claimed as passed.

## Downloaded draft acceptance

All six draft assets were downloaded anew before publication:

- Downloaded bytes match local artifacts and GitHub SHA-256 asset digests.
- Archive, DMG and installer checksum manifests passed.
- Archive passes the previous 0.2.3.66 installer's verification functions without invoking installation.
- App and helper versions are 0.2.3.68; app identity is `io.github.macfanpro.app`.
- App signatures pass `codesign --verify --deep --strict`.
- DMG verifies, mounts read-only, contains an application identical to the archive and an `/Applications` link, and was detached after inspection.
- All 18 packaged language tables match source resources.
- Downloaded installer equals the embedded installer and passes `bash -n`.

| Asset | SHA-256 |
| --- | --- |
| DMG | `6952e29b6a683efcba6d39012a9b37da8d97b06067bf5de0eac853a01c4e355c` |
| App + CLI archive | `c1839f7a2588272c5cacc59cf0ea8d97b7dd30bc332707251de412d87997e4d9` |
| Installer | `7dd486839d237ef4af5548ce7871ea4ed1c36d3c6709010c14d13956e545f172` |

Logs and verification scripts are retained under ignored `dist/validation-0.2.3.68/`.

## Limitations

Packages use ad-hoc signatures and are not notarized by Apple. No physical fan writes, service installation, high-temperature stress or physical sleep/wake acceptance is performed for this change.
