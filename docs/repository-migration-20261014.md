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

Publishing or editing a release in the main repository triggers and waits for compatibility synchronization via the repository-scoped LEGACY_DISPATCH_TOKEN. Every 15 minutes the compatibility repository also checks for new releases. GitHub may delay scheduled jobs. Maintainers also trigger and verify this workflow after publication (see releases/README.md). A monthly successful-sync commit prevents the repository's scheduled workflow from becoming inactive due to lack of repository activity.

Old Pages redirects retain a supported language path, query string and fragment. Without JavaScript a visible link remains available. No credentials are used by the redirect.

## Validation

- Debug and Release: 169 tests in each configuration passed, using simulated SMC and isolated data.
- Installer regressions, disconnected-client checks, 7 Gitee mirror tests, localization/package checks passed.
- Three compatibility-script checks reject invalid repository pairs, non-GitHub assets and bad source digests before upload/publication.
- All 18 website language pages build and validate.
- No local privileged install, background service replacement or fan-control operation was performed.
- Live transfer succeeded. New Pages deployment 38497238465, Homebrew dispatch 38497262803 and tap update 38497271612 succeeded. Gitee code sync 38497416056 and release sync 38497494008 succeeded. The unmodified v0.2.3.63 installer downloaded and verified v0.2.3.64 via the old repository after cutover. All 39 original source tags are also preserved in the compatibility repository, so automatic source archives contain the original code.

The compatibility token is limited to the old compatibility repository. Actions permission dispatches/watches sync; Contents and Workflows write permit copying original source commits containing workflow files. The main repository release job explicitly checks its repository identity to avoid building app releases in the compatibility repository. Token expiry is 2027-10-15. The old repository schedule remains a fallback for a failed immediate notification.
