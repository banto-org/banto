#!/bin/sh
# ai-context-decisions-numbering.sh
# decisions/ ファイルのタイムスタンプ命名 (YYYY-MM-DD-HHMMSS_topic_user.md) を支援する hook。
#
# - PostToolUse(Write|Edit): 日付始まりだが命名規約に合わない decisions 書き込みを警告。
#   さらに Write でファイル名日付が当日と異なる場合、タイムスタンプを記憶で書いた疑いとして警告。
#   （PreToolUse の推奨名注入は 2026-07-02 監査で廃止 — PreToolUse の stdout はモデルに
#    inject されず死にコードだった。CONTRACT.md:40。タイムスタンプの正は skill 側の date 取得指示）
#
# v5.14.0: 同日連番 NNN を導入。
# v5.21.4: チーム並行・オフライン運用で NNN がローカル走査ゆえ衝突する問題を回避するため、
#          秒精度タイムスタンプ命名へ移行（decision 2026-05-31_004）。
#          旧 NNN 形式 (YYYY-MM-DD_NNN_) の既存ファイルも valid として許容（grandfather・リネーム不要）。

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
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

        # タイムスタンプ精度チェック: 当日 Write なのにファイル名日付が当日と異なる場合、
        # モデルが日付を記憶で書いた疑いとして警告する（skill は date からの取得を指示）。
        # warn-only・Write のみ（Edit は既存 decision の改訂。意図的な back-date は無視可）。
        NAME_DATE=$(echo "$BASENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
        TODAY=$(echo "$NOW" | cut -d- -f1-3)
        if [ "$TOOL" = "Write" ] && [ -n "$NAME_DATE" ] && [ "$NAME_DATE" != "$TODAY" ]; then
            cat >&2 << END
[Decisions Timestamp] filename date ${NAME_DATE} differs from today ${TODAY} — the timestamp may have been written from memory rather than read from the clock.
If this decision is being saved now, use the real time:
  git mv "$FILE" "$(dirname "$FILE")/${NOW}_<topic>_${AUTHOR}.md"
Derive it from \`date +%Y-%m-%d-%H%M%S\` (do not round to a "nice" time). Intentional back-dating can be ignored.
END
        fi
        # スケルトン節チェック（decision 2026-07-17 freshness-newest-first）: 大型 decision の
        # 必須 4 節（背景/決定/根拠/検討した代替案。JA/EN 見出しとも許容）の欠落を警告する。
        # 軽量フォーマットの小型 decision はサイズゲートで対象外。warn-only・never block。
        if [ -f "$FILE" ]; then
            SIZE=$(wc -c < "$FILE" 2>/dev/null | tr -d ' ')
            if [ "${SIZE:-0}" -gt 1500 ]; then
                MISSING=""
                grep -Eq "^#{1,3} .*(背景|出発点|Background|Context)" "$FILE" || MISSING="$MISSING 背景/Background"
                grep -Eq "^#{1,3} .*(決定|判断|Decision)" "$FILE" || MISSING="$MISSING 決定/Decision"
                grep -Eq "^#{1,3} .*(根拠|決め手|理由|Rationale)" "$FILE" || MISSING="$MISSING 根拠/Rationale"
                grep -Eq "^#{1,3} .*(代替案|選択肢|不採用|Alternatives|Considered)" "$FILE" || MISSING="$MISSING 検討した代替案/Considered-Alternatives"
                if [ -n "$MISSING" ]; then
                    cat >&2 << END
[Decision Skeleton] missing required sections:$MISSING

Substantial decisions follow the fixed skeleton (背景/決定/根拠/検討した代替案 + 影響と限界).
The rejected-alternatives section is the highest-value one: it answers "why not X" searches
and becomes the extraction unit for training-data export ([B-03]).
Template: ai-context skill references/decisions.md (warn-only; lightweight small decisions are exempt)
END
                fi
            fi
        fi
        ;;
esac

exit 0
