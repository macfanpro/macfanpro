#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Socket integration tests use blocking clients. Run test cases serially so they
# cannot exhaust the Swift Testing worker pool on small CI runners. Each socket
# test still exercises concurrent server connections with its original deadlines.
if [[ "${1:-}" == "--all-configurations" ]]; then
    shift
    for argument in "$@"; do
        case "$argument" in
            -c|--configuration|-c?*|--configuration=*)
                echo "--all-configurations cannot be combined with -c/--configuration" >&2
                exit 2
                ;;
        esac
    done
    swift test --no-parallel -c debug "$@"
    swift test --no-parallel -c release "$@"
else
    swift test --no-parallel "$@"
fi

# These checks use their own fixtures, independent of the Swift build configuration.
# Run them once even when both Debug and Release are requested.
bash Scripts/test-disconnected-clients.sh

python3 Scripts/test-installer.py
