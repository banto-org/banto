#!/bin/sh
# test-compute-cost-gate.sh — tests for compute-cost-gate.sh + eval-stats.sh (model-lab Phase 4).
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GATE="$SCRIPT_DIR/../hooks/compute-cost-gate.sh"
STATS="$SCRIPT_DIR/eval-stats.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

command -v jq >/dev/null 2>&1 || { echo "jq required for this test"; exit 0; }
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT

# ---- compute-cost-gate.sh ----
gate() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -R .)" | sh "$GATE" >/dev/null 2>&1; echo $?; }

[ "$(gate "sky launch task.yaml")" = "2" ]            && ok "gate: sky launch -> block" || no "sky launch should block"
[ "$(gate "sbatch train.slurm")" = "2" ]              && ok "gate: sbatch -> block" || no "sbatch should block"
[ "$(gate "accelerate launch --cpu train.py")" = "0" ] && ok "gate: --cpu dry-run -> pass" || no "--cpu should pass"
[ "$(gate "python train.py --device mps")" = "0" ]    && ok "gate: local mps train -> pass" || no "local train should pass"
[ "$(printf '{"tool_name":"Bash","tool_input":{"command":"sky launch x"}}' | BANTO_ALLOW_COMPUTE=1 sh "$GATE" >/dev/null 2>&1; echo $?)" = "0" ] \
    && ok "gate: BANTO_ALLOW_COMPUTE=1 bypasses" || no "allow var should bypass"

# project cloud-launcher scripts (surfaced by goba-training dogfood)
[ "$(gate "./scripts/lambda_auto.sh smoke")" = "2" ]   && ok "gate: lambda_auto.sh -> block" || no "lambda_auto should block"
[ "$(gate "bash scripts/aws_b300_auto.sh")" = "2" ]    && ok "gate: aws_b300_auto.sh -> block" || no "aws_b300_auto should block"
[ "$(gate "python3 scripts/cloud_streaming_data.py")" = "0" ] && ok "gate: local cloud_streaming_data.py -> pass" || no "local data script should pass"
[ "$(printf '{"tool_name":"Bash","tool_input":{"command":"./run_on_cluster.sh"}}' | BANTO_PAID_LAUNCH_RE='run_on_cluster' sh "$GATE" >/dev/null 2>&1; echo $?)" = "2" ] \
    && ok "gate: BANTO_PAID_LAUNCH_RE override -> block" || no "project override should block"

# ---- false-positive fixes: connect/inspect is not a launch (ssh / read-only cloud CLI) ----
[ "$(gate "ssh ubuntu@1.2.3.4 nvidia-smi")" = "0" ]    && ok "gate: ssh to box -> pass" || no "ssh should pass (not a launch)"
[ "$(gate "scp model.bin ubuntu@1.2.3.4:/data/")" = "0" ] && ok "gate: scp -> pass" || no "scp should pass"
[ "$(gate "aws ec2 describe-instances --filters Name=instance-state-name,Values=running")" = "0" ] \
    && ok "gate: aws describe-instances (read-only) -> pass" || no "aws describe should pass"
[ "$(gate "gcloud compute instances list")" = "0" ]    && ok "gate: gcloud instances list -> pass" || no "gcloud list should pass"

# ---- real cloud launch verbs still block ----
[ "$(gate "aws ec2 run-instances --image-id ami-123 --instance-type p4d.24xlarge")" = "2" ] \
    && ok "gate: aws ec2 run-instances -> block" || no "aws run-instances should block"
[ "$(gate "aws ec2 start-instances --instance-ids i-abc")" = "2" ] && ok "gate: aws ec2 start-instances -> block" || no "aws start-instances should block"
[ "$(gate "gcloud compute instances create gpu-vm --accelerator type=nvidia-tesla-a100")" = "2" ] \
    && ok "gate: gcloud instances create -> block" || no "gcloud create should block"

# ---- inline authorization prefix in the command string bypasses (the documented escape) ----
[ "$(gate "BANTO_ALLOW_COMPUTE=1 sky launch task.yaml")" = "0" ] \
    && ok "gate: inline BANTO_ALLOW_COMPUTE=1 prefix bypasses" || no "inline prefix should bypass"
[ "$(gate "cd /repo && BANTO_ALLOW_COMPUTE=1 aws ec2 run-instances --image-id ami-1")" = "0" ] \
    && ok "gate: inline prefix after && bypasses" || no "inline prefix mid-command should bypass"
[ "$(gate "echo BANTO_ALLOW_COMPUTE=10")" = "0" ]      && ok "gate: harmless echo -> pass (no launch)" || no "plain echo should pass"

# ---- eval-stats.sh ----
if command -v python3 >/dev/null 2>&1; then
    export ODD_STATE_DIR="$FIX/state"; mkdir -p "$FIX/state"
    R="$FIX/res.jsonl"
    { for v in 78.0 78.5 78.2 78.4 78.1; do printf '{"value":%s}\n' "$v"; done; } > "$R"

    out=$(BANTO_EVAL_TARGET=70 sh "$STATS" "$R"); rc=$?
    { [ "$rc" = "0" ] && echo "$out" | grep -q 'verdict=green'; } && ok "stats: target below CI -> green" || no "target 70 should be green (rc=$rc: $out)"
    [ "$(head -1 "$FIX/state/eval-last-cli" 2>/dev/null)" = "green" ] && ok "stats: writes eval-last green" || no "should write green state"

    out=$(BANTO_EVAL_TARGET=85 sh "$STATS" "$R"); rc=$?
    { [ "$rc" = "2" ] && echo "$out" | grep -q 'verdict=red'; } && ok "stats: target above mean -> red" || no "target 85 should be red (rc=$rc: $out)"
    head -1 "$FIX/state/eval-last-cli" 2>/dev/null | grep -q '^red' && ok "stats: writes eval-last red" || no "should write red state"

    printf '{"value":78.2}\n' > "$FIX/one.jsonl"
    sh "$STATS" "$FIX/one.jsonl" >/dev/null 2>&1 && ok "stats: <2 values -> fail-open exit 0" || no "insufficient data should fail-open"
else
    echo "  (python3 absent — eval-stats tests skipped)"
fi

echo "compute-cost-gate/eval-stats tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
