#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Socket integration tests use blocking clients. Run test cases serially so they
# cannot exhaust the Swift Testing worker pool on small CI runners. Each socket
# test still exercises concurrent server connections with its original deadlines.
swift test --no-parallel "$@"
bash Scripts/test-disconnected-clients.sh

python3 Scripts/test-installer.py
