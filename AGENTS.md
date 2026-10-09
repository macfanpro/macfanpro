# Working on MacFanPro (for AI agents and contributors)

MacFanPro is a fork of [ThermalForge](https://github.com/ProducerGuy/ThermalForge). Several agents (Codex, Claude Code) work on it, sometimes at the same time. These rules keep their work from colliding.

## Develop on main by default

- As requested by the maintainer on 2026-10-10, make changes directly on `main` in the existing checkout. Create a separate branch, worktree or pull request only when the maintainer asks for one.
- Before starting, `git fetch` and inspect the branch, working tree and difference from `origin/main`. Fast-forward when safe; preserve existing uncommitted work and coordinate overlapping edits with other agents.
- Scope commits to the current task. Do not overwrite, discard or commit another agent's unrelated changes. Push when the maintainer requests it.
- If the maintainer requests a branch, use a tool/topic name such as `codex/<topic>` or `claude/<topic>`. Before merging it, rebase or merge the current `origin/main` and rerun the tests.

## Releases

- Only one release at a time. Before tagging, check that no other release is in progress: no unpublished draft on GitHub (`gh release list`) and no open `release:` pull request.
- Follow [docs/releases/README.md](docs/releases/README.md). A release is a version bump, notes in `docs/releases/<version>.md`, a validation record `docs/macfanpro-<version>-validation.md`, a tag, a verified draft, then publish. Homebrew updates automatically after publishing.
- Never publish a draft whose assets were not downloaded and checked.

## Upstream

- Merge upstream with a real `git merge`, and record the merge in `docs/upstream-sync-<date>.md`: what was adopted, what was kept, and why.
- Prefer upstream's code when it is as good as ours, so later merges stay small. Keep MacFanPro's own approach where it is better, and put stability first.
- Keep changes to upstream lines small, and prefer new files to rewriting upstream ones. Record lasting differences in [docs/upstream-divergence.md](docs/upstream-divergence.md).

## Checks before submitting changes

```bash
bash Scripts/test.sh --all-configurations
bash Scripts/check-localization-package.sh .build/release
git diff --check
```

- Localization: all 18 tables in `Sources/MacFanProLocalization/Resources/` need every key. English values equal their keys. Regenerate `zh-Hant` with `swift Scripts/update-traditional.swift`.
- Keep automated, rendered and real-hardware results distinct in notes and validation records, and say what was not run.

## Hardware and privileges

- Do not run commands that change fan control, install the service or need `sudo` on the maintainer's Mac unless the maintainer asked for it. The maintainer types `sudo` passwords.
- Tests must use the simulated SMC and temporary directories, never the real fans, socket or user files.
