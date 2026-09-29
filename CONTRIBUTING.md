# Contributing to MacFanPro

Thanks for helping! Bug reports, compatibility reports, code and translations are all welcome. 中文用户也可以直接用中文提交 issue 和 PR。

## Report a bug or a compatibility result

Open an [issue](https://github.com/macfanpro/macfanpro/issues) with:

- your Mac model (for example `MacBook Pro 16" M4 Max`) and macOS version,
- the MacFanPro version (`macfanpro --version`) and how you installed it,
- what you did, what you expected and what happened,
- the output of `macfanpro status`, and relevant lines from `~/Library/Logs/MacFanPro/`.

Reports from Macs other than the M4 Max are especially useful: most hardware testing so far has been on that model. The *Compatibility report* issue template lists what helps.

For questions and ideas, use [Discussions](https://github.com/macfanpro/macfanpro/discussions). For security problems, see [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Contribute code

You need an Apple Silicon Mac with Xcode 16 or later.

```bash
git clone https://github.com/macfanpro/macfanpro.git
cd macfanpro
swift build
bash Scripts/test.sh
bash Scripts/test.sh -c release
bash Scripts/check-localization-package.sh
```

These build and test without installing anything. Run `./setup.sh` to install your build on your own Mac.

In your pull request, describe the problem, the scope of the change and how you verified it. Keep automated tests, rendering tests and real-hardware results distinct, and say which Mac you tested on. Changes to fan control, the background service or its protocol need tests; `Tests/MacFanProTests/ControlLoopRecoveryTests.swift` drives the real control loops against a simulated SMC, so most failure cases can be tested without touching your fans.

Commit messages start with a short type, as in the history: `fix:`, `feat:`, `docs:`, `release:`.

MacFanPro follows upstream [ThermalForge](https://github.com/ProducerGuy/ThermalForge). Prefer small changes in place over restructuring upstream files, so upstream releases stay easy to merge; see [docs/upstream-divergence.md](docs/upstream-divergence.md).

## Improve a translation

The menu bar app has 18 languages. The translations were made by the maintainer, so corrections from native speakers are very welcome. Edit `Sources/MacFanProLocalization/Resources/<language>.json`, keeping `{placeholders}` unchanged, and check the layout as described in [docs/gui-localization.md](docs/gui-localization.md); the panel is only 260 pt wide. The same guide explains how to add a language.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
