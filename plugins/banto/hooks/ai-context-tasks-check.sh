#!/bin/sh
# ai-context-tasks-check.sh
# PostToolUse(Write|Edit) hook — tasks/active.md の肥大化・Phase 混在を検知して警告。
# 行数閾値: 200 行 / Phase 数閾値: 4 つ
# v5.13.0 で追加（Phase C: tasks/active.md 動的化）

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$CWD" ] && exit 0
[ -z "$FILE" ] && exit 0

# ai-context ベースdir を解決（central/legacy 透過・既定 legacy で挙動不変）
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi

# tasks ファイルへの書き込みのみ反応（legacy active.md + 新 layout per-workspace tasks.md）
case "$FILE" in
    */tasks/active.md|*/.ai-context/tasks/active.md|*/workspaces/*/tasks.md) ;;
    *) exit 0 ;;
esac

# 書き込まれた tasks ファイル自体を分析する（layout 非依存）
ACTIVE="$FILE"
[ ! -f "$ACTIVE" ] && exit 0

LINES=$(wc -l < "$ACTIVE" | tr -d ' ')
PHASES=$(grep -c -E '^#{1,2} Phase:' "$ACTIVE" 2>/dev/null | tr -d ' ')
DONE_TASKS=$(grep -c '^- \[x\]' "$ACTIVE" 2>/dev/null | tr -d ' ')
OPEN_TASKS=$(grep -c '^- \[ \]' "$ACTIVE" 2>/dev/null | tr -d ' ')

# 閾値判定
WARN=""
if [ "${LINES:-0}" -gt 200 ]; then
    WARN="${WARN}${LINES} lines > 200 / "
fi
if [ "${PHASES:-0}" -ge 4 ]; then
    WARN="${WARN}${PHASES} phases (4 or more) / "
fi
# 全タスク完了なら自動アーカイブ提案
if [ "${OPEN_TASKS:-0}" = "0" ] && [ "${DONE_TASKS:-0}" -ge 1 ]; then
    WARN="${WARN}all tasks done / "
fi

[ -z "$WARN" ] && exit 0

# 末尾の "/ " を削除
WARN=$(printf "%s" "$WARN" | sed 's| / $||')

cat >&2 << END
[Tasks Check] The tasks file ($(basename "$(dirname "$ACTIVE")")/$(basename "$ACTIVE")) is bloated or awaiting cleanup: $WARN

Recommended actions:
  /ai-context tasks split          <- split interactively per phase
  /ai-context tasks split --auto   <- auto-archive completed phases only
  /ai-context phase-done           <- archive the phase when all tasks are done

Stats: lines=$LINES / phases=$PHASES / done=$DONE_TASKS / open=$OPEN_TASKS
END

exit 0
