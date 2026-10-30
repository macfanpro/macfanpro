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

Hosted release build and downloaded-draft verification are pending. No physical fan writes, service installation, high-temperature stress or physical sleep/wake acceptance is performed for this change.
