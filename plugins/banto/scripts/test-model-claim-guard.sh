#!/bin/sh
# test-model-claim-guard.sh — tests for claim-link.sh + model-claim-guard.sh (model-lab Phase 3).
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LINK="$SCRIPT_DIR/claim-link.sh"
GUARD="$SCRIPT_DIR/../hooks/model-claim-guard.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

command -v jq >/dev/null 2>&1 || { echo "jq required for this test"; exit 0; }

FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT

# ---- claim-link.sh ----
LEDGER="$FIX/ledger.jsonl"
{ printf '%s\n' '{"claim":"acc +5%","run_id":"abc","status":"verified"}'
  printf '%s\n' '{"claim":"distill -0.8pt","run_id":"def","status":"proposed"}'; } > "$LEDGER"

printf 'Our method improved accuracy by +5%% (run:abc).\n' > "$FIX/paper_ok.tex"
sh "$LINK" "$LEDGER" "$FIX/paper_ok.tex" >/dev/null 2>&1 && ok "claim-link: backed claim -> pass" || no "backed claim should pass"

printf 'Our method improved accuracy by +5%%.\n' > "$FIX/paper_uncited.tex"
sh "$LINK" "$LEDGER" "$FIX/paper_uncited.tex" >/dev/null 2>&1; [ $? -eq 2 ] && ok "claim-link: uncited claim -> block(2)" || no "uncited claim should block"

printf 'Our method improved accuracy by +5%% (run:def).\n' > "$FIX/paper_unverified.tex"
sh "$LINK" "$LEDGER" "$FIX/paper_unverified.tex" >/dev/null 2>&1; [ $? -eq 2 ] && ok "claim-link: ref to non-verified run -> block(2)" || no "unverified ref should block"

printf 'This paper presents a method.\n' > "$FIX/paper_noclaim.tex"
sh "$LINK" "$LEDGER" "$FIX/paper_noclaim.tex" >/dev/null 2>&1 && ok "claim-link: no claims -> pass" || no "no-claim paper should pass"

# ---- model-claim-guard.sh ----
export ODD_STATE_DIR="$FIX/state"; mkdir -p "$FIX/state"
CLAIM_T="$FIX/claim.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"論文ドラフトが完成しました"}]}}' > "$CLAIM_T"
NOCLAIM_T="$FIX/noclaim.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"次の実験に進みます"}]}}' > "$NOCLAIM_T"
guard() { printf '{"transcript_path":"%s","stop_hook_active":false}' "$1" | sh "$GUARD" >/dev/null 2>&1; echo $?; }

rm -f "$FIX"/state/eval-last-*; printf 'red:acc\n' > "$FIX/state/eval-last-t"
[ "$(guard "$CLAIM_T")" = "2" ] && ok "guard: paper claim + eval RED -> block" || no "claim + eval RED should block"

rm -f "$FIX"/state/eval-last-*; printf 'green\n' > "$FIX/state/eval-last-t"
[ "$(guard "$CLAIM_T")" = "0" ] && ok "guard: paper claim + eval GREEN -> pass" || no "claim + eval GREEN should pass"

rm -f "$FIX"/state/eval-last-*; printf 'red:acc\n' > "$FIX/state/eval-last-t"
[ "$(guard "$NOCLAIM_T")" = "0" ] && ok "guard: no claim -> pass (even if RED)" || no "no claim should pass"

# ledger-based block: no eval state, ledger has a non-verified entry
rm -f "$FIX"/state/eval-last-*
[ "$(printf '{"transcript_path":"%s","stop_hook_active":false}' "$CLAIM_T" | BANTO_LEDGER="$LEDGER" sh "$GUARD" >/dev/null 2>&1; echo $?)" = "2" ] \
    && ok "guard: claim + ledger has non-verified -> block" || no "ledger non-verified should block"

# ledger all verified -> pass
ALLV="$FIX/ledger_allv.jsonl"; printf '%s\n' '{"claim":"acc +5%","run_id":"abc","status":"verified"}' > "$ALLV"
[ "$(printf '{"transcript_path":"%s","stop_hook_active":false}' "$CLAIM_T" | BANTO_LEDGER="$ALLV" sh "$GUARD" >/dev/null 2>&1; echo $?)" = "0" ] \
    && ok "guard: claim + ledger all verified -> pass" || no "ledger all-verified should pass"

# no eval state, no ledger -> pass (no false positive)
[ "$(guard "$CLAIM_T")" = "0" ] && ok "guard: claim, no eval state, no ledger -> pass" || no "clean claim should pass"

# false-positive regression: generic "公開しました" WITHOUT research nouns -> pass even if eval RED
PRPUB_T="$FIX/prpub.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"リリース PR を公開しました。マージは owner 操作です"}]}}' > "$PRPUB_T"
rm -f "$FIX"/state/eval-last-*; printf 'red:acc\n' > "$FIX/state/eval-last-t"
[ "$(guard "$PRPUB_T")" = "0" ] && ok "guard: PR publish claim (no research noun) -> pass" || no "PR publish should not block"

# publish claim WITH research noun -> still blocks on eval RED
HFPUB_T="$FIX/hfpub.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"モデルの重みを HF に公開しました"}]}}' > "$HFPUB_T"
[ "$(guard "$HFPUB_T")" = "2" ] && ok "guard: HF weights publish + eval RED -> block" || no "HF publish + RED should block"

# false-positive regression: stale eval RED (>4h) + paper claim -> pass
touch -t "$(date -v-5H +%Y%m%d%H%M 2>/dev/null || date -d '5 hours ago' +%Y%m%d%H%M)" "$FIX/state/eval-last-t"
[ "$(guard "$CLAIM_T")" = "0" ] && ok "guard: stale (>4h) eval RED -> pass" || no "stale eval RED should not block"

echo "model-claim-guard tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
