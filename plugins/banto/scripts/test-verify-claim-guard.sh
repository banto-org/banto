#!/bin/sh
# test-verify-claim-guard.sh — synthetic transcript/state tests for the build-and-verify
# enhancement of verify-claim-guard.sh (B1: block a completion claim while the last full
# verify is RED). Also covers the existing B2 error-trace heuristic and the no-claim path.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GUARD="$SCRIPT_DIR/../hooks/verify-claim-guard.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

command -v jq >/dev/null 2>&1 || { echo "jq required for this test"; exit 0; }

FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
export ODD_STATE_DIR="$FIX/state"; mkdir -p "$FIX/state"

CLAIM_T="$FIX/claim.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"実装が完了しました"}]}}' > "$CLAIM_T"
NOCLAIM_T="$FIX/noclaim.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"次に進みます"}]}}' > "$NOCLAIM_T"
ERR_T="$FIX/err.jsonl"
{ printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","is_error":true,"content":"boom"}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"修正しました"}]}}'; } > "$ERR_T"
# 誤検知回帰 1: 成功した tool_result の「内容」に fatal: 等の文字列 → error ではない
CONTENT_T="$FIX/content.jsonl"
{ printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","is_error":false,"content":"grep result: fatal: No such file or directory command not found [truncated]"}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"実装が完了しました"}]}}'; } > "$CONTENT_T"
# 誤検知回帰 2: 探索的な失敗のあと成功が 3 件続いて解消済み
RECOVERED_T="$FIX/recovered.jsonl"
{ printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","is_error":true,"content":"ls: no match"}]}}'
  printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","is_error":false,"content":"ok1"}]}}'
  printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","is_error":false,"content":"ok2"}]}}'
  printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","is_error":false,"content":"ok3"}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"実装が完了しました"}]}}'; } > "$RECOVERED_T"

guard() { printf '{"transcript_path":"%s","stop_hook_active":false,"session_id":"t"}' "$1" | sh "$GUARD" >/dev/null 2>&1; echo $?; }

# B1: claim + last verify RED -> block (exit 2)
rm -f "$FIX"/state/verify-last-*; printf 'red:test\n' > "$FIX/state/verify-last-t"
[ "$(guard "$CLAIM_T")" = "2" ] && ok "claim + verify RED -> block" || no "claim + verify RED should block"

# claim + last verify GREEN + no error trace -> pass (exit 0)
rm -f "$FIX"/state/verify-last-*; printf 'green\n' > "$FIX/state/verify-last-t"
[ "$(guard "$CLAIM_T")" = "0" ] && ok "claim + verify GREEN -> pass" || no "claim + verify GREEN should pass"

# no claim -> pass even if verify RED
rm -f "$FIX"/state/verify-last-*; printf 'red:test\n' > "$FIX/state/verify-last-t"
[ "$(guard "$NOCLAIM_T")" = "0" ] && ok "no claim -> pass (even if RED)" || no "no claim should pass"

# B2 (existing heuristic): claim + error trace, no verify state -> block
rm -f "$FIX"/state/verify-last-*
[ "$(guard "$ERR_T")" = "2" ] && ok "claim + error trace -> block (B2 heuristic intact)" || no "B2 heuristic should block"

# clean claim, no verify state, no error trace -> pass (no false positive)
rm -f "$FIX"/state/verify-last-*
[ "$(guard "$CLAIM_T")" = "0" ] && ok "clean claim (no verify, no error) -> pass" || no "clean claim should pass"

# false-positive regression: error strings inside a SUCCESSFUL tool_result content -> pass
[ "$(guard "$CONTENT_T")" = "0" ] && ok "claim + 'fatal:' in successful content -> pass" || no "content-only error strings should not block"

# false-positive regression: old error already recovered by 3 later successes -> pass
[ "$(guard "$RECOVERED_T")" = "0" ] && ok "claim + recovered error (3 successes after) -> pass" || no "recovered error should not block"

# false-positive regression: stale RED verify state (>4h) -> pass
rm -f "$FIX"/state/verify-last-*; printf 'red:test\n' > "$FIX/state/verify-last-t"
touch -t "$(date -v-5H +%Y%m%d%H%M 2>/dev/null || date -d '5 hours ago' +%Y%m%d%H%M)" "$FIX/state/verify-last-t"
[ "$(guard "$CLAIM_T")" = "0" ] && ok "claim + stale (>4h) verify RED -> pass" || no "stale verify RED should not block"

echo "verify-claim-guard tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
