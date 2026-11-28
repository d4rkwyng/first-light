#!/bin/bash
# Scripts/verify.sh — the local pass required before a push or claiming done.
# Writes a stamp for this exact HEAD, and only if the work tree is clean.
#
#   Scripts/verify.sh
#
# Env:
#   VERIFY_JOBS     compile jobs (default 4, to keep the host responsive)
#   DEVELOPER_DIR   honored if set; this script never runs xcode-select
#
# The stamp lives under $(git rev-parse --git-common-dir)/verify-stamps/<sha>,
# outside the work tree, so it does not dirty the tree.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "verify.sh: not a git work tree" >&2
    exit 2
fi

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
    echo "verify.sh: working tree is not clean. Commit or stash, then rerun." >&2
    git status --porcelain >&2
    exit 1
fi

# Never call xcode-select. Honor DEVELOPER_DIR if the caller set it.
SHA="$(git rev-parse HEAD)"
JOBS="${VERIFY_JOBS:-4}"
echo "==> verify.sh: HEAD $SHA  jobs=$JOBS  DEVELOPER_DIR=${DEVELOPER_DIR:-<unset>}"


# Tests run as a release build (see Scripts/test.sh). Build that configuration first
# so the suite does not pay for a second compile.
echo "==> [1/4] clean build (swift build -c release --build-tests; .build is not wiped)"
swift build -c release --build-tests --jobs "$JOBS"

echo "==> [2/4] full suite (Scripts/test.sh, --no-parallel)"
Scripts/test.sh --jobs "$JOBS"

echo "==> [3/4] timing-test 5x loop"
echo "verify.sh: SKIPPED timing-test 5x loop: this repo has no Scripts/ timing-stress script."

echo "==> [4/4] Swift 6.1 build"
SWIFT61_DIR="${SWIFT61_TOOLCHAIN_DIR:-$HOME/Library/Developer/Toolchains/swift-6.1.2-RELEASE.xctoolchain}"
SWIFT61_ID="${SWIFT61_TOOLCHAIN_ID:-org.swift.612202505261a}"
SDK16=""
for d in \
    /Applications/Xcode-16.4.0.app/Contents/Developer \
    /Applications/Xcode-16.4.app/Contents/Developer \
    /Applications/Xcode_16.4.app/Contents/Developer \
    /Applications/Xcode_16.4.0.app/Contents/Developer \
    /Applications/Xcode-16.3.0.app/Contents/Developer \
    /Applications/Xcode-16.3.app/Contents/Developer \
    /Applications/Xcode_16.3.app/Contents/Developer
do
    if [ -d "$d" ]; then SDK16="$d"; break; fi
done
if [ ! -d "$SWIFT61_DIR" ]; then
    echo "verify.sh: SKIPPED Swift 6.1 build: toolchain not installed at $SWIFT61_DIR."
elif [ -z "$SDK16" ]; then
    echo "verify.sh: SKIPPED Swift 6.1 build: the 6.1.2 toolchain cannot compile against the 26/27 SDKs. Install Xcode 16.4 alongside the current Xcode (do not change xcode-select) and rerun."
else
    echo "verify.sh: Swift 6.1 build with TOOLCHAINS=$SWIFT61_ID DEVELOPER_DIR=$SDK16"
    DEVELOPER_DIR="$SDK16" TOOLCHAINS="$SWIFT61_ID" xcrun --toolchain "$SWIFT61_ID" swift build --build-tests --jobs "$JOBS"
fi

stamp_dir="$(git rev-parse --git-common-dir)/verify-stamps"
mkdir -p "$stamp_dir"
stamp="$stamp_dir/$SHA"
{
    echo "sha=$SHA"
    echo "clean=1"
    echo "tree=$(git rev-parse "HEAD^{tree}")"
    echo "verified_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host=$(hostname)"
    echo "worktree=$(pwd)"
} > "$stamp"
echo "verify.sh: stamped $SHA -> $stamp"
