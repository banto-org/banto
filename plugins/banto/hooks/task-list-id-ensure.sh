#!/bin/sh
# task-list-id-ensure.sh — SessionStart: 永続タスクリストを per-project で自動 ensure する
#
# 背景: Claude Code 組み込みのタスクリスト（TaskCreate/TaskList）は session スコープで、
#   resume/clear で失われる。env var CLAUDE_CODE_TASK_LIST_ID を設定すると disk-backed
#   （~/.claude/tasks/<id>/）になり、resume/clear/restart をまたいで残る。これを「ユーザー
#   が覚えておく」摩擦なしに per-project で勝手に効かせる。
#
# 方針:
#   - id は git toplevel の basename を sanitize した安定値（ai-context store の derive 名と同趣旨）。
#   - 書き込み先は personal で gitignore 済みの <toplevel>/.claude/settings.local.json
#     （committed の settings.json には触れない。teammate 間でも衝突しない）。
#   - 既存キーは jq merge で保持し、temp file + mv の atomic 書き込み（partial write しない）。
#   - .gitignore に .claude/settings.local.json 行が無ければ追記（personal file の commit 防止）。
#   - fail-open: jq 不在 / 非 git / toplevel が $HOME or / → no-op exit 0（他 hook と同じ哲学）。
#
# harness-setup.sh の --project からも sh で直接呼べるよう self-contained にしてある。

# --- cwd を SessionStart payload から取る（無ければ $PWD）。jq 不在は fail-open no-op ---
if command -v jq >/dev/null 2>&1; then
    INPUT=$(cat 2>/dev/null)
    CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
else
    # jq 不在 → settings.local.json の安全な merge 書き込みができないため no-op（fail-open）
    exit 0
fi
[ -z "$CWD" ] && CWD="$PWD"

# --- git toplevel 解決。非 git / toplevel が $HOME or / → no-op（fail-open）---
TOP=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
[ -z "$TOP" ] && exit 0
[ "$TOP" = "$HOME" ] && exit 0
[ "$TOP" = "/" ] && exit 0

# --- 安定 id: toplevel basename を sanitize（lowercase / 非英数の連続→単一 - / 端の - を除去）---
ID=$(basename "$TOP" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')
[ -z "$ID" ] && exit 0

SETTINGS="$TOP/.claude/settings.local.json"

# --- 冪等: 既に non-empty な値が入っていれば silent no-op ---
if [ -f "$SETTINGS" ]; then
    CUR=$(jq -r '.env.CLAUDE_CODE_TASK_LIST_ID // empty' "$SETTINGS" 2>/dev/null)
    [ -n "$CUR" ] && exit 0
fi

# --- merge-write（既存キー保持・atomic） ---
mkdir -p "$TOP/.claude" 2>/dev/null
TMP=$(mktemp "${TMPDIR:-/tmp}/banto-tli.XXXXXX" 2>/dev/null) || exit 0
if [ -f "$SETTINGS" ]; then
    jq --arg id "$ID" '.env.CLAUDE_CODE_TASK_LIST_ID = $id' "$SETTINGS" > "$TMP" 2>/dev/null \
        && mv "$TMP" "$SETTINGS" || { rm -f "$TMP"; exit 0; }
else
    jq -n --arg id "$ID" '{env: {CLAUDE_CODE_TASK_LIST_ID: $id}}' > "$TMP" 2>/dev/null \
        && mv "$TMP" "$SETTINGS" || { rm -f "$TMP"; exit 0; }
fi

# --- .gitignore に .claude/settings.local.json 行を保証（無ければ追記・無ければ作成）---
GI="$TOP/.gitignore"
if [ -f "$GI" ]; then
    grep -qxF '.claude/settings.local.json' "$GI" 2>/dev/null \
        || printf '%s\n' '.claude/settings.local.json' >> "$GI"
else
    printf '%s\n' '.claude/settings.local.json' > "$GI"
fi

# --- 通知（冪等のため自然に 1 回だけ出る）---
echo "[banto] Persistent task list enabled (CLAUDE_CODE_TASK_LIST_ID=$ID) in .claude/settings.local.json — restart Claude Code to activate; tasks now survive resume/clear/compact."
exit 0
