#!/bin/bash
# Produce the same signed app + CLI layout used by Homebrew and source installs.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
version="$("$bin_dir/macfanpro" --version)"
architecture="$(uname -m)"
test "$architecture" = arm64
if [ -n "${RELEASE_TAG:-}" ]; then test "$RELEASE_TAG" = "v$version"; fi
output_dir="${1:-$PWD/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
stage="$(mktemp -d "${TMPDIR:-/tmp}/macfanpro-release.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
name="MacFanPro-$version-macos-$architecture"
mkdir -p "$stage/$name/bin"
cp "$bin_dir/macfanpro" "$stage/$name/bin/macfanpro"
"$bin_dir/macfanpro" build-app --binary "$bin_dir/MacFanProApp" \
    --icon MacFanPro.icns --dest "$stage/$name/MacFanPro.app"
cp LICENSE NOTICE.md README.md "$stage/$name/"
cp -R ThirdPartyNotices "$stage/$name/"
codesign --force --deep --sign - "$stage/$name/MacFanPro.app"
codesign --verify --deep --strict "$stage/$name/MacFanPro.app"
COPYFILE_DISABLE=1 tar -czf "$output_dir/$name.tar.gz" -C "$stage" "$name"
# Keep SHA256SUMS archive-only: already deployed updaters check every entry.
cp "$stage/$name/MacFanPro.app/Contents/Resources/install.sh" "$output_dir/install.sh"
bash -n "$output_dir/install.sh"
(cd "$output_dir" && shasum -a 256 install.sh > install.sh.sha256)
(cd "$output_dir" && shasum -a 256 "$name.tar.gz" > SHA256SUMS)
printf 'Packaged %s\n' "$output_dir/$name.tar.gz"
