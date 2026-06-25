#!/bin/sh
# compute-cost-gate.sh — PreToolUse(Bash) cost gate for model-lab.
#
# Blocks a paid-compute launch (cluster / cloud GPU orchestrators) so the owner confirms
# the budget first. Local runs (Mac MPS/MLX, local Nvidia, --cpu dry-runs) pass through.
# This is the deterministic stop behind odd.yaml's "有料計算は人間ゲート".
#
# Allow after confirming budget: BANTO_ALLOW_COMPUTE=1
# Fail-open: jq absent / no command → exit 0.
set -u

command -v jq >/dev/null 2>&1 || exit 0
[ "${BANTO_ALLOW_COMPUTE:-0}" = "1" ] && exit 0

PAYLOAD=$(cat 2>/dev/null || echo '{}')
CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || exit 0

# paid-compute launchers (cluster / cloud). Local training is NOT gated here.
# Built-in: generic orchestrators + common GPU-cloud launcher scripts (Lambda / AWS B-series).
# Project-specific launchers: set BANTO_PAID_LAUNCH_RE to an extended-regex of your own scripts.
PAID='(^|[; &|])(sky|skypilot)[[:space:]]+(launch|jobs[[:space:]]+launch)|(^|[; &|])sbatch[[:space:]]|(^|[; &|])srun[[:space:]]|runpodctl[[:space:]]+(create|start)|(^|[; &|])(aws|gcloud|az)[[:space:]].*(instance|gpu|compute).*(create|run|start)|--cloud[[:space:]]|lambda_auto|lambda_setup|lambda_poll|aws_b[0-9]+_auto|aws_remote_build|_b[0-9]00_auto'
matched=no
printf '%s' "$CMD" | grep -qiE "$PAID" && matched=yes
[ "$matched" = "no" ] && [ -n "${BANTO_PAID_LAUNCH_RE:-}" ] && printf '%s' "$CMD" | grep -qiE "$BANTO_PAID_LAUNCH_RE" && matched=yes
[ "$matched" = "yes" ] || exit 0

cat >&2 <<MSG
⚠ compute-cost-gate: this looks like a paid-compute launch (cluster / cloud GPU):
    $CMD
model-lab gates paid compute behind owner confirmation (odd.yaml). Confirm the budget /
cost ceiling first, prefer Spot/preemptible, then re-run with:
    BANTO_ALLOW_COMPUTE=1
(Local runs — Mac MPS/MLX, local GPU, 'accelerate launch --cpu' — are not gated.)
MSG
exit 2
