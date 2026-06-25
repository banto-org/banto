#!/bin/sh
# claim-link.sh — verify every result claim in a paper is backed by a verified ledger entry.
# model-lab Stage 8: "no unbacked claim reaches the paper".
#
# Usage: claim-link.sh <ledger.jsonl> <paper.tex>
#   ledger.jsonl : one experiment per line, {claim, run_id, seeds, metric, mean, ci95, status}
#   paper.tex    : a result claim line must carry a run reference (run:<id> / clearml://<id>
#                  / \runref{<id>}) that resolves to a status="verified" ledger entry.
#
# Exit: 0 = all result claims backed / fail-open ; 2 = unbacked or unverified claims found.
set -u

LEDGER=${1:-}; PAPER=${2:-}
{ [ -n "$LEDGER" ] && [ -n "$PAPER" ]; } || { echo "usage: claim-link.sh <ledger.jsonl> <paper.tex>" >&2; exit 0; }
{ [ -f "$LEDGER" ] && [ -f "$PAPER" ]; } || { echo "claim-link: ledger or paper missing — skipped (fail-open)"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "claim-link: jq absent — skipped (fail-open)"; exit 0; }

VERIFIED=$(jq -r 'select((.status // "") == "verified") | .run_id // empty' "$LEDGER" 2>/dev/null)

CLAIM_RE='改善|向上|outperform|state-of-the-art|SOTA|新記録|\bbest\b|\+[0-9.]+ *%'
REF_RE='run:[A-Za-z0-9_/.-]+|clearml://[A-Za-z0-9_/.-]+|\\runref\{[^}]+\}'

problems=0
while IFS= read -r line; do
    printf '%s' "$line" | grep -qiE "$CLAIM_RE" || continue
    refs=$(printf '%s' "$line" | grep -oE "$REF_RE")
    if [ -z "$refs" ]; then
        echo "UNCITED: $line" >&2
        problems=$((problems + 1))
        continue
    fi
    for r in $refs; do
        id=$(printf '%s' "$r" | sed -E 's#^run:##; s#^clearml://##; s#^\\runref\{##; s#\}$##')
        printf '%s\n' "$VERIFIED" | grep -qxF "$id" || { echo "UNVERIFIED($id): $line" >&2; problems=$((problems + 1)); }
    done
done < "$PAPER"

if [ "$problems" -gt 0 ]; then
    echo "claim-link: $problems unbacked claim(s) — every result claim needs a verified ledger run." >&2
    exit 2
fi
echo "claim-link: all result claims are backed by verified ledger entries."
exit 0
