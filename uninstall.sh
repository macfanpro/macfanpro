#!/bin/bash
set -euo pipefail
sudo /usr/local/bin/macfanpro uninstall "$@"
if command -v brew >/dev/null && brew list --formula macfanpro >/dev/null 2>&1; then
    brew uninstall macfanpro
fi
