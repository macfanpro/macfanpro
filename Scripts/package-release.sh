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
codesign --force --sign - "$stage/$name/MacFanPro.app/Contents/Helpers/macfanpro"
codesign --force --deep --sign - "$stage/$name/MacFanPro.app"
codesign --verify --deep --strict "$stage/$name/MacFanPro.app"
COPYFILE_DISABLE=1 tar -czf "$output_dir/$name.tar.gz" -C "$stage" "$name"
# Keep SHA256SUMS archive-only: already deployed updaters check every entry.
cp "$stage/$name/MacFanPro.app/Contents/Resources/install.sh" "$output_dir/install.sh"
bash -n "$output_dir/install.sh"
(cd "$output_dir" && shasum -a 256 install.sh > install.sh.sha256)
(cd "$output_dir" && shasum -a 256 "$name.tar.gz" > SHA256SUMS)
printf 'Packaged %s\n' "$output_dir/$name.tar.gz"

# A second distribution format; the tar layout and its checksum remain compatible
# with installed versions of the online updater and the Homebrew formula.
mkdir "$stage/dmg"
cp -R "$stage/$name/MacFanPro.app" "$stage/dmg/"
ln -s /Applications "$stage/dmg/Applications"
cat > "$stage/dmg/Installation.txt" <<'GUIDE'
MacFanPro — macOS 14+ / Apple Silicon

1. Drag MacFanPro.app to Applications. Open it from Applications, not this disk.
2. If macOS blocks opening, verify the download source, then open System Settings
   > Privacy & Security > Open Anyway. This release is not notarized by Apple.
3. Click Install and enable. macOS requests administrator authorization to install
   the background service. No Terminal, Homebrew, Xcode or further download needed.

To update: quit MacFanPro, replace the app with a newer copy, and open it again.
The setup window appears if the background service needs synchronization.
Homebrew users should continue updating through Homebrew.
To uninstall: open Background service in the menu, remove the service, quit the app,
and move it to the Trash. Your settings and logs are preserved.

简体中文
1. 将 MacFanPro.app 拖入“应用程序”，然后从“应用程序”打开。
2. 若被 macOS 拦截，确认下载来源后，进入“系统设置 → 隐私与安全性 → 仍要打开”。
   当前版本尚未经过 Apple 公证。
3. 点击“安装并启用”，在 macOS 系统弹窗中授权。无需终端、Homebrew、Xcode 或再次下载。
更新：退出应用，拖入新版替换后重新打开，按提示同步后台服务。
Homebrew 用户继续通过 Homebrew 更新。
卸载：在菜单的“后台服务”中移除服务，退出后将应用移入废纸篓。配置和日志会保留。
GUIDE
hdiutil create -quiet -volname MacFanPro -srcfolder "$stage/dmg" -format UDZO -ov "$output_dir/$name.dmg"
hdiutil verify -quiet "$output_dir/$name.dmg"
(cd "$output_dir" && shasum -a 256 "$name.dmg" > "$name.dmg.sha256")
printf 'Packaged %s\n' "$output_dir/$name.dmg"
