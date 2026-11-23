#!/bin/zsh
# Launch smoke test for a packaged First Light.app.
# Usage: Scripts/smoke-launch.sh <path/to/First Light.app> [seconds]
#
# Checks that the bundle carries its SwiftPM resource bundles in
# Contents/Resources, then starts the app's executable, waits (default 6 s),
# and fails if the process exited on its own. If the launch survived, runs
# `"First Light" --resource-check` (loads one known file from each resource
# bundle through the app's locator, never Bundle.module; prints one line per
# bundle with the resolved path) and requires exit 0 within 15 s. Fails if a
# new "First Light*.ips" crash report appeared in
# ~/Library/Logs/DiagnosticReports during either run. Exit 0 = pass.
#
# Order: the plain launch runs first, so an app that crashes at launch (1.0.0,
# 1.0.1, or any build older than --resource-check, which would just ignore
# the flag) fails with "exited within 6s" before the resource check runs.
# Both runs happen with the build-time bundle paths hidden (below).
#
# Not covered (known follow-up): a crash AFTER the 6 s window. The board art,
# tapes, gallery and BASIC/ACI ROMs load lazily on user action through the
# same static bundle accessors, so a bundle that resolved at launch but lacks
# a later file would only fail then. --resource-check samples one file per
# bundle, not every file.
#
# Why the build-time bundles are hidden while the app runs:
#   SwiftPM's generated Bundle.module accessor (the native build system,
#   which the macos-15 CI runner's Xcode uses) falls back to the ABSOLUTE
#   build-time path of each resource bundle (…/.build/<triple>/release/
#   first-light_<Target>.bundle), and that path is compiled into the binary.
#   On the machine (or CI runner) that built the app, that directory still
#   exists, so a broken app — one that cannot find its bundles inside the
#   .app — launches fine there and crashes on every other Mac. That is how
#   1.0.0 and 1.0.1 shipped. So before launching, this script reads every
#   absolute path embedded in the executable whose last component is
#   first-light_Apple1Core.bundle or first-light_FirstLight.bundle (no other
#   .bundle path is touched) and renames each one that exists to
#   "<path>.smoke-hidden" for the duration of the launch (the same effect as
#   moving .build aside, but it also covers a custom --scratch-path and leaves
#   the rest of .build alone). A trap renames them back on exit, Ctrl-C or
#   failure, trying every entry; if any rename back fails the script says so
#   loudly and exits non-zero even if the launch passed. Only a SIGKILL of
#   this script could leave one renamed silently; the next run refuses to
#   start and says what to `mv` back. Do not run this while a build is
#   writing that .build directory.
set -euo pipefail

APP="${1:-}"
WAIT="${2:-6}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
    echo "usage: $0 <path/to/First Light.app> [seconds]" >&2
    exit 2
fi
APP="${APP:A}"   # absolute, symlinks resolved
EXE="$APP/Contents/MacOS/First Light"
RES="$APP/Contents/Resources"

fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }

# 1. Layout: the resource bundles live in Contents/Resources (never at the
#    .app root — codesign/notarization reject unsealed root content).
[[ -x "$EXE" ]] || fail "no executable at $EXE"
# SwiftPM's native build system makes flat bundles (<b>.bundle/ROMs/…);
# swiftbuild (Swift 6.4+) makes macOS-style ones (<b>.bundle/Contents/Resources/ROMs/…).
CORE="$RES/first-light_Apple1Core.bundle"
[[ -f "$CORE/ROMs/wozmon.bin" || -f "$CORE/Contents/Resources/ROMs/wozmon.bin" ]] \
    || fail "missing wozmon.bin in $CORE (looked in ROMs/ and Contents/Resources/ROMs/)"
[[ -d "$RES/first-light_FirstLight.bundle" ]] \
    || fail "missing $RES/first-light_FirstLight.bundle"
for b in first-light_Apple1Core.bundle first-light_FirstLight.bundle; do
    [[ ! -e "$APP/$b" ]] || fail "$b is at the .app root (codesign rejects unsealed root content)"
done
echo "layout ok: resource bundles in Contents/Resources"

# 2. Hide every build-time bundle path the binary could fall back to.
typeset -a FALLBACKS HIDDEN
# One path per line (paths may contain spaces); only our two bundle names.
FALLBACKS=(${(u)${(f)"$(strings -a "$EXE" \
    | grep -E '^/.+/first-light_(Apple1Core|FirstLight)\.bundle$' || true)"}})
RESTORE_FAILED=0
# Rename every hidden path back. Tries every entry; entries that could not be
# restored stay in HIDDEN (so a later call retries them) and set
# RESTORE_FAILED, which makes the script exit non-zero.
restore() {
    local d
    local -a stuck=()
    for d in "${HIDDEN[@]}"; do
        if [[ ! -e "$d.smoke-hidden" && -e "$d" ]]; then
            continue   # already back
        fi
        if [[ -e "$d.smoke-hidden" && ! -e "$d" ]] && mv "$d.smoke-hidden" "$d"; then
            echo "restored $d"
        else
            stuck+=("$d")
            RESTORE_FAILED=1
            echo "SMOKE ERROR: could not restore $d — fix by hand: mv '$d.smoke-hidden' '$d'" >&2
        fi
    done
    HIDDEN=("${stuck[@]}")
}
cleanup() {
    [[ -n "${PID:-}" ]] && kill -9 "$PID" 2>/dev/null || true
    [[ -n "${RCPID:-}" ]] && kill -9 "$RCPID" 2>/dev/null || true
    restore
    [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
    if (( RESTORE_FAILED )); then
        echo "SMOKE ERROR: build-time bundle path(s) left renamed (see above); exiting non-zero" >&2
        exit 1
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

if (( ${#FALLBACKS[@]} == 0 )) || [[ -z "${FALLBACKS[1]}" ]]; then
    FALLBACKS=()
    echo "no absolute bundle paths embedded in the binary (nothing to hide)"
fi
for d in "${FALLBACKS[@]}"; do
    if [[ -e "$d.smoke-hidden" ]]; then
        fail "$d.smoke-hidden exists (an interrupted earlier smoke run?). Restore it: mv '$d.smoke-hidden' '$d'"
    fi
    if [[ -e "$d" ]]; then
        mv "$d" "$d.smoke-hidden"
        HIDDEN+=("$d")
        echo "hid build-path fallback $d (restored on exit)"
    else
        echo "build-path fallback $d is absent (nothing to hide)"
    fi
done
# Belt and braces: no embedded bundle path may resolve during the launch.
for d in "${FALLBACKS[@]}"; do
    [[ ! -e "$d" ]] || fail "build-time bundle path still exists during smoke: $d"
done

# 3. Launch and watch.
REPORTS="$HOME/Library/Logs/DiagnosticReports"
TMP=$(mktemp -d /tmp/fl-smoke.XXXXXX)
MARK="$TMP/mark"
: > "$MARK"
sleep 1   # mtime granularity: reports from before this point stay older than MARK
"$EXE" >"$TMP/stdout" 2>"$TMP/stderr" &
PID=$!
echo "launched pid $PID; watching for ${WAIT}s"

exited=0
for (( i = 0; i < WAIT * 4; i++ )); do
    if ! kill -0 "$PID" 2>/dev/null; then exited=1; break; fi
    sleep 0.25
done

rc=0
if (( exited )); then
    wait "$PID" || rc=$?
    PID=
    sleep 3   # give ReportCrash time to write the .ips
else
    kill "$PID" 2>/dev/null || true
    for (( i = 0; i < 20; i++ )); do kill -0 "$PID" 2>/dev/null || break; sleep 0.25; done
    kill -9 "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    PID=
fi
# 4. Resource check (only if the launch survived), still with paths hidden.
RCWAIT=15
rc_rc=-1
rc_timed_out=0
if (( ! exited )); then
    "$EXE" --resource-check >"$TMP/rc-stdout" 2>"$TMP/rc-stderr" &
    RCPID=$!
    for (( i = 0; i < RCWAIT * 4; i++ )); do
        kill -0 "$RCPID" 2>/dev/null || break
        sleep 0.25
    done
    if kill -0 "$RCPID" 2>/dev/null; then
        rc_timed_out=1
        kill -9 "$RCPID" 2>/dev/null || true
        wait "$RCPID" 2>/dev/null || true
    else
        rc_rc=0
        wait "$RCPID" || rc_rc=$?
    fi
    RCPID=
    (( rc_rc == 0 )) || sleep 3   # let ReportCrash write any .ips
fi

NHIDDEN=${#HIDDEN[@]}
restore
(( ! RESTORE_FAILED )) || fail "could not restore every hidden build-time bundle path (see above)"

crash=$(find "$REPORTS" -maxdepth 1 -name 'First Light*.ips' -newer "$MARK" 2>/dev/null || true)

if (( exited )); then
    echo "--- stderr ---" >&2; cat "$TMP/stderr" >&2
    echo "--- stdout ---" >&2; cat "$TMP/stdout" >&2
    [[ -n "$crash" ]] && echo "crash report(s): $crash" >&2
    fail "First Light exited within ${WAIT}s (exit code $rc)"
fi
echo "launch ok: First Light ran ${WAIT}s"
cat "$TMP/rc-stdout"
if (( rc_timed_out )); then
    fail "--resource-check did not exit within ${RCWAIT}s (a build without the flag starts the UI instead)"
fi
if (( rc_rc != 0 )); then
    echo "--- resource-check stderr ---" >&2; cat "$TMP/rc-stderr" >&2
    [[ -n "$crash" ]] && echo "crash report(s): $crash" >&2
    fail "--resource-check exited with code $rc_rc"
fi
(( $(grep -c '^resource-check PASS ' "$TMP/rc-stdout") == 2 )) \
    || fail "--resource-check exited 0 but did not print two PASS lines"
if [[ -n "$crash" ]]; then
    echo "--- stderr ---" >&2; cat "$TMP/stderr" >&2
    fail "new crash report(s) during the smoke window: $crash"
fi
echo "SMOKE PASS: First Light ran ${WAIT}s and --resource-check passed (${NHIDDEN} build-time bundle path(s) hidden, ${#FALLBACKS[@]} embedded); no crash report"
