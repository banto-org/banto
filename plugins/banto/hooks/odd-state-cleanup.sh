#!/bin/sh
# odd-state-cleanup.sh — removes per-session ODD state files at SessionEnd
#
# Related: hooks/odd-active-tracker.sh (writes active-*.json), auto-test.sh (writes test-failures-*)
#
# Behavior:
#   1. read session_id from the SessionEnd payload
#   2. delete this session's state files (active-*.json / agents-* / test-failures-*)
#   3. also delete state files older than 30 days (orphan sweep)

set -u

PAYLOAD=$(cat 2>/dev/null || echo '{}')

# session_id 抽出（jq があれば使う、無ければ grep フォールバック）
if command -v jq >/dev/null 2>&1; then
    SESSION_ID=$(printf "%s" "$PAYLOAD" | jq -r '.session_id // empty')
else
    SESSION_ID=$(printf "%s" "$PAYLOAD" | grep -oE '"session_id":[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"session_id":[[:space:]]*"([^"]*)".*/\1/')
fi

STATE_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"

# 当 session の state file を削除（active skill + 並列カウンタ + 連続失敗カウンタ。P3）
if [ -n "$SESSION_ID" ]; then
    rm -f "$STATE_DIR/active-${SESSION_ID}.json" \
          "$STATE_DIR/agents-${SESSION_ID}" \
          "$STATE_DIR/test-failures-${SESSION_ID}" 2>/dev/null
fi

# also sweep state files older than 30 days (orphan protection)
find "$STATE_DIR" -maxdepth 1 \( -name 'active-*.json' -o -name 'agents-*' -o -name 'test-failures-*' \) -mtime +30 -delete 2>/dev/null

exit 0
