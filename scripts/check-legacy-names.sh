#!/bin/sh
# Gate: the exported (public) tree must not contain the legacy brand name.
# Usage: check-legacy-names.sh [--code]
#   --code : only code files (*.sh *.py *.json *.yaml *.yml *.js) — Phase 1 gate
#   (none) : all tracked files — Phase 4 export gate
# Lines carrying the inline tag "legacy:<name>" are allowed (migration shims).
# The same exclude list is reused by the export script (T4.7).
set -eu
cd "$(git rev-parse --show-toplevel)"

# Build the pattern from fragments so this script never matches itself.
NAME="plu""sing"
TAG="legacy:${NAME}"

SCOPE="${1:-full}"

# Paths excluded from this gate — mirror the export allowlist (these never reach the public tree):
#   CHANGELOG.md                  — internal history, not exported
#   skills/                       — repo-root standalone skills (TEAM-NOTES / system-dev-contracts /
#                                   re-x-development); absent from the export allowlist = private
#   scripts/check-legacy-names.sh — this gate itself
EXCLUDES=":(exclude)CHANGELOG.md
:(exclude)skills/
:(exclude)scripts/check-legacy-names.sh"

if [ "$SCOPE" = "--code" ]; then
  PATHSPEC="*.sh *.py *.json *.yaml *.yml *.js"
else
  PATHSPEC="."
fi

# shellcheck disable=SC2086 # intentional word-splitting of pathspecs
HITS="$(git grep -I -i -n -- "$NAME" -- $PATHSPEC $EXCLUDES 2>/dev/null | grep -v "$TAG" || true)"

if [ -z "$HITS" ]; then
  echo "OK: no legacy brand names found (scope: $SCOPE)"
  exit 0
fi

echo "FAIL: legacy brand name found (scope: $SCOPE):"
printf '%s\n' "$HITS" | awk -F: '{print $1}' | sort | uniq -c | sort -rn
echo "---"
printf '%s\n' "$HITS" | head -20
TOTAL="$(printf '%s\n' "$HITS" | wc -l | tr -d ' ')"
echo "(total: $TOTAL lines; tag allowed lines with \"$TAG\")"
exit 1
