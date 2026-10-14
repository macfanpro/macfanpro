# MacFanControl 0.2.3.65 validation

## Scope

Repository and website migration, legacy release synchronization, canonical update/download URLs, and version bump. No fan-control algorithm changes.

## Completed migration checks

- Original GitHub repository ID 1378207908, 13 stars, commit history and releases preserved.
- Old repository ID 1418213839 contains 37 verified stable release copies / 138 uploaded attachments through 0.2.3.64.
- Unmodified v0.2.3.63 installer downloaded and verified 0.2.3.64 from the migrated old endpoint with `--check` (no install).
- Old latest URL remained `github.com/macfanpro/macfanpro/releases/tag/v0.2.3.64`.
- New 18-language Pages deployment and old-site language/query/fragment redirect checks passed.
- Gitee source repository references now use the new GitHub repository; code sync and v0.2.3.64 release check passed.

## Release gates

Version-specific automated results and downloaded draft asset validation will be appended after execution, before publication.

## Boundaries

No local privileged install, service replacement or real fan writes. Packages remain ad-hoc signed and not Apple notarized. Cloud Homebrew migration and isolated installer tests do not prove every historical runtime configuration.

## Version-specific local checks before tagging

- Debug / Release: 169 tests each passed for the 0.2.3.65 sources.
- 18 installer cases, 7 Gitee mirror cases, 3 compatibility bridge cases and disconnected-client regressions passed.
- Release CLI reports 0.2.3.65; localization/service-helper packaging and ad-hoc signature checks passed.
- All 18 website pages build and link validation passes; `git diff --check` passed.
- Immediate compatibility dispatch and synchronization succeeded after migration (38498071693 / 38498079925).
