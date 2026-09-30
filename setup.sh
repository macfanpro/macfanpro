#!/bin/bash
# Build a complete app before replacing any running installation.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
if [ ! -f MacFanPro.icns ]; then
    swift Scripts/generate-icon.swift
    iconutil -c icns MacFanPro.iconset -o MacFanPro.icns
fi
"$bin_dir/macfanpro" build-app --binary "$bin_dir/MacFanProApp" \
    --icon MacFanPro.icns --dest "$bin_dir/MacFanPro.app" --source-dir "$PWD"
codesign --force --deep --sign - "$bin_dir/MacFanPro.app"
sudo "$bin_dir/macfanpro" install "$@"
open /Applications/MacFanPro.app
