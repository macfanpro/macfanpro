# MacFanPro 0.2.3.69 validation

## Scope

Selective PR #52 performance adaptation: changed-only state publication and routine success-log suppression/sampling. Control execution, safety thresholds, logger file handling and ownership policy are unchanged.

## Checks

Local release-source checks passed:

- Debug and Release: 187 tests in 35 suites each, including five new tests.
- Disconnect integration: 108 abandoned replies followed by a successful request; 300 vanished-daemon requests failed cleanly.
- Installer fixtures: 17 tests; mirror fixtures: seven tests.
- Localization/installer packaging, missing-resource protection, and `git diff --check`: passed.

Focused tests cover unchanged-state notifications, RPM/profile/safety changes, heartbeat debounce and unreadable state, routine-log boundaries, concurrency, errors, advisory results, CLI holds and release requests.

No service installation, physical fan writes, temperature stress or physical sleep/wake testing is performed. Tests use simulated SMC and isolated temporary resources. CPU/battery benefits have not been measured.

## Release acceptance

- Source commit: `ebea0007ca6778c9ae85e43204300b5cac3eed8c`.
- Annotated tag `v0.2.3.69`: `9f2444f9ae136a78263ce04628ecef06ba4675ff`; GitHub resolves it to the source commit.
- Hosted macOS 15 [CI](https://github.com/macfanpro/macfanpro/actions/runs/43167219055) and [Release](https://github.com/macfanpro/macfanpro/actions/runs/43167219128) both passed. Each ran Debug and Release with 187 tests, disconnect integration (108/300), installer fixtures (17), mirror fixtures (7), and localization packaging.
- Official artifacts were built by the hosted Release workflow from the tag, not from the separately built local packages.

All six draft assets were downloaded anew before publication:

- Each downloaded SHA-256 matches the GitHub asset digest. Archive, DMG and installer checksum manifests passed.
- The previous 0.2.3.66 installer's archive and package verification functions accepted the archive; no installation function was called.
- App/helper versions are 0.2.3.69, and the app identity is `io.github.macfanpro.app`.
- Strict deep code-signature verification passed.
- DMG verification and read-only mounting passed. Its application matches the archive and its Applications link points to `/Applications`; it was detached after inspection.
- All 18 packaged language tables match source resources.
- Downloaded installer matches the embedded installer and passes `bash -n`.

| Asset | SHA-256 |
| --- | --- |
| DMG | `857095bee11448efc50a875a682c3ad22924a0feeff0743bd9526b8770c080f3` |
| App + CLI archive | `99ecaf09abeb8e79b3e398149b622592b991c15fa211a12a22db19a7c3b85e16` |
| Installer | `e93268cdd708e35e4128170c2797678900d5211f0ca96af0f612b601edd2a0dc` |

Evidence logs, downloaded packages and verification scripts are retained under ignored `dist/validation-0.2.3.69/`.

Packages use ad-hoc signatures and are not notarized by Apple.
