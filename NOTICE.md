# Attribution

MacFanPro is an independently maintained derivative of
[ProducerGuy/ThermalForge](https://github.com/ProducerGuy/ThermalForge), based on
upstream [v0.2.3](https://github.com/ProducerGuy/ThermalForge/releases/tag/v0.2.3)
(commit `3fbaa527aee05a5a0ed2606f00b50254df9d614f`) and selected subsequent code and documentation updates. It is not an official
ThermalForge release and does not imply endorsement by the upstream authors.

The complete upstream MIT copyright and permission notice is retained in
`LICENSE`, together with the copyright notices for downstream modifications.
The app bundle and downloadable distribution include that license.

The retained release-write checking was informed by John Shojaei's
[PR #30](https://github.com/ProducerGuy/ThermalForge/pull/30), with fresh readback
added after local M4 testing. Profile test directory isolation adapts the focused
test-isolation portion of Sam McLeod's
[PR #47](https://github.com/ProducerGuy/ThermalForge/pull/47).

Installation helpers adapt upstream
[commit 42bb534](https://github.com/ProducerGuy/ThermalForge/commit/42bb5345bc0a8d41a9c47719c3ceb0fbc7249687):
launchd lifecycle checks, executable discovery, process outcome reporting,
regular-file copying and atomic app replacement. The integration choices are
recorded in `docs/upstream-sync-20261007.md`.

The earlier M4, test-isolation, release-validation, localization and native-spacing
contributions remain submitted to upstream as PRs #54–#58. Their review branches
retain the upstream product identity.

The CLI links [Apple Swift Argument Parser](https://github.com/apple/swift-argument-parser),
licensed under Apache 2.0 with the Swift Runtime Library Exception. Its complete
license is distributed in `ThirdPartyNotices/swift-argument-parser-LICENSE.txt`.
