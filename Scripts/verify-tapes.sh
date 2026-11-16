#!/bin/zsh
# T2: headless verification of the whole cassette library, through the
# app's own load path. Pass --verbose to dump every tape's transcript.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product FirstLight
# Run the binary this build just produced — never a hardcoded .build/debug
# path, which newer SwiftPM (Swift Build backend) no longer writes, so it
# can silently point at a stale binary from an older toolchain.
"$(swift build --product FirstLight --show-bin-path)/FirstLight" --verify-tapes "$@"
