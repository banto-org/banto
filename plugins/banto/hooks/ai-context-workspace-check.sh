#!/bin/sh
# AI Context Workspace Check Hook (PostToolUse: Write|Edit)
# decisions/ または docs/ への書き込み時に WORKSPACE.md に未登録なら警告
# POSIX互換: macOS / Linux / WSL

command -v jq >/dev/null 2>&1 || exit 0

TEMP_INPUT=$(mktemp)
cat > "$TEMP_INPUT"

TOOL_NAME=$(jq -r '.tool_name // empty' "$TEMP_INPUT" 2>/dev/null)
FILE_PATH=$(jq -r '.tool_input.file_path // empty' "$TEMP_INPUT" 2>/dev/null)
CWD=$(jq -r '.cwd // empty' "$TEMP_INPUT" 2>/dev/null)

rm -f "$TEMP_INPUT"

[ -z "$FILE_PATH" ] && exit 0
[ -z "$CWD" ] && exit 0

# ai-context ベースdir を解決（central/legacy 透過・既定 legacy で挙動不変）
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi

case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# decisions/ or docs/ への書き込みのみ対象
# central mode では AI_BASE（<store>/<project>）配下の絶対パスに書くため、
# in-repo パターンに加えて AI_BASE 配下も gate に含める（prefix-check と同じ乖離の修正）
case "$FILE_PATH" in
    *"/.ai-context/decisions/"*|*"/.ai-context/docs/"*) ;;
    "$AI_BASE/decisions/"*|"$AI_BASE/docs/"*) ;;
    *) exit 0 ;;
esac

# WORKSPACE.md が存在しない場合はスキップ（per-checkout 実効ポインタを他 hook と同じ resolver で解決）
WS_FILE="$AI_BASE/WORKSPACE.md"
command -v _ai_context_ws_pointer >/dev/null 2>&1 && WS_FILE=$(_ai_context_ws_pointer "$AI_BASE" "$CWD")
[ ! -f "$WS_FILE" ] && exit 0

# multi モード判定（WORKSPACE-refs.md が存在すれば multi）
REFS_FILE="$AI_BASE/WORKSPACE-refs.md"
MULTI_MODE=0
[ -f "$REFS_FILE" ] && MULTI_MODE=1

# ファイルパスを相対パスに変換
REL_PATH=$(echo "$FILE_PATH" | sed "s|$AI_BASE/||")

# primary WORKSPACE.md / refs どちらかに既に登録されているか
if grep -qF "$REL_PATH" "$WS_FILE" 2>/dev/null; then
    exit 0
fi
if [ "$MULTI_MODE" = "1" ] && grep -qF "$REL_PATH" "$REFS_FILE" 2>/dev/null; then
    exit 0
fi

# ファイル名だけでも確認（パスの書き方が微妙に違う場合）
BASENAME=$(basename "$FILE_PATH")
if grep -qF "$BASENAME" "$WS_FILE" 2>/dev/null; then
    exit 0
fi
if [ "$MULTI_MODE" = "1" ] && grep -qF "$BASENAME" "$REFS_FILE" 2>/dev/null; then
    exit 0
fi

# i18n: 「## 関連ドキュメント」 below is the WORKSPACE.md section heading format —
#       consumed-by hooks/ai-context-auto.sh awk, skills/ws/SKILL.md (do not translate the token alone)
if [ "$MULTI_MODE" = "1" ]; then
    # primary 名を WORKSPACE.md の先頭行から抽出
    PRIMARY=$(grep -m1 '^# Workspace:' "$WS_FILE" 2>/dev/null | sed 's/^# Workspace:\s*//')
    [ -z "$PRIMARY" ] && PRIMARY="(primary)"

    # references の一覧を WORKSPACE-refs.md から抽出
    REFS=$(grep -E '^### \[' "$REFS_FILE" 2>/dev/null | sed 's/^### //' | head -5 | tr '\n' '/' | sed 's|/$||')
    [ -z "$REFS" ] && REFS="(references)"

    cat << WS_MULTI_MSG
[Workspace: multi mode] A new file is not registered in any workspace:
  File: $REL_PATH
  Primary:    $PRIMARY (write target)
  References: $REFS (read-only)

  Decision rules:
    - Normally append it to the 「## 関連ドキュメント」 (related documents) section of the primary WORKSPACE.md
    - If it belongs to a reference, confirm with the user, then edit the reference's original workspace file
    - To avoid cross-wiring, never write into WORKSPACE-refs.md itself
WS_MULTI_MSG
else
    cat << WS_CHECK_MSG
[Workspace] A new file is not registered in WORKSPACE.md:
  File: $REL_PATH
  Update WORKSPACE.md:
    - add: add it to the 「## 関連ドキュメント」 (related documents) section
    - replace: swap it with an existing entry
    - skip: unrelated to this workspace (do not add)
WS_CHECK_MSG
fi

exit 0
