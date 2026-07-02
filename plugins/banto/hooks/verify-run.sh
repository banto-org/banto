#!/bin/sh
# verify-run.sh <dir> — full project verify: build -> full test -> API smoke, aggregated.
# Part of the build-and-verify loop (spec 2026-06-22_build-and-verify-loop). Self-driving
# implementation runs this before claiming done; verify-claim-guard.sh (Stop) enforces it.
#
#   exit 0 = all green (or nothing to verify) / 2 = something red.
#   - records the result to verify-last-<session> (read by verify-claim-guard)
#   - red bumps the shared test-failure counter (odd-gate circuit breaker); green resets it
#   - API smoke runs the project's package script with NODE_ENV=test + BANTO_VERIFY=1
#     (staging / read-only convention; never hits production — that is the smoke script's job)
#   - test seam: BANTO_VERIFY_CMDS_FILE overrides detection for hermetic unit tests
set -u

DIR=${1:-.}
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STATE_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"
# session 鍵: env 優先 → odd-gate が PreToolUse:Bash で残す cwd 単位ポインタ → manual。
# hook payload の session_id（odd-gate / auto-test の counter 鍵）と揃えるための配線
#（2026-07-02 監査: env が無く "manual" に落ち、circuit breaker に積算されない鍵ズレの修正）。
SESSION_ID=${BANTO_SESSION_ID:-${CLAUDE_SESSION_ID:-}}
if [ -z "$SESSION_ID" ]; then
    _cwd_abs=$(CDPATH= cd -- "$DIR" 2>/dev/null && pwd || printf '%s' "$DIR")
    _cwd_id=$(printf '%s' "$_cwd_abs" | cksum | awk '{print $1}')
    SESSION_ID=$(cat "$STATE_DIR/session-current-${_cwd_id}" 2>/dev/null)
fi
[ -n "$SESSION_ID" ] || SESSION_ID=manual
VERIFY_STATE="$STATE_DIR/verify-last-${SESSION_ID}"
TF_FILE="$STATE_DIR/test-failures-${SESSION_ID}"

# detect verify commands (or override via test seam)
if [ -n "${BANTO_VERIFY_CMDS_FILE:-}" ] && [ -f "${BANTO_VERIFY_CMDS_FILE}" ]; then
    CMDS=$(cat "$BANTO_VERIFY_CMDS_FILE")
else
    CMDS=$(sh "$SELF_DIR/verify-detect.sh" "$DIR" 2>/dev/null)
fi
_cmd() { printf '%s\n' "$CMDS" | grep "^$1=" | head -1 | cut -d= -f2-; }
BUILD_CMD=$(_cmd BUILD_CMD); TEST_CMD=$(_cmd TEST_CMD); API_SMOKE_CMD=$(_cmd API_SMOKE_CMD)

failed=""; ran=0
_step() { # <label> <cmd> <extra-env>
    [ -n "$2" ] || return 0
    ran=$((ran + 1))
    # shellcheck disable=SC2086
    OUT=$( cd "$DIR" 2>/dev/null && env $3 sh -c "$2" 2>&1 ); rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "[verify] $1: PASS" >&2
    else
        echo "[verify] $1: FAIL — $2" >&2
        printf '%s\n' "$OUT" | tail -8 >&2
        failed="$failed $1"
    fi
}
_step build     "$BUILD_CMD"     ""
_step test      "$TEST_CMD"      ""
_step api-smoke "$API_SMOKE_CMD" "NODE_ENV=test BANTO_VERIFY=1"

mkdir -p "$STATE_DIR" 2>/dev/null
if [ "$ran" -eq 0 ]; then
    printf 'green (no verify commands detected)\n' > "$VERIFY_STATE" 2>/dev/null
    echo "[verify] no build/test/api commands detected — nothing to verify" >&2
    exit 0
fi
if [ -n "$failed" ]; then
    printf 'red:%s\n' "$failed" > "$VERIFY_STATE" 2>/dev/null
    _n=$(cat "$TF_FILE" 2>/dev/null); case "$_n" in ''|*[!0-9]*) _n=0;; esac
    printf '%s' "$((_n + 1))" > "$TF_FILE" 2>/dev/null
    echo "[verify] RED — failed:$failed" >&2
    exit 2
fi
printf 'green\n' > "$VERIFY_STATE" 2>/dev/null
printf '0' > "$TF_FILE" 2>/dev/null
echo "[verify] GREEN — $ran step(s) passed" >&2
exit 0
