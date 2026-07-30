#!/bin/sh
# test-checkpoint-ws-stamp.sh — checkpoint-ws-stamp.sh（PostToolUse Write|Edit）の決定論刻印を検証する。
# marker の唯一の決定論 writer として、sessions/checkpoint-*.md に正準キー _ai_context_ws_key を
# 前置する。reader（ai-context-session-start.sh）の完全一致配送と同じ関数由来のキーなので一致が保たれる。
# no-op: checkpoint パスでない / 既に marker あり / ws キー未解決。
# 実 hook を合成 HOME + 合成 store root で通す（test-idle-checkpoint-delivery と同じ idiom）。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
STAMP="$DIR/hooks/checkpoint-ws-stamp.sh"
SS="$DIR/hooks/ai-context-session-start.sh"
PH="$DIR/scripts/_ai-context-paths.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }
[ -f "$STAMP" ] || { echo "SKIP: checkpoint-ws-stamp hook not found"; exit 0; }

unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_LOCAL_ROOT AI_CONTEXT_LOCAL_MAPPING BANTO_IGNORE_FILE
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ck-ws-stamp.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"; mkdir -p "$FAKE_HOME/.claude" "$TMP/tmp"
STORE="$TMP/store"
printf 'tester\n' > "$TMP/tmp/banto-ai-context-author-$(id -u 2>/dev/null || echo u)"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

paths() { HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" AI_CONTEXT_STORE_ROOT="$STORE" sh "$PH" "$@" 2>/dev/null; }
# 合成 payload で hook を起動（PostToolUse: tool_name / tool_input.file_path / cwd）
run_stamp() { # tool cwd file
    printf '%s' "{\"tool_name\":\"$1\",\"tool_input\":{\"file_path\":\"$3\"},\"cwd\":\"$2\"}" \
        | HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" AI_CONTEXT_STORE_ROOT="$STORE" CLAUDE_PLUGIN_ROOT="$DIR" sh "$STAMP" 2>/dev/null
}
marker_of() { head -1 "$1" 2>/dev/null; }

# --- リポジトリ用意 + base 登録（scaffold）+ ポインタ設定 ---
R="$TMP/myrepo"; mkdir -p "$R"
( cd "$R" && git init -q && git config user.name tester && git config user.email tester@example.com \
    && git commit -q --allow-empty -m init ) 2>/dev/null
printf '%s' "{\"cwd\":\"$R\",\"source\":\"startup\",\"session_id\":\"t\"}" \
    | HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" AI_CONTEXT_STORE_ROOT="$STORE" sh "$SS" >/dev/null 2>&1
BASE=$(paths --resolve "$R")
[ -n "$BASE" ] && [ -d "$BASE" ] || { echo "SKIP: base did not resolve ($BASE)"; exit 0; }
SESS="$BASE/sessions"; mkdir -p "$SESS"
printf '# Workspace: [test] alpha\n' > "$BASE/WORKSPACE.md"
[ "$(paths --ws-key "$R")" = "[test] alpha" ] || { echo "SKIP: ws-key did not resolve"; exit 0; }

# === 1: Write + 未マーカー + ポインタあり → 正準キーを刻印 ===
CK="$SESS/checkpoint-2026-07-24-1200-1.md"
printf '# Checkpoint - x\n\nbody\n' > "$CK"
run_stamp Write "$R" "$CK"
[ "$(marker_of "$CK")" = "<!-- banto-ws: [test] alpha -->" ] \
    && ok "1: stamps canonical marker when absent" \
    || bad "1: marker not stamped (got '$(marker_of "$CK")')"

# === 2: 既に marker あり → 触らない（冪等） ===
CK2="$SESS/checkpoint-2026-07-24-1200-2.md"
printf '<!-- banto-ws: [test] beta -->\n# Checkpoint - x\n' > "$CK2"
run_stamp Write "$R" "$CK2"
[ "$(marker_of "$CK2")" = "<!-- banto-ws: [test] beta -->" ] \
    && ok "2: existing marker left intact (idempotent)" \
    || bad "2: existing marker was altered"

# === 3: checkpoint でないパス → no-op ===
mkdir -p "$BASE/docs"; NC="$BASE/docs/note.md"; printf 'plain\n' > "$NC"
run_stamp Write "$R" "$NC"
[ "$(head -1 "$NC")" = "plain" ] && ok "3: non-checkpoint path untouched" || bad "3: non-checkpoint path modified"

# === 4: ポインタ未解決（WS_KEY 空）→ 刻印しない（未マーカーのまま = 後方互換配送） ===
mv "$BASE/WORKSPACE.md" "$BASE/WORKSPACE.md.bak"
CK4="$SESS/checkpoint-2026-07-24-1200-4.md"
printf '# Checkpoint - x\n' > "$CK4"
run_stamp Write "$R" "$CK4"
case "$(marker_of "$CK4")" in
    "<!-- banto-ws:"*) bad "4: stamped despite unresolved ws-key" ;;
    *)                 ok "4: no stamp when ws-key unresolved (left unmarked)" ;;
esac
mv "$BASE/WORKSPACE.md.bak" "$BASE/WORKSPACE.md"

# === 5: Edit tool_name でも刻印される ===
CK5="$SESS/checkpoint-2026-07-24-1200-5.md"
printf '# Checkpoint - x\n' > "$CK5"
run_stamp Edit "$R" "$CK5"
[ "$(marker_of "$CK5")" = "<!-- banto-ws: [test] alpha -->" ] \
    && ok "5: Edit tool path also stamped" \
    || bad "5: Edit tool path not stamped"

echo
[ "$fail" = "0" ] && { echo "ALL OK (test-checkpoint-ws-stamp)"; exit 0; } || { echo "FAILURES (test-checkpoint-ws-stamp)"; exit 1; }
