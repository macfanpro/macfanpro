# GitHub repository and website migration — 2026-10-14

## Destinations

- Authoritative repository: `macfancontrol/macfancontrol` (original repository ID 1378207908).
- Website: https://macfancontrol.github.io/macfancontrol/ (18 languages).
- Homebrew: `macfancontrol/homebrew-tap`; old tap URL continues to redirect.
- Gitee: `macfancontrol/macfancontrol`, one-way mirror of the authoritative GitHub repository.
- Legacy update repository: `macfanpro/macfanpro` (prepared as `macfanpro/update-compat`, ID 1418213839).

The compatibility repository occupies the original path. This intentionally replaces GitHub's repository redirect: old clients reject a latest-release URL outside the old repository. Verified release copies keep their final URLs compatible. Source clones must change origin to the new repository, as explained in the old repository README.

## Compatibility maintenance

`Scripts/legacy-bridge/` is the reviewed source for the compatibility repository's release sync script and workflow. Copy updates there explicitly. The workflow copies public stable releases, verifies source checksums and downloads uploaded copies before publishing drafts. Existing matching asset digests avoid redundant transfers. It does not build software, install services or copy secrets. Failed jobs leave new releases as drafts and can be rerun.

Publishing or editing a release in the main repository triggers and waits for compatibility synchronization via the Actions-only LEGACY_DISPATCH_TOKEN. Every 15 minutes the compatibility repository also checks for new releases. GitHub may delay scheduled jobs. Maintainers also trigger and verify this workflow after publication (see releases/README.md). A monthly successful-sync commit prevents the repository's scheduled workflow from becoming inactive due to lack of repository activity.

Old Pages redirects retain a supported language path, query string and fragment. Without JavaScript a visible link remains available. No credentials are used by the redirect.

## Validation

- Debug and Release: 169 tests in each configuration passed, using simulated SMC and isolated data.
- Installer regressions, disconnected-client checks, 6 Gitee mirror tests, localization/package checks passed.
- Three compatibility-script checks reject invalid repository pairs, non-GitHub assets and bad source digests before upload/publication.
- All 18 website language pages build and validate.
- No local privileged install, background service replacement or fan-control operation was performed.
- Live transfer, Pages deployment, old update URLs, Homebrew and Gitee acceptance results will be appended after cutover.
