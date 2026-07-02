#!/bin/sh
# ai-context-decisions-numbering.sh
# decisions/ ファイルのタイムスタンプ命名 (YYYY-MM-DD-HHMMSS_topic_user.md) を支援する hook。
#
# - PostToolUse(Write|Edit): 日付始まりだが命名規約に合わない decisions 書き込みを警告
#   （PreToolUse の推奨名注入は 2026-07-02 監査で廃止 — PreToolUse の stdout はモデルに
#    inject されず死にコードだった。CONTRACT.md:40）
#
# v5.14.0: 同日連番 NNN を導入。
# v5.21.4: チーム並行・オフライン運用で NNN がローカル走査ゆえ衝突する問題を回避するため、
#          秒精度タイムスタンプ命名へ移行（decision 2026-05-31_004）。
#          旧 NNN 形式 (YYYY-MM-DD_NNN_) の既存ファイルも valid として許容（grandfather・リネーム不要）。

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$CWD" ] && exit 0

# decisions/ への書き込み判定
case "$FILE" in
    */decisions/*.md|*/.ai-context/decisions/*.md) ;;
    *) exit 0 ;;
esac

# ai-context のベースdir を解決（central/legacy 透過。既定 legacy → 挙動不変）。
# helper は scripts/ に在り、$AI_PATHS で sourced 時の resolver 位置を伝える契約。
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi

DEC_DIR="$AI_BASE/decisions"
[ ! -d "$DEC_DIR" ] && exit 0

NOW=$(date +%Y-%m-%d-%H%M%S)
# author 導出は _ai_context_author に集約（gh→git→$USER。paths.sh 不在時のみ $USER）
AUTHOR="${USER:-unknown}"
command -v _ai_context_author >/dev/null 2>&1 && AUTHOR=$(_ai_context_author "$CWD")

case "$EVENT" in
    PostToolUse)
        BASENAME=$(basename "$FILE")
        # 新形式（タイムスタンプ）でも旧形式（NNN）でもなく、日付始まりだけのものを警告
        if ! echo "$BASENAME" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}_" >/dev/null \
           && ! echo "$BASENAME" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{3}_" >/dev/null; then
            if echo "$BASENAME" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" >/dev/null; then
                cat >&2 << END
[Decisions Naming] decisions file does not follow the naming convention: $BASENAME

Recommended action:
  git mv "$FILE" "$(dirname "$FILE")/${NOW}_<topic>_${AUTHOR}.md"

Reason: second-precision timestamp naming is recommended to avoid number collisions in parallel team work (v5.21.4+)
END
            fi
        fi
        ;;
esac

exit 0
