#!/bin/sh
# model-role-guard.sh — PreToolUse(Task|Agent) 警告フック（warn only, no block）
#
# model 未指定のサブエージェント起動は親モデルを継承し高コストになりやすい
# （quality.md: 実装 fan-out は sonnet / 機械的探索は haiku / 監査は opus を既定とする）。
# 同一セッション内での再警告はマーカーファイルで 1 回だけに抑制する
# （checkpoint-recommend.sh と同じ ${TMPDIR}/banto-<name>-<session_id> 方式）。
#
# 入力: PreToolUse hook payload (stdin JSON)
# 出力: 警告時 stderr（CONTRACT.md: PreToolUse の stdout は inject されないため stderr）。
#       常に exit 0（block しない）。fail-open: jq 不在 / session_id 欠如は no-op。
set -u

command -v jq >/dev/null 2>&1 || exit 0

PAYLOAD=$(cat 2>/dev/null || true)
TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
case "$TOOL_NAME" in
    Task|Agent) ;;
    *) exit 0 ;;
esac

MODEL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.model // empty' 2>/dev/null)
[ -n "$MODEL" ] && exit 0   # model 明示済みは対象外

SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0

MARKER="${TMPDIR:-/tmp}/banto-model-role-warned-${SESSION_ID}"
[ -f "$MARKER" ] && exit 0   # 同一セッション内は 1 回だけ
: > "$MARKER" 2>/dev/null

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
POLICY="$PLUGIN_ROOT/templates/model-policy.json"

IMPLEMENT="sonnet"; MECHANICAL="haiku"; AUDIT="opus"
if [ -f "$POLICY" ]; then
    _i=$(jq -r '.roles.implement // empty' "$POLICY" 2>/dev/null); [ -n "$_i" ] && IMPLEMENT="$_i"
    _m=$(jq -r '.roles.mechanical // empty' "$POLICY" 2>/dev/null); [ -n "$_m" ] && MECHANICAL="$_m"
    _a=$(jq -r '.roles.audit // empty' "$POLICY" 2>/dev/null); [ -n "$_a" ] && AUDIT="$_a"
fi

printf '[model role] Agent launched without an explicit model (inherits the parent model — high cost). model-policy: implement=%s / mechanical=%s / audit=%s\n' \
    "$IMPLEMENT" "$MECHANICAL" "$AUDIT" >&2

exit 0
