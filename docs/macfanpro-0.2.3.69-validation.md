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

Build and downloaded-draft verification are pending.
