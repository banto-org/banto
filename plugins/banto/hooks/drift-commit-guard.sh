#!/bin/sh
# drift-commit-guard.sh — PreToolUse(Bash) 警告フック（warn only, no block）
#
# banto の CONCEPT アンチゴール「edit repo と live plugin のドリフト」を commit 時点で拾う。
# plugins/banto/ 配下に staged 変更があるのに plugin.json（version）が同じ commit に
# 含まれていなければ、version bump 忘れの可能性を警告する。
#
# 判定対象: 当該 repo に plugins/banto/.claude-plugin/plugin.json が存在する場合のみ
# （= banto リポジトリ自身。それ以外の repo では marker が無いため no-op）。
#
# 入力: PreToolUse hook payload (stdin JSON)
# 出力: warn 時 stderr（CONTRACT.md: PreToolUse の stdout は inject されないため stderr）。
#       常に exit 0（block しない）。fail-open: jq / git 不在は no-op。

set -u

PAYLOAD=$(cat 2>/dev/null || true)

command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
HOOK_CWD=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
[ "$TOOL_NAME" = "Bash" ] || exit 0
[ -n "$CMD" ] || exit 0
[ -n "$HOOK_CWD" ] || HOOK_CWD=$PWD

# git commit セグメント判定（release-guard.sh / odd-kill-switch.sh と同じセグメント単位方式）
_commit=0
_segments=$(printf '%s\n' "$CMD" | tr ';&|' '\n')
while IFS= read -r _seg; do
    [ -n "$_seg" ] || continue
    case " $_seg " in
        *" git commit "*|*" git "*" commit "*) _commit=1 ;;
    esac
done <<DRIFT_GUARD_SEGMENTS
$_segments
DRIFT_GUARD_SEGMENTS
[ "$_commit" = "1" ] || exit 0

ROOT=$(git -C "$HOOK_CWD" rev-parse --show-toplevel 2>/dev/null)
[ -n "$ROOT" ] || exit 0

PLUGIN_JSON="$ROOT/plugins/banto/.claude-plugin/plugin.json"
[ -f "$PLUGIN_JSON" ] || exit 0   # banto リポジトリ以外は no-op

STAGED=$(git -C "$ROOT" diff --cached --name-only 2>/dev/null)
[ -n "$STAGED" ] || exit 0

_has_banto_change=0
_has_version_bump=0
while IFS= read -r _f; do
    [ -z "$_f" ] && continue
    case "$_f" in
        plugins/banto/.claude-plugin/plugin.json) _has_version_bump=1 ;;
        plugins/banto/*) _has_banto_change=1 ;;
    esac
done <<DRIFT_GUARD_STAGED
$STAGED
DRIFT_GUARD_STAGED

if [ "$_has_banto_change" = "1" ] && [ "$_has_version_bump" = "0" ]; then
    printf '[drift guard] plugins/banto/ has staged changes but plugin.json is not part of this commit — possible missed version bump.\n' >&2
    printf '  Check: %s\n' "$PLUGIN_JSON" >&2
fi

exit 0
