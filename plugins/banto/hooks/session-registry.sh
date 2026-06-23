#!/bin/sh
# session-registry.sh — 並走セッションを store に登録し「艦隊」を可視化する（Fleet 指揮層）。
#
# CONCEPT 中核「1 人指揮 + N AI セッション」を実体化する。中央 store は知識を共有するが
# 作業（誰がどの branch/worktree で動いているか）は共有していなかった。それを registry で埋める。
#   spec: docs/specs/2026-06-10_harness-next-level（P4 core）
#
# SessionStart: <base>/sessions/registry/<session_id>.json を active で書く + 衝突検知。
# SessionEnd:   status=ended に更新（削除でなく履歴・dashboard が間引く）。
#
# stdout は出さない（SessionStart hook の stdout は context 注入されるため）。衝突は
# pending-channel collision に集約し、後続の ai-context-session-start.sh が注入する。
# fail-open: jq 不在 / base 解決失敗 → silent exit 0。

set -u

command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

PAYLOAD=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(printf "%s" "$PAYLOAD" | jq -r '.session_id // empty')
[ -z "$SESSION_ID" ] && exit 0
EVENT=$(printf "%s" "$PAYLOAD" | jq -r '.hook_event_name // empty')
CWD=$(printf "%s" "$PAYLOAD" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="$PWD"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
[ -f "$PATHS" ] || exit 0
. "$PATHS"
BASE=$(_ai_context_base_dir "$CWD")
[ -d "$BASE" ] || exit 0

REG_DIR="$BASE/sessions/registry"
mkdir -p "$REG_DIR" 2>/dev/null || exit 0
REG_FILE="$REG_DIR/${SESSION_ID}.json"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)

BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
WORKTREE=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
AUTHOR=$(_ai_context_author "$CWD" 2>/dev/null)
WS=""
_wsptr=$(_ai_context_ws_pointer "$BASE" "$CWD" 2>/dev/null)
[ -n "$_wsptr" ] && [ -f "$_wsptr" ] && WS=$(grep -m1 '^# Workspace:' "$_wsptr" 2>/dev/null | sed 's/^# Workspace:[[:space:]]*//')

case "$EVENT" in
    SessionEnd)
        # 既存 registry を ended に更新（無ければ何もしない）
        if [ -f "$REG_FILE" ]; then
            TMP="$REG_FILE.tmp.$$"
            jq --arg ts "$TS" '.status="ended" | .last_seen=$ts' "$REG_FILE" > "$TMP" 2>/dev/null \
                && mv "$TMP" "$REG_FILE" 2>/dev/null || rm -f "$TMP"
        fi
        exit 0
        ;;
    *)
        # SessionStart（startup/resume/clear/compact）: active で記録
        jq -c -n --arg sid "$SESSION_ID" --arg author "$AUTHOR" --arg ws "$WS" \
            --arg branch "$BRANCH" --arg wt "$WORKTREE" --arg cwd "$CWD" --arg ts "$TS" \
            '{session_id:$sid, author:$author, ws:$ws, branch:$branch, worktree:$wt, cwd:$cwd, started:$ts, last_seen:$ts, status:"active"}' \
            > "$REG_FILE" 2>/dev/null
        ;;
esac

# --- 古い registry を間引く（>7 日は削除）---
find "$REG_DIR" -maxdepth 1 -name '*.json' -mtime +7 -delete 2>/dev/null

# --- 衝突検知: 同 branch or 同 worktree の別 active session（last_seen が 12h 以内）---
# heartbeat が無いため、crash した stale active を誤検知しないよう時間窓で絞る。
CUTOFF=$(date -u -v-12H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -d "12 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "0000")

COLLIDE=""
for f in "$REG_DIR"/*.json; do
    [ -f "$f" ] || continue
    case "$f" in */"${SESSION_ID}.json") continue ;; esac  # 自分は除外
    other=$(cat "$f" 2>/dev/null)
    [ -z "$other" ] && continue
    o_status=$(printf "%s" "$other" | jq -r '.status // empty')
    o_seen=$(printf "%s" "$other" | jq -r '.last_seen // empty')
    [ "$o_status" = "active" ] || continue
    [ -n "$o_seen" ] && [ "$o_seen" \< "$CUTOFF" ] && continue   # 時間窓外 = stale
    o_branch=$(printf "%s" "$other" | jq -r '.branch // empty')
    o_wt=$(printf "%s" "$other" | jq -r '.worktree // empty')
    o_author=$(printf "%s" "$other" | jq -r '.author // empty')
    o_ws=$(printf "%s" "$other" | jq -r '.ws // empty')
    _hit=""
    [ -n "$BRANCH" ] && [ "$o_branch" = "$BRANCH" ] && _hit="same branch '$BRANCH'"
    [ -n "$WORKTREE" ] && [ "$o_wt" = "$WORKTREE" ] && _hit="same worktree"
    if [ -n "$_hit" ]; then
        COLLIDE="${COLLIDE}- Another session is active on the ${_hit} (author=${o_author:-?}${o_ws:+ / ws=$o_ws}). Double-editing the same branch causes state splits (decision 2026-05-29_005).
"
    fi
done

# pending-channel collision を毎回再評価（衝突あり→記載 / 無し→クリア）
PENDING="$PLUGIN_ROOT/hooks/pending-channel.sh"
if [ -f "$PENDING" ]; then
    if [ -n "$COLLIDE" ]; then
        printf '## 🛰 Session collision (%s)\n%s' "$(date +%Y-%m-%d 2>/dev/null)" "$COLLIDE" \
            | sh "$PENDING" collision "$CWD" 2>/dev/null
    else
        printf '' | sh "$PENDING" collision "$CWD" 2>/dev/null
    fi
fi

exit 0
