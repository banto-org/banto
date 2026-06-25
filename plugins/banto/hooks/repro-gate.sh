#!/bin/sh
# repro-gate.sh — PreToolUse(Write|Edit) reproducibility gate for model-lab.
#
# Acts only on model-lab experiment artifacts:
#   - a training script (train/finetune/pretrain/distill/prune *.py) missing seed
#     fixing / determinism → advisory note (exit 0; do not churn mid-implementation)
#   - a results doc (results*/report*.md|json|.tex) that claims an improvement
#     without statistical backing (std / CI / bootstrap) → block (exit 2)
#
# The check itself is delegated to scripts/repro-check.sh (shared with the CLI).
# Escape:    BANTO_ALLOW_UNREPRO=1 (state a reason when using it)
# Fail-open: jq absent / no parseable content → exit 0.
set -u

command -v jq >/dev/null 2>&1 || exit 0
[ "${BANTO_ALLOW_UNREPRO:-0}" = "1" ] && exit 0

PAYLOAD=$(cat 2>/dev/null || echo '{}')
FILE=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$FILE" ] || exit 0
CONTENT=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
[ -n "$CONTENT" ] || exit 0

case "$FILE" in
    *train*.py|*finetune*.py|*pretrain*.py|*distill*.py|*prune*.py) KIND=train ;;
    *results*.md|*results*.json|*results*.jsonl|*report*.md|*.tex)  KIND=result ;;
    *) exit 0 ;;
esac

SDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP=$(mktemp) || exit 0
printf '%s' "$CONTENT" > "$TMP"
OUT=$(sh "$SDIR/../scripts/repro-check.sh" "$TMP" "$FILE" 2>/dev/null)
RC=$?
rm -f "$TMP"

[ "$RC" -eq 1 ] || exit 0
ITEMS=${OUT#warn:}

if [ "$KIND" = "result" ]; then
    case ",$ITEMS," in
        *,stats,*)
            cat >&2 <<MSG
⚠ repro-gate: results doc "$FILE" claims an improvement without statistical backing
(no std / CI / bootstrap / permutation). model-lab requires a multi-seed mean±CI before a
result is recorded. Add the variance/CI (scripts/eval-stats.sh) or drop the claim.
- Escape (state a reason): BANTO_ALLOW_UNREPRO=1
MSG
            exit 2 ;;
    esac
    exit 0
fi

cat >&2 <<MSG
note: repro-gate — "$FILE" is missing [$ITEMS]. Reproducibility needs a fixed seed +
torch.use_deterministic_algorithms(True) before the run. (advisory, not blocking)
MSG
exit 0
