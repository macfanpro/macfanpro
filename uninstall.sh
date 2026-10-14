#!/bin/bash
set -euo pipefail
# The old path also supports uninstalling installations from before the rename.
cli=/usr/local/bin/macfancontrol
if [ ! -x "$cli" ]; then cli=/usr/local/bin/macfanpro; fi
sudo "$cli" uninstall "$@"
if command -v brew >/dev/null && brew list --formula macfancontrol >/dev/null 2>&1; then
    brew uninstall macfancontrol
elif command -v brew >/dev/null && brew list --formula macfanpro >/dev/null 2>&1; then
    brew uninstall macfanpro
fi
