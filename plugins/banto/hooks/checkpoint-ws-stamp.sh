#!/bin/sh
# checkpoint-ws-stamp.sh (PostToolUse: Write|Edit)
# チェックポイント（sessions/checkpoint-*.md）へ workspace 宛先マーカーを決定論で刻印する。
# 配送側（ai-context-session-start.sh）は marker と正準キー _ai_context_ws_key の完全一致で
# checkpoint を配送する。marker をモデルに書かせると [scope] プレフィックス欠落・literal "(none)"
# 等で揺れ、完全一致に恒常的に失敗する（reader は決定論・writer は非決定論という契約違反）。
# 本 hook が marker の唯一の決定論 writer となり、手動 /save-checkpoint と idle autofire fork の
# 両経路（どちらも Write を経由する）を 1 箇所でカバーする。正準キーは reader と同じ関数由来なので
# 完全一致が保たれる。
#
# no-op 条件: checkpoint パスでない / ファイル不在 / 既に marker あり / ws キーが解決不能。
# POSIX 互換: macOS / Linux / WSL。
#
# 重要: printf '%s' "$INPUT" | jq は JSON 内の $() 等がシェル展開されて壊れるため、
# 一時ファイル経由で jq に渡す。

command -v jq >/dev/null 2>&1 || exit 0

TEMP_INPUT=$(mktemp)
cat > "$TEMP_INPUT"
TOOL_NAME=$(jq -r '.tool_name // empty' "$TEMP_INPUT" 2>/dev/null)
FILE_PATH=$(jq -r '.tool_input.file_path // empty' "$TEMP_INPUT" 2>/dev/null)
CWD=$(jq -r '.cwd // empty' "$TEMP_INPUT" 2>/dev/null)
rm -f "$TEMP_INPUT"

case "$TOOL_NAME" in Write|Edit) ;; *) exit 0 ;; esac
[ -n "$FILE_PATH" ] || exit 0

# checkpoint mailbox のファイルだけを対象にする（ファイル名は checkpoint-YYYY-MM-DD-HHMM.md 規約）
case "$FILE_PATH" in
    */sessions/checkpoint-*.md) ;;
    *) exit 0 ;;
esac
[ -f "$FILE_PATH" ] || exit 0

# 既に marker があれば触らない（冪等。既存の正準 stamp も尊重）
grep -q '^<!-- banto-ws: ' "$FILE_PATH" 2>/dev/null && exit 0

PATHS="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}/scripts/_ai-context-paths.sh"
[ -f "$PATHS" ] || exit 0
[ -n "$CWD" ] || CWD="$PWD"

# 正準キー（reader = _ai_context_ws_key と同一経路）。未解決なら空 → 刻印しない
# （未マーカー = 後方互換で全 ws へ配送されるため starvation にはならない）。
WS_KEY=$(sh "$PATHS" --ws-key "$CWD" 2>/dev/null)
[ -n "$WS_KEY" ] || exit 0

# 正準マーカーを先頭行へ前置
TMP_CK="$FILE_PATH.wsstamp.$$"
if { printf '<!-- banto-ws: %s -->\n' "$WS_KEY"; cat "$FILE_PATH"; } > "$TMP_CK" 2>/dev/null; then
    mv -f "$TMP_CK" "$FILE_PATH" 2>/dev/null || rm -f "$TMP_CK" 2>/dev/null
else
    rm -f "$TMP_CK" 2>/dev/null
fi
exit 0
