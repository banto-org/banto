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
PROJECT_ID="$ID"

# --- WS スコープ: 現在の workspace が解決できれば <project>--<ws-slug> へ ---
# タスクリストを workspace 単位で分離する（store の tasks.md が WS 単位なのと同じ粒度）。
# WS ポインタが無い repo は従来どおり project 単位。タスクストアの解決は動的で、書き込み後の
# 次のツール呼び出しから新リストが使われる（実測）。切替時、旧リストの項目は旧 id 側に残る。
PATHS_LIB=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/scripts/_ai-context-paths.sh
if [ -f "$PATHS_LIB" ]; then
    # shellcheck disable=SC1090
    . "$PATHS_LIB" 2>/dev/null || true
    if command -v _ai_context_base_dir >/dev/null 2>&1 && command -v _ai_context_ws_key >/dev/null 2>&1; then
        _tli_base=$(_ai_context_base_dir "$CWD" 2>/dev/null || true)
        _tli_wskey=""
        [ -n "$_tli_base" ] && _tli_wskey=$(_ai_context_ws_key "$_tli_base" "$CWD" 2>/dev/null || true)
        if [ -n "$_tli_wskey" ]; then
            _tli_wslug=$(printf '%s' "$_tli_wskey" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')
            [ -n "$_tli_wslug" ] && ID="${PROJECT_ID}--${_tli_wslug}"
        fi
    fi
fi

SETTINGS="$TOP/.claude/settings.local.json"

# --- 冪等 + WS 追従: 望む id と一致なら no-op。banto 導出値（project または project--*）は
#     WS 切替に追従して更新する。それ以外（ユーザー独自の id）は保護して触らない ---
if [ -f "$SETTINGS" ]; then
    CUR=$(jq -r '.env.CLAUDE_CODE_TASK_LIST_ID // empty' "$SETTINGS" 2>/dev/null)
    [ "$CUR" = "$ID" ] && exit 0
    case "$CUR" in
        ""|"$PROJECT_ID"|"$PROJECT_ID"--*) : ;;
        *) exit 0 ;;
    esac
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
