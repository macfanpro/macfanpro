#!/bin/bash
# Validate packaging without opening the app or touching installed files.
set -euo pipefail
cd "$(dirname "$0")/.."
bin_dir="${1:-$(swift build --show-bin-path)}"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/macfanpro-package.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
bundle=MacFanPro_MacFanProLocalization.bundle
# The assembler only copies the icon; a fixture avoids an unrelated icon build.
: > "$check_dir/icon.icns"
"$bin_dir/macfanpro" build-app --binary "$bin_dir/MacFanProApp" --icon "$check_dir/icon.icns" --dest "$check_dir/Check.app"
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$check_dir/Check.app/Contents/Info.plist")" = io.github.macfanpro.app
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleName' "$check_dir/Check.app/Contents/Info.plist")" = MacFanPro
cmp LICENSE "$check_dir/Check.app/Contents/Resources/LICENSE"
resource_dir="$check_dir/Check.app/Contents/Resources/$bundle"
if [ -d "$resource_dir/Contents/Resources" ]; then resource_dir="$resource_dir/Contents/Resources"; fi
for table in Sources/MacFanProLocalization/Resources/*.json; do
 cmp "$table" "$resource_dir/$(basename "$table")"
done
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleLocalizations' "$check_dir/Check.app/Contents/Info.plist" | grep -c '^ ')" = "$(ls Sources/MacFanProLocalization/Resources/*.json | wc -l | tr -d ' ')"
mkdir "$check_dir/unbundled"
cp "$bin_dir/MacFanProApp" "$check_dir/unbundled/MacFanProApp"
echo preserve > "$check_dir/Check.app/sentinel"
if "$bin_dir/macfanpro" build-app --binary "$check_dir/unbundled/MacFanProApp" --icon "$check_dir/icon.icns" --dest "$check_dir/Check.app" > "$check_dir/rejection.log" 2>&1; then
 echo "Unexpected success with missing localization resources" >&2
 exit 1
fi
test "$(cat "$check_dir/Check.app/sentinel")" = preserve
printf 'Localization packaging and missing-resource protection passed.\n'
