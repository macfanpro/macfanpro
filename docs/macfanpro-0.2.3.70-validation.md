# MacFanPro 0.2.3.70 validation

## Scope

Retain processed CLI speed-command details when low-level ramp logging is quiet. Add simulated dispatcher/logging coverage and independent temperature, mode and sensor-disappearance publication coverage. No changes to SMC writes, permission checks, ownership or thermal protection.

## Checks

Local release-source checks passed:

- Debug and Release each passed 190 tests in 36 suites.
- Disconnect integration passed: 108 abandoned replies and a subsequent request; 300 vanished-daemon requests failed cleanly.
- Installer fixtures: 17 tests; mirror fixtures: seven tests.
- Localization/installer packaging, missing-resource protection and `git diff --check`: passed.

The logging regression drives the real dispatcher and FanControl against simulated SMC, captures processed request diagnostics, and verifies the low-level quiet window remains in effect. A second case keeps hardware at simulated thermal max while recording the queued CLI target and advisory.

Tests use isolated temporary resources and never the installed socket or real fans. No service installation, physical fan writes, high-temperature stress or physical sleep/wake acceptance is performed.

## Release acceptance

Hosted checks and downloaded-draft acceptance are pending.
