#!/bin/sh
# AI Context PostCommit Hook (PostToolUse: Bash)
# git commit を検出して設計判断の保存をリマインド
# POSIX互換: macOS / Linux / WSL

command -v jq >/dev/null 2>&1 || exit 0

TEMP_INPUT=$(mktemp)
cat > "$TEMP_INPUT"

TOOL_INPUT=$(jq -r '.tool_input.command // empty' "$TEMP_INPUT" 2>/dev/null)
CWD=$(jq -r '.cwd // empty' "$TEMP_INPUT" 2>/dev/null)

rm -f "$TEMP_INPUT"

[ -z "$TOOL_INPUT" ] && exit 0
# `git commit` がコマンド先頭位置（行頭 or ; & | 直後）で現れる時のみ発火
# （`git -C <dir> commit` 対応）。旧実装の substring 一致は `grep -r 'git commit'` /
# `echo "how to git commit"` / `git log --grep='git commit'` 等で誤発火していた
# （2026-06-05 監査 TEST 1）。引数中に文字列として現れるだけのケースは拾わない。
echo "$TOOL_INPUT" | grep -Eq '(^[[:space:]]*|[;&|][[:space:]]*)git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?commit([[:space:]]|$)' || exit 0
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
[ ! -d "$AI_BASE" ] && exit 0
echo "[AI Context] Commit detected. If there were design decisions or important discussions, save them to $AI_BASE/decisions/."
exit 0
