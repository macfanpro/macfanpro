# Upstream PR review and adaptations — 2026-10-30

Baseline: MacFanPro `614159a`; upstream main remains `42bb5345bc0a8d41a9c47719c3ceb0fbc7249687`, already an ancestor. No new upstream main commits were available to merge. The following are adaptations of still-open PRs, not a merge of their branches or a claim of upstream approval.

| PR | Adopted / retained |
| --- | --- |
| [#74](https://github.com/ProducerGuy/ThermalForge/pull/74) | Anomaly cooldown and consecutive snapshot compaction in a new pure helper. Calibration updates history without consuming a report. Safety/error logging bypasses the gate. |
| [#77](https://github.com/ProducerGuy/ThermalForge/pull/77) | Stop monitor/admission before queue completion. Use asynchronous AppKit termination with a once-only reply and a five-second overall deadline rather than blocking the main actor. Final `releaseAppHold` runs on the same serial queue, preserving CLI ownership without a separate state-read race. |
| [#72](https://github.com/ProducerGuy/ThermalForge/pull/72) | Do not zero a target after its mode write was rejected. Keep our attempts of every fan, Ftst cleanup, fresh mode 0/3 acknowledgement, advisory target semantics and retries. |
| [#73](https://github.com/ProducerGuy/ThermalForge/pull/73) | Five sampled cold seconds for ordinary curve and Smart releases. Reset the streak on warming/profile changes. Preserve immediate explicit hands-off, safety recovery and failed-acquisition cleanup. No change to the 95/90°C safety hysteresis, Smart curve, start threshold or start sustain. |
| [#75](https://github.com/ProducerGuy/ThermalForge/pull/75) | One-second display cadence and immediate profile/state updates. Use a separate clock gate and explicitly reset it on profile changes, avoiding the upstream gate's dependency on a resettable tick counter. |
| [#70](https://github.com/ProducerGuy/ThermalForge/pull/70) | Complete firmware inventory for the app and daemon only (CLI watch remains uncached). Enumeration has a 100ms budget checked between firmware calls. Failed/partial discovery remains fail-open with at most three discovery attempts and exponential backoff per wake/connection; invalidate on wake. Skip absent temperature keys only. No cached control modes, fan count, values or key metadata. |
| [#78](https://github.com/ProducerGuy/ThermalForge/pull/78) | Add missing reported CPU/GPU keys, deduplicating Te09 already present. Several core mappings also appear in Stats. Probe these additions only on M6 CPU brands: some keys also exist on M4 with potentially different meanings. No new chip-specific display table or claim of M6 hardware validation. |
| #80 / #76 / #68 / #69 | Do not import the metadata cache, extra hands-off retry watch or replacement safety governor. Existing slow-acquisition transport repair covers #69. |

## Evidence and limits

Mac16,5 / Apple M4 Max, installed 0.2.3.66: retained October 24–30 runtime logs contained 41,130 anomaly entries and 37,832 history dumps. Anomaly/history output occupied 99.35% of the initial 41,207,734-byte snapshot. There were 238 Smart and 19 ordinary-curve on/off pairs no more than five seconds apart. These are acknowledged control transitions, not proof of physical fan stop or wear. Unified logs retained only the later part of the requested period and did not establish an exit or rejected-release failure.

The read-only benchmark opens its own SMC connections and never writes fans, contacts the daemon, or uses runtime logs/calibration files. Compare raw readable keys separately from status() temperature snapshots: powered-down cores can fall below the existing validity filter, changing snapshot membership without changing firmware inventory. Simulated tests cover partial enumeration, invalidation and fresh control reads.

External references: [Stats SMC](https://github.com/exelban/stats/blob/master/SMC/smc.swift), [Stats mode-3 regression](https://github.com/exelban/stats/issues/2977), [Macs Fan Control sensor fluctuations](https://crystalidea.com/macs-fan-control/temperature-sensors), [TG Pro gradual boost](https://www.tunabellysoftware.com/support/faq/), [NBFC up/down thresholds](https://github.com/nbfc-linux/nbfc-linux/wiki/nbfc_service.json). These support mechanisms, not our exact five-second parameter or a universal temperature limit.

Version-specific validation and publication evidence: [0.2.3.67 validation](macfanpro-0.2.3.67-validation.md).
