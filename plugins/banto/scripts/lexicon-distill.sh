#!/bin/sh
# lexicon-distill.sh — extracts frequent technical terms from recent decisions and proposes additions to the search lexicon.
#
# Continuous improvement of native search (carry-over from the search-native-migration spec).
# In addition to manual additions after deep-path successes, mechanically surfaces
# candidates from accumulated decisions.
#   spec: docs/specs/2026-06-10_harness-next-level (P2)
#
# Output (stdout): addition candidates for search-lexicon.md (applying them is a human / agent decision; never auto-appended).
# Usage: lexicon-distill.sh [cwd] [top_n]
# fail-open: decisions missing → no output, exit 0.

set -u

CWD="${1:-$PWD}"
TOP_N="${2:-15}"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
[ -f "$PATHS" ] || exit 0
BASE=$(sh "$PATHS" --resolve "$CWD" 2>/dev/null)
[ -z "$BASE" ] && exit 0

DEC="$BASE/decisions"
[ -d "$DEC" ] || exit 0
LEXICON="$BASE/search-lexicon.md"

# Aggregate ASCII technical terms (English words/abbreviations, 3+ chars) over the 40 most recent decisions
RECENT=$(ls -t "$DEC"/*.md 2>/dev/null | head -40)
[ -z "$RECENT" ] && exit 0

# stopwords (frequent but useless for the lexicon)
# i18n: the JP tokens in STOP are filtering logic for JP decision docs — do not translate.
# The banto-domain terms below (decisions, store, owner, ...) recur in nearly every decision log
# regardless of topic, so they drown out genuinely distinctive candidates (measured 2026-07-04:
# sh lexicon-distill.sh <base> 15 surfaced only generic terms in the top 15 before this list).
STOP=" the and for that this with from have are was were will into not but skill skills hook hooks 設計 する した して これ それ ため decisions decision store owner doc docs title scope status related accepted provisional agent agents opus haiku sonnet claude banto md file files grep i18n cold author date read find "

CANDIDATES=$(printf '%s\n' "$RECENT" | xargs grep -hoE '[A-Za-z][A-Za-z0-9_.+-]{2,}' 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' \
    | sort | uniq -c | sort -rn \
    | awk '{print $2, $1}')

[ -z "$CANDIDATES" ] && exit 0

TODAY=$(date +%Y-%m-%d 2>/dev/null || echo "")
PROPOSED=""
COUNT=0
# IFS line loop (temp variable instead of a here-string, to avoid a subshell)
OLD_IFS="$IFS"; IFS='
'
for line in $CANDIDATES; do
    term=$(printf '%s' "$line" | awk '{print $1}')
    freq=$(printf '%s' "$line" | awk '{print $2}')
    [ -z "$term" ] && continue
    # exclude stopwords
    case "$STOP" in *" $term "*) continue ;; esac
    # fewer than 3 occurrences is a weak signal → exclude
    [ "${freq:-0}" -lt 3 ] && continue
    # exclude terms already in the lexicon
    if [ -f "$LEXICON" ] && grep -qiw -- "$term" "$LEXICON" 2>/dev/null; then
        continue
    fi
    PROPOSED="${PROPOSED}- \`${term}\` (${freq} occurrences)
"
    COUNT=$((COUNT + 1))
    [ "$COUNT" -ge "$TOP_N" ] && break
done
IFS="$OLD_IFS"

[ -z "$PROPOSED" ] && exit 0

echo "## 🔤 search-lexicon addition candidates (from recent decisions / ${TODAY})"
echo "Frequent technical terms not yet in the lexicon. Adding them to \`${LEXICON#"$BASE"/}\` with translations, synonyms, and abbreviations improves search hit rate (applying is a judgment call)."
printf '%s' "$PROPOSED"
exit 0
