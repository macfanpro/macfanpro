# Working on MacFanPro (for AI agents and contributors)

MacFanPro is a fork of [ThermalForge](https://github.com/ProducerGuy/ThermalForge). Several agents (Codex, Claude Code) work on it, sometimes at the same time. These rules keep their work from colliding.

## One change, one branch

- Work in your own branch and worktree (`git worktree add`, or the agent's own worktree), never directly in the shared checkout on `main`. Another agent may be building, testing or releasing there.
- Name branches by tool and topic, for example `codex/<topic>` or `claude/<topic>`.
- Open a pull request into `main`. The maintainer merges; do not push to `main` unless the maintainer asked you to.
- Before starting, `git fetch` and branch from the current `origin/main`. Before merging, rebase or merge `origin/main` and rerun the tests.

## Releases

- Only one release at a time. Before tagging, check that no other release is in progress: no unpublished draft on GitHub (`gh release list`) and no open `release:` pull request.
- Follow [docs/releases/README.md](docs/releases/README.md). A release is a version bump, notes in `docs/releases/<version>.md`, a validation record `docs/macfanpro-<version>-validation.md`, a tag, a verified draft, then publish. Homebrew updates automatically after publishing.
- Never publish a draft whose assets were not downloaded and checked.

## Upstream

- Merge upstream with a real `git merge`, and record the merge in `docs/upstream-sync-<date>.md`: what was adopted, what was kept, and why.
- Prefer upstream's code when it is as good as ours, so later merges stay small. Keep MacFanPro's own approach where it is better, and put stability first.
- Keep changes to upstream lines small, and prefer new files to rewriting upstream ones. Record lasting differences in [docs/upstream-divergence.md](docs/upstream-divergence.md).

## Checks before a pull request

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
