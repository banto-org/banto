#!/bin/sh
# test-repro-gate.sh — synthetic payload tests for repro-check.sh + repro-gate.sh (model-lab Phase 2).
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHECK="$SCRIPT_DIR/repro-check.sh"
GATE="$SCRIPT_DIR/../hooks/repro-gate.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

command -v jq >/dev/null 2>&1 || { echo "jq required for this test"; exit 0; }

FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT

# ---- repro-check.sh (CLI) ----
printf 'import torch\nmodel.fit()\n' > "$FIX/train_noseed.py"
out=$(sh "$CHECK" "$FIX/train_noseed.py"); rc=$?
{ [ "$rc" = "1" ] && echo "$out" | grep -q seed; } && ok "check: train no seed -> warn:seed" || no "train no seed should warn (got rc=$rc out=$out)"

printf 'import torch\ntorch.manual_seed(0)\ntorch.use_deterministic_algorithms(True)\nmodel.fit()\n' > "$FIX/train_ok.py"
out=$(sh "$CHECK" "$FIX/train_ok.py"); rc=$?
{ [ "$rc" = "0" ] && [ "$out" = "ok" ]; } && ok "check: train with seed+determinism -> ok" || no "train ok should pass (got rc=$rc out=$out)"

printf '# Results\naccuracy improved by +5%% over baseline\n' > "$FIX/results_bad.md"
out=$(sh "$CHECK" "$FIX/results_bad.md"); rc=$?
{ [ "$rc" = "1" ] && echo "$out" | grep -q stats; } && ok "check: results improvement w/o stats -> warn:stats" || no "results no-stats should warn (got rc=$rc out=$out)"

printf '# Results\naccuracy improved by +5%% (95%% CI [3.1, 6.9], 5 seeds)\n' > "$FIX/results_ok.md"
out=$(sh "$CHECK" "$FIX/results_ok.md"); rc=$?
{ [ "$rc" = "0" ]; } && ok "check: results improvement w/ CI -> ok" || no "results with CI should pass (got rc=$rc out=$out)"

# ---- repro-gate.sh (PreToolUse) ----
gate() { printf '%s' "$1" | sh "$GATE" >/dev/null 2>&1; echo $?; }

P_TRAIN_NOSEED=$(printf '{"tool_name":"Write","tool_input":{"file_path":"/p/train.py","content":"import torch\\nmodel.fit()\\n"}}')
[ "$(gate "$P_TRAIN_NOSEED")" = "0" ] && ok "gate: train no seed -> advisory (exit 0)" || no "train no seed should be advisory"

P_RESULT_BAD=$(printf '{"tool_name":"Write","tool_input":{"file_path":"/p/results.md","content":"accuracy improved by +5%% over baseline"}}')
[ "$(gate "$P_RESULT_BAD")" = "2" ] && ok "gate: results improvement w/o stats -> block (exit 2)" || no "results no-stats should block"

P_RESULT_OK=$(printf '{"tool_name":"Write","tool_input":{"file_path":"/p/results.md","content":"accuracy improved by +5%% (95%% CI [3.1,6.9])"}}')
[ "$(gate "$P_RESULT_OK")" = "0" ] && ok "gate: results improvement w/ CI -> pass (exit 0)" || no "results with CI should pass"

P_OTHER=$(printf '{"tool_name":"Write","tool_input":{"file_path":"/p/notes.txt","content":"+5%% improved"}}')
[ "$(gate "$P_OTHER")" = "0" ] && ok "gate: non-artifact file -> pass (exit 0)" || no "non-artifact should pass"

ESC=$(printf '{"tool_name":"Write","tool_input":{"file_path":"/p/results.md","content":"improved by +5%%"}}')
[ "$(printf '%s' "$ESC" | BANTO_ALLOW_UNREPRO=1 sh "$GATE" >/dev/null 2>&1; echo $?)" = "0" ] && ok "gate: escape var bypasses block" || no "escape var should bypass"

echo "repro-gate tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
