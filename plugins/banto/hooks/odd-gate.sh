#!/bin/sh
# odd-gate.sh — test-failure circuit breaker (PreToolUse: Write|Edit)
#
# When the project's own unit tests (run by auto-test.sh after each source edit)
# fail N times in a row, this blocks further edits and tells the model to find the
# root cause with a debugger agent instead of churning. It is a deterministic safety
# valve for self-driving implementation loops, and fires regardless of which skill
# (if any) is active — runaway edit→test-fail loops happen in the main loop where no
# skill is active, so the check reads a session-global counter, not per-skill state.
#
# Counter:   $ODD_STATE_DIR/test-failures-<session> (written by auto-test.sh; reset to 0 on a passing test)
# Threshold: ODD_TEST_FAILURE_THRESHOLD (default 3)
# Escape:    ODD_ALLOW_TEST_FAILURES=1 (state a reason when using it)
#
# jq required; absent → silent exit 0 (fail-open).

set -u

command -v jq >/dev/null 2>&1 || exit 0
[ "${ODD_ALLOW_TEST_FAILURES:-0}" = "1" ] && exit 0

PAYLOAD=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(printf "%s" "$PAYLOAD" | jq -r '.session_id // empty')
[ -z "$SESSION_ID" ] && exit 0

STATE_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"
TF_FILE="$STATE_DIR/test-failures-${SESSION_ID}"
[ -f "$TF_FILE" ] || exit 0

TF_CUR=$(cat "$TF_FILE" 2>/dev/null)
case "$TF_CUR" in ''|*[!0-9]*) exit 0 ;; esac

THRESH="${ODD_TEST_FAILURE_THRESHOLD:-3}"
case "$THRESH" in ''|*[!0-9]*) THRESH=3 ;; esac

if [ "$TF_CUR" -ge "$THRESH" ]; then
    printf "[ODD gate] Tests have failed %s times in a row (threshold %s). Blocking further edits.\n" "$TF_CUR" "$THRESH" >&2
    printf "  Stop churning — find the root cause with a debugger agent (read-only: it returns a fix proposal, you apply it).\n" >&2
    printf "  Escape (state a reason): ODD_ALLOW_TEST_FAILURES=1\n" >&2
    exit 2
fi

exit 0
