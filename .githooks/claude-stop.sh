#!/bin/bash
# Claude Code Stop hook: block claiming "done" unless Scripts/verify.sh has
# stamped this exact HEAD on a clean tree. Wired from .claude/settings.json.
# Exit 2 blocks the stop and sends stderr back to Claude. Exit 0 allows it.
# If this is not a git work tree, do nothing (don't brick other sessions).
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root"

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
    echo "Working tree is not clean. Commit or stash, then run Scripts/verify.sh before claiming done." >&2
    exit 2
fi

sha="$(git rev-parse HEAD)"
stamp="$(git rev-parse --git-common-dir)/verify-stamps/$sha"
if [ ! -f "$stamp" ] || ! grep -q "^sha=$sha$" "$stamp"; then
    echo "No verify stamp for $sha. Run Scripts/verify.sh, then you may claim done." >&2
    exit 2
fi
exit 0
