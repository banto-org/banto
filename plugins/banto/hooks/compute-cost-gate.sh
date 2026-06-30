#!/bin/sh
# compute-cost-gate.sh — PreToolUse(Bash) cost gate for model-lab.
#
# Blocks a paid-compute launch (cluster / cloud GPU orchestrators) so the owner confirms
# the budget first. Local runs (Mac MPS/MLX, local Nvidia, --cpu dry-runs) pass through.
# This is the deterministic stop behind odd.yaml's "有料計算は人間ゲート".
#
# Allow after confirming budget (human authorization). Two equivalent forms:
#   - session env (settings.json / parent shell):  export BANTO_ALLOW_COMPUTE=1
#   - inline prefix on the command itself:          BANTO_ALLOW_COMPUTE=1 <cmd>
# Fail-open: jq absent / no command → exit 0.
set -u

command -v jq >/dev/null 2>&1 || exit 0
[ "${BANTO_ALLOW_COMPUTE:-0}" = "1" ] && exit 0

PAYLOAD=$(cat 2>/dev/null || echo '{}')
CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || exit 0

# Human authorization, inline form: `BANTO_ALLOW_COMPUTE=1 <cmd>`. A PreToolUse hook does NOT
# inherit a command's inline env assignment — that env only reaches the launched process, never
# the hook — so the env check above structurally cannot see the prefix. Detect the token in the
# command string instead, so the documented escape actually works.
printf '%s' "$CMD" | grep -qE '(^|[[:space:];&|(])BANTO_ALLOW_COMPUTE=1([[:space:]]|$)' && exit 0

# paid-compute launchers (cluster / cloud). Local training is NOT gated here. Neither are
# read-only / connection commands: ssh, scp, nvidia-smi, `aws ec2 describe-instances`,
# `gcloud compute instances list`, etc. — connecting to or inspecting an already-running box is
# not a *launch*. Only the actual launch verbs below are gated.
# Built-in: generic orchestrators + cloud-CLI launch verbs + GPU-cloud launcher scripts (Lambda / AWS B-series).
# Project-specific launchers: set BANTO_PAID_LAUNCH_RE to an extended-regex of your own scripts.
PAID='(^|[; &|])(sky|skypilot)[[:space:]]+(launch|jobs[[:space:]]+launch)|(^|[; &|])sbatch[[:space:]]|(^|[; &|])srun[[:space:]]|runpodctl[[:space:]]+(create|start)|(^|[; &|])aws[[:space:]]+ec2[[:space:]]+(run|start)-instances|(^|[; &|])gcloud[[:space:]]+compute[[:space:]]+instances[[:space:]]+(create|start)|(^|[; &|])az[[:space:]]+vm[[:space:]]+(create|start)|--cloud[[:space:]]|lambda_auto|lambda_setup|lambda_poll|aws_b[0-9]+_auto|aws_remote_build|_b[0-9]00_auto'
matched=no
printf '%s' "$CMD" | grep -qiE "$PAID" && matched=yes
[ "$matched" = "no" ] && [ -n "${BANTO_PAID_LAUNCH_RE:-}" ] && printf '%s' "$CMD" | grep -qiE "$BANTO_PAID_LAUNCH_RE" && matched=yes
[ "$matched" = "yes" ] || exit 0

cat >&2 <<MSG
⚠ compute-cost-gate: this looks like a paid-compute launch (cluster / cloud GPU):
    $CMD
model-lab gates paid compute behind owner confirmation (odd.yaml). Confirm the budget /
cost ceiling first, prefer Spot/preemptible, then re-run with the authorization prefix:
    BANTO_ALLOW_COMPUTE=1 $CMD
(The inline prefix is read from the command itself — it works even though a hook can't see a
command's env. Local runs — Mac MPS/MLX, local GPU, ssh to an existing box — are not gated.)
MSG
exit 2
