# Upstream review — 2026-11-12

Upstream main remains `42bb5345bc0a8d41a9c47719c3ceb0fbc7249687`, already included locally. No upstream-main merge was needed. This is a selective adaptation of unmerged PR #52 commit [3732d13](https://github.com/ProducerGuy/ThermalForge/commit/3732d1337c74cfa0478e8e5ba35b37190fb87b75), not a merge of that PR.

## Adopted in 0.2.3.69

- Publish monitor and daemon state only when individual values change. Preserve unreadable advisory state and the existing two-missed-heartbeat debounce.
- Successful heartbeat/version/state/status requests no longer produce routine request lines. Successful supervised set/setfan requests and per-fan target-write messages are sampled at most once every 30 seconds per key, using a thread-safe uptime clock.
- Keep every failed request, advisory result, explicit CLI hold, max/auto/auto-if-app request and existing safety/recovery message. Record hold-owner changes separately so routine log suppression cannot hide an acquisition.

## Kept local

- No custom curves, editor, status-item replacement or new window lifecycle.
- No persistent file handles: retain the existing asynchronous bounded logger, multi-process rotation and checked append-open behavior.
- No change to SMC writes, polling, profile curves, safety thresholds, command authorization or ownership policy. The gate runs only for diagnostic decisions.

Validation is recorded separately in `docs/macfanpro-0.2.3.69-validation.md`.
