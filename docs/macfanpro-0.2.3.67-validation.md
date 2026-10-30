# MacFanPro 0.2.3.67 validation

Validation completed locally on 2026-10-31 (Asia/Shanghai). The source baseline was `614159a`; the candidate is tagged `v0.2.3.67` after these gates. Publication/download checks are recorded separately below.

## Scope

Adaptations of upstream PRs #70, #72–75, #77 and #78. See [adoption decisions](upstream-sync-20261030.md). #68, #76 and #80 are not included. No new upstream main commit was available to merge. The 95/90°C protection, CLI ownership and 100ms control cadence are retained. Normal cold release now requires five sampled seconds; safety/failed-acquisition cleanup and explicit hands-off requests bypass that delay.

## Automated verification

| Gate | Actual result |
| --- | --- |
| `bash Scripts/test.sh --all-configurations` | Debug and Release each passed 182 tests / 33 suites. |
| Disconnected clients | 108 abandoned replies plus a subsequent request, and 300 vanished-daemon requests passed. |
| Online installer / Gitee mirror | 17 installer tests and 7 mirror tests passed. |
| `bash Scripts/check-localization-package.sh .build/release` | Passed: 18 language tables, embedded service/installer, missing-resource protection, failed-copy preservation, complete replacement and strict signature verification. |
| `git diff --check` | Passed. |

Regressions cover ordered exit release and rejection of late writes; mode failure without zeroing targets; automatic/system mode readback; Smart/curve cold confirmation at different tick rates; immediate hands-off and failed-acquisition recovery; UI reselection/clock rollback; anomaly cooldown/compaction; complete/partial/failed inventories, fresh control reads, invalidation, capped retries and discovery time budget; M6 brand scoping.

All automated control tests use simulated SMC, temporary sockets/directories and synthetic clocks. They do not contact the installed service. Existing layout tests rendered retained panels/settings in all 18 languages and both settings appearances with services disabled; this is automated rendering, not inspection of a live candidate app.

## Read-only hardware measurement

Mac16,5 / Apple M4 Max, installed App and daemon remain 0.2.3.66. The standalone `Tools/benchmark-smc-status.swift` opens separate SMC connections, disables runtime logging, and never writes fans or contacts the daemon. Three alternating runs measure 100 warm status reads after five warmups. Every cached run explicitly verified a complete 3,512-key firmware inventory and preserved all 39 directly readable thermal keys / two fans. Core power gating changes the set of values passing the existing temperature filter, so that dynamic snapshot set is not an inventory-equivalence assertion.

| Round | Uncached mean ms | Inventory mean ms |
| --- | ---: | ---: |
| 1 | 12.247 | 7.444 |
| 2 | 9.123 | 7.005 |
| 3 | 9.204 | 8.058 |

These are per-read timings under the current machine workload, not application CPU, battery, temperature, noise or inference-throughput improvements. First cached status reads in these runs took 11.46–13.68ms. Discovery checks a 100ms budget between calls; it cannot interrupt one blocked kernel call. Unsupported enumeration falls back to fresh probes, with at most three attempts per connection/wake. CLI watch and one-shot reads remain uncached.

## Independent review

A separate provider/model, Claude Sonnet 5.5 (`claude-sonnet-5-5`), performed tool-free read-only reviews of the supplied source. Initial findings led to a five-second overall quit deadline with once-only reply, asynchronous monitor cancellation, off-main daemon wake handling, CLI watch exclusion, bounded inventory retries/time budget, and M6-only additions. Final signoff: no remaining blocker or should-fix, conditional on the final budget test passing; that test subsequently passed in both full configurations.

Non-blocking limits: a single stuck IOKit call is not cancellable by the discovery budget; wake invalidation is asynchronous; existing SIGTERM recovery can wait behind an acquisition's hardware lock. No universal thermal limit or physical fan-wear claim is derived from the upstream reports.

## Local distribution acceptance

The candidate tar.gz, DMG and pinned installer were built with `Scripts/package-release.sh`. All three checksum manifests passed. The old v0.2.3.66 installer's `verify_archive` / `verify_package` accepted the package without running installation. App/CLI/helper version and bundle identity match; strict deep codesign passed. The DMG was mounted read-only: its App matches the archive, its Applications link is correct, and its embedded installer matches the standalone asset. All 18 JSON language tables match source bytes and CFBundleLocalizations contains 18 languages.

Local evidence is retained in ignored `dist/validation-0.2.3.67/`: `all-configurations.log`, `localization-package.log`, `package-release.log`, `local-assets.log`, `smc-benchmark-final.log` and the three independent-review JSON results.

## Downloaded draft / publication

Pending creation of the tag-triggered draft. The downloaded draft assets must pass the same acceptance script before publication. Homebrew automation is checked after public release.

## Not performed

No candidate application installation, daemon restart, fan-control write, high-temperature stress, physical sleep/wake control test, clean-Mac authorization/uninstall test or M6 hardware acceptance. These are not claimed by automated tests or read-only timing. Packages use ad-hoc signatures and are not notarized by Apple.
