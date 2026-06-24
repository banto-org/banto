#!/bin/sh
# ai-eval-judge.sh — minimal LLM-as-judge for the ai-build skill (Stage 6 EVAL).
#
# Scores a small case set with `claude -p` (0–100 per case), averages, and emits a
# verify-last-compatible one-line verdict so dev-loop's verify-claim-guard / escalation
# skeleton can be reused.
#
# Determinism split: this script DETERMINISTICALLY parses cases, aggregates, and decides
# PASS/FAIL against a threshold; the SCORING itself is delegated to an LLM (claude -p).
#
# Usage:
#   sh ai-eval-judge.sh <cases.jsonl>            # score a JSONL case set
#   sh ai-eval-judge.sh --help
#
# Case set (JSONL, one case per line):
#   {"input": "...", "expected": "...", "output": "..."}
#   - output   : the system-under-test's answer (judge scores it). If omitted, the judge
#                scores against `input` + `expected` only (rubric / absolute scoring).
#   - expected : the gold answer OR a scoring rubric (passed to the judge prompt). Optional.
#   NEVER put production client data / PII / internal names here (egress-guard blocks egress;
#   use synthetic or anonymized cases).
#
# Env:
#   BANTO_EVAL_PASS    pass threshold, 0–100 (default 70)
#   BANTO_EVAL_MODEL   judge model passed to `claude --model` (default: claude CLI default)
#   BANTO_EVAL_CMD     override the judge command (default: claude -p) — for tests
#
# Exit codes:
#   0  PASS  (avg >= threshold)  OR  fail-open no-op (claude / jq absent, empty case set)
#   2  FAIL  (avg <  threshold)
#   3  usage / argument error
#
# Fail-open: if `claude` or `jq` is missing, this prints a note and exits 0 — eval being
# unavailable must never block implementation (matches Banto's fail-open hook convention).
# POSIX compatible: macOS / Linux / WSL.
set -u

case "${1:-}" in
    --help|-h)
        sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    "")
        printf 'usage: ai-eval-judge.sh <cases.jsonl>\n' >&2
        exit 3
        ;;
esac

CASES="$1"
if [ ! -f "$CASES" ]; then
    printf 'ai-eval-judge: case file not found: %s\n' "$CASES" >&2
    exit 3
fi

PASS_THRESHOLD="${BANTO_EVAL_PASS:-70}"
JUDGE_CMD="${BANTO_EVAL_CMD:-}"

# Resolve the judge command (fail-open if claude is missing and no override given).
if [ -z "$JUDGE_CMD" ]; then
    if command -v claude >/dev/null 2>&1; then
        if [ -n "${BANTO_EVAL_MODEL:-}" ]; then
            JUDGE_CMD="claude -p --model ${BANTO_EVAL_MODEL}"
        else
            JUDGE_CMD="claude -p"
        fi
    else
        printf 'ai-eval-judge: claude CLI not found — eval skipped (fail-open, exit 0)\n'
        exit 0
    fi
fi

if ! command -v jq >/dev/null 2>&1; then
    printf 'ai-eval-judge: jq not found — eval skipped (fail-open, exit 0)\n'
    exit 0
fi

# Rubric handed to the judge. It must reply with ONLY an integer 0–100 (first integer wins).
RUBRIC='You are a strict evaluator (LLM-as-judge). Score how well OUTPUT satisfies the task,
given INPUT and (if present) EXPECTED — where EXPECTED may be a gold answer or a scoring rubric.
Scale 0–100: 100 = fully correct/faithful/on-format, 0 = wrong/unfaithful/off-format.
Penalize fabrication, missing the question, and format violations.
Reply with ONLY a single integer 0–100. No words, no punctuation.

'

total=0
count=0
failed_parse=0
line_no=0

# Read JSONL line by line. `|| [ -n "$line" ]` catches a final line without a trailing newline.
while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))
    # skip blank lines
    [ -n "$(printf '%s' "$line" | tr -d ' \t')" ] || continue

    if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
        printf 'ai-eval-judge: line %d is not valid JSON — skipped\n' "$line_no" >&2
        failed_parse=$((failed_parse + 1))
        continue
    fi

    c_input=$(printf '%s' "$line"    | jq -r '.input    // ""')
    c_expected=$(printf '%s' "$line" | jq -r '.expected // ""')
    c_output=$(printf '%s' "$line"   | jq -r '.output   // ""')

    prompt="${RUBRIC}INPUT:
${c_input}

EXPECTED:
${c_expected}

OUTPUT:
${c_output}
"

    # shellcheck disable=SC2086
    raw=$(printf '%s' "$prompt" | $JUDGE_CMD 2>/dev/null)
    # first integer 0–100 in the reply
    score=$(printf '%s' "$raw" | tr -c '0-9\n' ' ' | tr ' ' '\n' | grep -E '^[0-9]+$' | head -n1)

    if [ -z "$score" ]; then
        printf 'ai-eval-judge: case %d — no numeric score from judge — skipped\n' "$line_no" >&2
        failed_parse=$((failed_parse + 1))
        continue
    fi
    [ "$score" -gt 100 ] 2>/dev/null && score=100

    total=$((total + score))
    count=$((count + 1))
    printf 'case %d: %d\n' "$line_no" "$score"
done < "$CASES"

if [ "$count" -eq 0 ]; then
    printf 'ai-eval-judge: no scorable cases — eval skipped (fail-open, exit 0)\n'
    exit 0
fi

avg=$((total / count))
printf 'ai-eval-judge: scored=%d skipped=%d avg=%d threshold=%d\n' \
    "$count" "$failed_parse" "$avg" "$PASS_THRESHOLD"

if [ "$avg" -ge "$PASS_THRESHOLD" ]; then
    printf 'green\n'
    exit 0
else
    printf 'red:avg=%d<%d\n' "$avg" "$PASS_THRESHOLD"
    exit 2
fi
