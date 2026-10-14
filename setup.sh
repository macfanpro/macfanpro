#!/bin/bash
# Build a complete app before replacing any running installation.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
if [ ! -f MacFanControl.icns ]; then
    swift Scripts/generate-icon.swift
    iconutil -c icns MacFanControl.iconset -o MacFanControl.icns
fi
"$bin_dir/macfancontrol" build-app --binary "$bin_dir/MacFanControlApp" \
    --icon MacFanControl.icns --dest "$bin_dir/MacFanControl.app" --source-dir "$PWD"
codesign --force --deep --sign - "$bin_dir/MacFanControl.app"
sudo "$bin_dir/macfancontrol" install "$@"
open /Applications/MacFanControl.app
