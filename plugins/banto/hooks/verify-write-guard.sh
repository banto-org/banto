#!/bin/sh
# verify-write-guard.sh — PreToolUse(Write|Edit) guard for the `plugin-audit verify` sandbox.
#
# While a verify run is active, a skill under verification must only write under the
# fixture base. This guard blocks any Write/Edit whose target is OUTSIDE that base, so a
# verified skill cannot pollute the real ai-context store or the repo. Deterministic
# enforcement (a hook), not a prose promise — same philosophy as egress-guard / kill-switch.
#
# Activation is opt-in via a marker file written by verify-sandbox.sh:
#   ${TMPDIR}/banto-verify-active  (line1 = allowed base abspath, line2 = epoch start)
#
# Fail-safe design (never breaks normal sessions):
#   - No marker → instant no-op (normal sessions: a single `test -f`).
#   - Stale marker (>1800s, e.g. a crashed verify run) → fail-open (no-op).
#   - Malformed marker / no jq / undeterminable target → fail-open.
set -u

MARKER="${TMPDIR:-/tmp}/banto-verify-active"
[ -f "$MARKER" ] || exit 0   # no active verify run → no-op (the hot path for normal sessions)

BASE=$(sed -n '1p' "$MARKER" 2>/dev/null)
START=$(sed -n '2p' "$MARKER" 2>/dev/null)
[ -n "$BASE" ] || exit 0
# staleness guard: malformed or >1800s old → fail-open
case "$START" in ''|*[!0-9]*) exit 0 ;; esac
NOW=$(date +%s 2>/dev/null) || exit 0
[ $((NOW - START)) -gt 1800 ] && exit 0

# extract the write target from the PreToolUse payload (stdin JSON)
command -v jq >/dev/null 2>&1 || exit 0
TARGET=$(cat 2>/dev/null | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$TARGET" ] || exit 0

# 連続スラッシュを畳んでから比較（base/target どちらに '//' が混入しても誤ブロックしない多重防御）。
BASE_N=$(printf '%s' "$BASE" | sed 's://*:/:g'); BASE_N="${BASE_N%/}"
TARGET=$(printf '%s' "$TARGET" | sed 's://*:/:g')
case "$TARGET" in
    "$BASE_N"|"$BASE_N"/*) exit 0 ;;   # inside the fixture base → allow
esac

printf '[verify sandbox] blocked: Write/Edit outside the fixture base.\n' >&2
printf '  target: %s\n  base:   %s\n' "$TARGET" "$BASE_N" >&2
printf 'A skill under `plugin-audit verify` may only write under the fixture base.\n' >&2
exit 2
