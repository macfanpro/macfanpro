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
cmp "$bin_dir/macfanpro" "$check_dir/Check.app/Contents/Helpers/macfanpro"
test -x "$check_dir/Check.app/Contents/Helpers/macfanpro"
cmp NOTICE.md "$check_dir/Check.app/Contents/Resources/NOTICE.md"
cmp LICENSE "$check_dir/Check.app/Contents/Resources/LICENSE"
version="$("$bin_dir/macfanpro" --version)"
sed "s/@MACFANPRO_VERSION@/$version/g" Scripts/install.sh > "$check_dir/install.sh"
cmp "$check_dir/install.sh" "$check_dir/Check.app/Contents/Resources/install.sh"
bash -n "$check_dir/install.sh"
resource_dir="$check_dir/Check.app/Contents/Resources/$bundle"
if [ -d "$resource_dir/Contents/Resources" ]; then resource_dir="$resource_dir/Contents/Resources"; fi
tables=(Sources/MacFanProLocalization/Resources/*.json)
for table in "${tables[@]}"; do
 cmp "$table" "$resource_dir/$(basename "$table")"
done
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleLocalizations' "$check_dir/Check.app/Contents/Info.plist" | grep -c '^ ')" = "${#tables[@]}"
mkdir "$check_dir/unbundled"
cp "$bin_dir/MacFanProApp" "$check_dir/unbundled/MacFanProApp"
echo preserve > "$check_dir/Check.app/sentinel"
if "$bin_dir/macfanpro" build-app --binary "$check_dir/unbundled/MacFanProApp" --icon "$check_dir/icon.icns" --dest "$check_dir/Check.app" > "$check_dir/rejection.log" 2>&1; then
 echo "Unexpected success with missing localization resources" >&2
 exit 1
fi
test "$(cat "$check_dir/Check.app/sentinel")" = preserve
if "$bin_dir/macfanpro" build-app --binary "$bin_dir/MacFanProApp" --icon "$check_dir/icon.icns" --dest "$check_dir/Check.app" --installer-script "$check_dir/missing.sh" > "$check_dir/rejection.log" 2>&1; then
 echo "Unexpected success with a missing installer script" >&2
 exit 1
fi
test "$(cat "$check_dir/Check.app/sentinel")" = preserve
if "$bin_dir/macfanpro" build-app --binary "$check_dir/unbundled/MacFanProApp" --localization-resources "$bin_dir/$bundle" --icon "$check_dir/icon.icns" --dest "$check_dir/Check.app" > "$check_dir/rejection.log" 2>&1; then
 echo "Unexpected success with a missing bundled service executable" >&2
 exit 1
fi
test "$(cat "$check_dir/Check.app/sentinel")" = preserve
printf 'Localization/installer packaging and missing-resource protection passed.\n'
