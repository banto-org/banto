#!/bin/sh
# AI Context Combined Rebuild Hook (PostToolUse: Write|Edit)
# .ai-context/decisions/ または .ai-context/docs/ への書き込みを検知して
# combined.txt（検索用の単一テキスト）をバックグラウンドで再生成する。
#
# 旧 ai-context-index-rebuild.sh の後継（search-native-migration spec T1-3）:
# SoftMatcha index 構築（uv + MCP venv + モデルロード ~6-8s/2.2GB）を廃し、
# python3 stdlib の純テキスト連結（~50ms・メモリスパイクなし）に置換。
# POSIX互換: macOS / Linux / WSL
#
# 重要: printf '%s' "$INPUT" | jq は JSON 内の $() 等がシェル展開されて壊れるため、
# 一時ファイル経由で jq に渡す

command -v jq >/dev/null 2>&1 || exit 0

# stdin を一時ファイルに保存（シェル展開を回避）
TEMP_INPUT=$(mktemp)
cat > "$TEMP_INPUT"

TOOL_NAME=$(jq -r '.tool_name // empty' "$TEMP_INPUT" 2>/dev/null)
FILE_PATH=$(jq -r '.tool_input.file_path // empty' "$TEMP_INPUT" 2>/dev/null)
CWD=$(jq -r '.cwd // empty' "$TEMP_INPUT" 2>/dev/null)

rm -f "$TEMP_INPUT"

[ -z "$FILE_PATH" ] && exit 0
[ -z "$CWD" ] && exit 0

case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# ai-context ベースを解決（central/legacy 透過）。central では store path に
# /.ai-context/ が含まれないため、固定パターンではなく解決済みベースで判定する。
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi

case "$FILE_PATH" in
    "$AI_BASE/decisions/"*|"$AI_BASE/docs/"*) ;;
    *) exit 0 ;;
esac

# silent failure 防止: python3 が無い時は stderr に 1 行出して可視化
if ! command -v python3 >/dev/null 2>&1; then
    printf '[AI Context] combined rebuild skipped: python3 is not installed. Search results may go stale.\n' >&2
    exit 0
fi
COMBINED_PY="$PATHS_DIR/ai_context_combined.py"
if [ ! -f "$COMBINED_PY" ]; then
    printf '[AI Context] combined rebuild skipped: ai_context_combined.py not found (CLAUDE_PLUGIN_ROOT=%s).\n' "${CLAUDE_PLUGIN_ROOT:-unset}" >&2
    exit 0
fi

# lock はプロジェクト単位（複数プロジェクト並走時の取りこぼし防止。2026-06-05 監査 TEST 7）
_proj_id=$(printf '%s' "$CWD" | cksum | awk '{print $1}')
LOCK="${TMPDIR:-/tmp}/ai-context-combined-rebuild-${_proj_id}.lock"

# 前回のバックグラウンド再生成が失敗していたら可視化する（context-keeper agent への実導線。
# バックグラウンド実行のため同一実行内では失敗を報せられない — マーカー経由で次回に通知）
FAIL_MARKER="${TMPDIR:-/tmp}/ai-context-combined-rebuild-${_proj_id}.failed"
if [ -f "$FAIL_MARKER" ]; then
    printf '[AI Context] combined.txt: the previous rebuild failed. Run the context-keeper agent (Agent subagent_type="banto:context-keeper") to verify consistency and rebuild it.\n' >&2
fi
if [ -f "$LOCK" ]; then
    if [ $(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || stat -f %m "$LOCK" 2>/dev/null || echo 0) )) -lt 10 ]; then
        exit 0
    fi
fi
touch "$LOCK"

(
    trap 'rm -f "$LOCK"' EXIT
    if python3 "$COMBINED_PY" --project-root "$CWD" --base "$AI_BASE" --scope project >/dev/null 2>&1; then
        rm -f "$FAIL_MARKER"
    else
        touch "$FAIL_MARKER"
    fi
    # FTS5 セクション索引も追従させる（鮮度スキップ・原子的差し替え・fail-open は内蔵）
    [ -f "$PATHS_DIR/store_index_gen.py" ] && python3 "$PATHS_DIR/store_index_gen.py" --base "$AI_BASE" >/dev/null 2>&1
    rm -f "$LOCK"
) &

exit 0
