#!/bin/sh
# AI Context Stop Hook
# Claude の応答完了時に、未保存の設計判断がないかチェックする
# exit 2 → ブロック（Claude に追加ターンを与える）
# exit 0 → 通常終了
#
# 重要: JSONL 全体を grep すると hook 出力やシステムメッセージも拾ってしまうので、
# jq でユーザーメッセージのテキストのみを抽出してチェックする。

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

[ -z "$CWD" ] || [ -z "$TRANSCRIPT" ] && exit 0

# ai-context ベースdir を解決（central/legacy 透過・既定 legacy で挙動不変）
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi
[ ! -d "$AI_BASE" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

# 当日の decision ファイルが既にあればOK（早期リターンで負荷削減）
TODAY=$(date +%Y-%m-%d)
ls "$AI_BASE/decisions/${TODAY}"_*.md >/dev/null 2>&1 && exit 0

# セッション単位の発火抑制
if command -v md5sum >/dev/null 2>&1; then
    HASH=$(echo -n "$TRANSCRIPT" | md5sum | cut -d' ' -f1)
elif command -v md5 >/dev/null 2>&1; then
    HASH=$(echo -n "$TRANSCRIPT" | md5 | cut -d' ' -f1)
else
    HASH=$(echo -n "$TRANSCRIPT" | cksum | cut -d' ' -f1)
fi
LOCK_FILE="${TMPDIR:-/tmp}/ai-context-stop-${HASH}.fired"
[ -f "$LOCK_FILE" ] && exit 0

# 直近のユーザーメッセージ10件のテキストのみを抽出
USER_TEXT=$(tail -2000 "$TRANSCRIPT" 2>/dev/null | jq -r '
    select(.type == "user" and .message.role == "user") |
    .message.content |
    if type == "string" then .
    elif type == "array" then map(select(.type == "text") | .text) | join(" ")
    else empty end
' 2>/dev/null | tail -10 | tr '\n' ' ')

[ -z "$USER_TEXT" ] && exit 0

# ユーザーメッセージのみ対象なので広めに設定
# 確定・承認・指示・決定を示す表現を網羅
KEYWORDS='(を採用|に決定|に決めた|に決めました|ではなく.*にする|に確定|確定しておいて|確定でいい|でいこう|でいきましょう|それで行こう|それで頼む|それでいい|それでOK|それでオッケー|それでいく|やってくれ|お願いします|お願いしたい|進めて|進めてください|その方向|その方針|そうしよう|そうして|そのとおり|その通り|合ってる|合っています|問題ない|問題なし|OKです|okだ|了解です|承認|採用|確認した上で|に切り替え|にピボット|に変更した|方針で行こう|finalized|adopted|approved|confirmed|go with|let.s go|sounds good|proceed)'
echo "$USER_TEXT" | grep -qiE "$KEYWORDS" || exit 0

touch "$LOCK_FILE"
echo "[AI Context] A design decision was detected in this conversation but has not been saved to $AI_BASE/decisions/." >&2
echo "Save it under decisions/ following the ai-context skill format." >&2
exit 2
