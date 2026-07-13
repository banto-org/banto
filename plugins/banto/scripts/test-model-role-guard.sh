#!/bin/sh
# test-model-role-guard.sh — model-role-guard.sh の合成 payload テスト（warn only, no block）
# 対象: model 未指定 Agent 起動への 1 回だけの警告 / model 指定時は無警告 /
#   同一セッション内の重複抑制 / セッションが異なれば再警告 / 非 Task|Agent は no-op / fail-open。
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$DIR/../hooks/model-role-guard.sh"
PLUGIN_ROOT=$(cd "$DIR/.." && pwd)

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/model-role-guard-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

run_hook() {  # $1=tool_name $2=session_id $3=model(optional) → stdout=stderr
    payload=$(jq -c -n --arg tn "$1" --arg sid "$2" --arg m "${3:-}" \
        '{tool_name:$tn, session_id:$sid, tool_input:(if $m == "" then {prompt:"x"} else {prompt:"x", model:$m} end)}')
    printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" TMPDIR="$TMP" sh "$HOOK" 2>&1 >/dev/null
}

_out=$(run_hook "Task" "sess-a"); _rc=$?
[ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -q "model-policy" \
    && ok "warns once for model-less Task launch" || bad "missing warning for model-less launch"

_out2=$(run_hook "Task" "sess-a"); _rc2=$?
[ "$_rc2" -eq 0 ] && [ -z "$_out2" ] \
    && ok "suppressed on repeat within the same session" || bad "repeat warning not suppressed"

_out3=$(run_hook "Agent" "sess-b"); _rc3=$?
[ "$_rc3" -eq 0 ] && printf '%s' "$_out3" | grep -q "model-policy" \
    && ok "warns again for a different session_id (Agent tool name)" || bad "new session did not re-warn"

_out4=$(run_hook "Task" "sess-c" "haiku"); _rc4=$?
[ "$_rc4" -eq 0 ] && [ -z "$_out4" ] \
    && ok "no warning when model is explicit" || bad "false warning despite explicit model"

_out5=$(run_hook "Bash" "sess-d"); _rc5=$?
[ "$_rc5" -eq 0 ] && [ -z "$_out5" ] \
    && ok "non-Task|Agent tool is a no-op" || bad "non-Task|Agent tool produced output"

printf 'not-json' | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" TMPDIR="$TMP" sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "fail-open: garbage payload exits 0" || bad "fail-open: garbage payload non-zero"

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; else echo "FAILURES PRESENT"; exit 1; fi
