#!/bin/sh
# repro-check.sh — model-lab reproducibility static check (Stage 4 / 7).
# Inspects a training script (seed fixing + determinism flags) or a results doc
# (statistical backing when it claims an improvement) and prints "ok" or
# "warn:<items>". Used both as a CLI (Stage 4/7) and by repro-gate.sh.
#
# Usage:
#   repro-check.sh <file>                 # check a file on disk (classify by its name)
#   repro-check.sh <contentfile> <name>   # check <contentfile>, classify by <name> (for the gate)
#
# Exit: 0 = ok / fail-open (cannot check) ; 1 = warnings found.
# No external deps (grep only). POSIX: macOS / Linux / WSL.
set -u

CONTENT_FILE=${1:-}
NAME=${2:-$CONTENT_FILE}
[ -n "$CONTENT_FILE" ] || { echo "usage: repro-check.sh <file> [name]" >&2; exit 0; }
[ -f "$CONTENT_FILE" ] || { echo "ok (no file to check)"; exit 0; }

C=$(cat "$CONTENT_FILE" 2>/dev/null) || { echo "ok (unreadable)"; exit 0; }

warns=""
add() { warns="${warns:+$warns,}$1"; }

case "$NAME" in
    *.py)
        printf '%s' "$C" | grep -qE 'manual_seed|set_seed|seed_everything|use_deterministic_algorithms|np\.random\.seed|random\.seed' || add seed
        printf '%s' "$C" | grep -qE 'use_deterministic_algorithms|CUBLAS_WORKSPACE_CONFIG|cudnn\.deterministic' || add determinism
        ;;
    *.md|*.json|*.jsonl|*.txt|*.tex)
        # only a results doc that claims an improvement needs statistical backing
        if printf '%s' "$C" | grep -qiE '改善|向上|outperform|state-of-the-art|SOTA|新記録|ベスト|\bbest\b|\+[0-9.]+ *%'; then
            printf '%s' "$C" | grep -qiE '±|std|stdev|標準偏差|信頼区間|\bCI\b|ci95|ci_95|bootstrap|permutation|p-value|p値' || add stats
        fi
        ;;
    *)
        echo "ok (not a checkable type)"; exit 0
        ;;
esac

if [ -n "$warns" ]; then
    echo "warn:$warns"
    exit 1
fi
echo "ok"
exit 0
