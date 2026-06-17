#!/bin/zsh
# Runs the test suite. With full Xcode installed, plain `swift test` works;
# with only the Command Line Tools, the Swift Testing framework lives in a
# non-default location and needs explicit search/runtime paths.
set -euo pipefail
cd "$(dirname "$0")/.."

# Default to a release build: emulation tests run many cycles.

if [[ " $* " != *" -c "* && " $* " != *" --configuration "* ]]; then
    set -- -c release "$@"
fi

# --no-parallel: the emulator keeps its 6502 state in fake6502 C globals
# (Apple1.current owns the CPU), so only one Apple1 can run at a time. Without
# this, the Apple1Core and FirstLight test suites run in parallel and clobber
# each other's CPU state (a flaky "60 cps governor" failure was the tell).
if xcode-select -p 2>/dev/null | grep -q "CommandLineTools"; then
    FWK=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
    LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
    exec swift test --no-parallel \
        -Xswiftc -F"$FWK" \
        -Xlinker -F"$FWK" \
        -Xlinker -rpath -Xlinker "$FWK" \
        -Xlinker -rpath -Xlinker "$LIB" \
        "$@"
else
    exec swift test --no-parallel "$@"
fi
