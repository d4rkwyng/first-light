#!/bin/zsh
# T2: headless verification of the whole cassette library.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product FirstLight 2>/dev/null | tail -1 || swift build --product FirstLight
.build/debug/FirstLight --verify-tapes
