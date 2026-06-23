#!/bin/sh
# plugin-audit-matrix.sh
# Computes Axis 6: the cross-skill disambiguation matrix.
#
# Official basis + design decisions: skills/plugin-audit/references/scoring.md
#
# Usage:
#   ./plugin-audit-matrix.sh [PLUGIN_DIR]
#
# Output (Markdown):
#   - Vocabulary-overlap pairs (Warn when descriptions share ≥ 10 common words)
#   - Bidirectional reference pairs (A's description names B, and B's names A)
#   - Counts per waza prefix category
#
# Note: final judgment of boundary ambiguity (semantic disambiguation via a
# general-purpose Agent) is implemented in Phase E. This script is static only.

set -u
PLUGIN_DIR=${1:-.}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/plugin-audit-matrix.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

# ---- Extract (skill_name, description) from each SKILL.md ---------------------
mkdir -p "$TMP/words"

extract_name() {
    awk '
        { gsub(/\r/, "") }
        BEGIN{n=0}
        /^---$/{n++; if(n==2)exit; next}
        n==1 && /^name:[[:space:]]*/{
            sub(/^name:[[:space:]]*/, "")
            sub(/^"/, ""); sub(/"$/, "")
            sub(/^'\''/, ""); sub(/'\''$/, "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$1"
}

extract_desc() {
    awk '
        { gsub(/\r/, "") }
        BEGIN{n=0; in_desc=0; in_wtu=0}
        /^---$/{n++; if(n==2)exit; next}
        n==1 && /^description:/{
            sub(/^description:[[:space:]]*/, "")
            sub(/^"/, ""); sub(/"$/, "")
            sub(/^\|[[:space:]]*$/, "")
            print
            in_desc=1; in_wtu=0
            next
        }
        n==1 && /^when_to_use:/{
            sub(/^when_to_use:[[:space:]]*/, "")
            sub(/^"/, ""); sub(/"$/, "")
            sub(/^\|[[:space:]]*$/, "")
            print
            in_wtu=1; in_desc=0
            next
        }
        n==1 && (in_desc || in_wtu) && /^[[:space:]]+/{
            sub(/^[[:space:]]+/, "")
            print
            next
        }
        n==1 && (in_desc || in_wtu) && /^[[:alpha:]_-]+:/{ in_desc=0; in_wtu=0 }
    ' "$1"
}

# all_skills.tsv: name\tdesc\tpath
SKILL_FILES=$(find "$PLUGIN_DIR/skills" -name "SKILL.md" 2>/dev/null | sort)
[ -z "$SKILL_FILES" ] && { echo "(no SKILL.md found under skills/)"; exit 0; }

printf "%s\n" "$SKILL_FILES" | while read -r f; do
    [ -z "$f" ] && continue
    name=$(extract_name "$f")
    [ -z "$name" ] && continue
    desc=$(extract_desc "$f" | tr -d '\n')
    # Tokenize: replace punctuation (JP + ASCII) with spaces, lowercase, normalize synonyms to a
    # canonical token, dedupe tokens of length >= 2. The synonym dictionary lifts overlap detection
    # from raw word-matching toward *meaning* (e.g. save/store/保存 → one token), so semantically
    # near-duplicate descriptions surface even when worded differently. The agent (Phase E) still
    # makes the final boundary call. (JP is phrase-level here — synonym normalization mainly helps
    # the EN-heavy parts + standalone JP tokens.)
    # i18n: the JP punctuation / JP synonym literals below are tokenization logic — do not change.
    printf "%s\n" "$desc" \
        | tr '、。：（）「」【】，．・:();,(){}[]/<>"#'"'" ' ' \
        | tr '\t' ' ' \
        | tr ' ' '\n' \
        | tr 'A-Z' 'a-z' \
        | sed -E 's/^(save|store|record|persist|saving|保存|記録)$/_g_save/;s/^(search|find|recall|lookup|searching|検索|想起|探す)$/_g_find/;s/^(research|investigate|investigation|調査)$/_g_research/;s/^(decision|decisions|decide|決定|判断)$/_g_decision/;s/^(task|tasks|todo|タスク)$/_g_task/;s/^(parallel|fanout|fan-out|並列|並走)$/_g_parallel/;s/^(audit|auditing|監査)$/_g_audit/;s/^(report|status|報告|進捗)$/_g_report/;s/^(document|doc|docs|ドキュメント|資料)$/_g_doc/;s/^(checkpoint|チェックポイント)$/_g_checkpoint/;s/^(context|コンテキスト|文脈)$/_g_context/' \
        | awk 'length($0)>=2 {print}' \
        | sort -u > "$TMP/words/$name.txt"
    printf "%s\t%s\n" "$name" "$f" >> "$TMP/name_path.tsv"
done

[ ! -f "$TMP/name_path.tsv" ] && { echo "(no extractable SKILL.md found)"; exit 0; }

NAMES=$(cut -f1 "$TMP/name_path.tsv" | sort)
SKILL_COUNT=$(printf "%s\n" "$NAMES" | wc -l | tr -d ' ')

echo "# Plugin Disambiguation Matrix"
echo ""
echo "_Generated: $(date '+%Y-%m-%d %H:%M')_ / skills: ${SKILL_COUNT}"
echo ""
echo "**Axis 6**: static computation of the cross-skill disambiguation matrix. Semantic judgment of boundary ambiguity is done by an Agent (Phase E)."
echo ""

# ---- Vocabulary overlap -------------------------------------------------------
echo "## Vocabulary-overlap pairs (descriptions share ≥ 10 common words, Warn)"
echo ""
echo "**Note**: tokens are lowercased and run through a synonym dictionary (save/store/保存 → one token, etc.) so overlap reflects *meaning*, not just shared words; common stopwords still add structural noise, so pairs here are **candidates**. Final judgment of semantic overlap is done by an Agent (Phase E)."
echo ""

# Generate all pairs (fixed order, a < b) and compute overlap
THRESHOLD=10
PAIRS_OUT=""
NAMES_SORTED=$(printf "%s\n" "$NAMES")
# nested loop
i=0
echo "$NAMES_SORTED" | while read -r a; do
    [ -z "$a" ] && continue
    echo "$NAMES_SORTED" | while read -r b; do
        [ -z "$b" ] && continue
        # compute only when a < b (avoids duplicate pairs)
        case "$a" in
            "$b") continue ;;
        esac
        if [ "$a" \< "$b" ]; then
            overlap=$(comm -12 "$TMP/words/$a.txt" "$TMP/words/$b.txt" 2>/dev/null | wc -l | tr -d ' ')
            if [ "$overlap" -ge "$THRESHOLD" ]; then
                printf "%s\t%s\t%s\n" "$a" "$b" "$overlap"
            fi
        fi
    done
done | sort -t"$(printf '\t')" -k3 -rn > "$TMP/overlap.tsv"

if [ -s "$TMP/overlap.tsv" ]; then
    echo "| Skill A | Skill B | Common words |"
    echo "|---------|---------|----------|"
    while IFS=$(printf '\t') read -r a b c; do
        printf "| %s | %s | %s |\n" "$a" "$b" "$c"
    done < "$TMP/overlap.tsv"
else
    echo "(no pairs with ${THRESHOLD}+ common words)"
fi

# ---- Bidirectional references ---------------------------------------------------
echo ""
echo "## Bidirectional reference pairs (mutual mention in descriptions, Info)"
echo ""
echo "Pairs where A's description mentions B's name and B's description mentions A's name."
echo "Recommended design for explicitly communicating cross-skill boundaries."
echo ""

# Generate a description file per skill
mkdir -p "$TMP/desc"
printf "%s\n" "$SKILL_FILES" | while read -r f; do
    [ -z "$f" ] && continue
    name=$(extract_name "$f")
    [ -z "$name" ] && continue
    extract_desc "$f" | tr -d '\n' > "$TMP/desc/$name.txt"
done

# Check mutual references for each pair
echo "$NAMES_SORTED" | while read -r a; do
    [ -z "$a" ] && continue
    echo "$NAMES_SORTED" | while read -r b; do
        [ -z "$b" ] && continue
        case "$a" in
            "$b") continue ;;
        esac
        if [ "$a" \< "$b" ]; then
            # A's name appears in B's desc AND B's name appears in A's desc
            a_in_b=$(grep -F "$a" "$TMP/desc/$b.txt" 2>/dev/null | wc -l | tr -d ' ')
            b_in_a=$(grep -F "$b" "$TMP/desc/$a.txt" 2>/dev/null | wc -l | tr -d ' ')
            if [ "$a_in_b" -gt 0 ] && [ "$b_in_a" -gt 0 ]; then
                printf "%s\t%s\n" "$a" "$b"
            fi
        fi
    done
done > "$TMP/bidir.tsv"

if [ -s "$TMP/bidir.tsv" ]; then
    echo "| Skill A | Skill B |"
    echo "|---------|---------|"
    while IFS=$(printf '\t') read -r a b; do
        printf "| %s | %s |\n" "$a" "$b"
    done < "$TMP/bidir.tsv"
else
    echo "(no bidirectional reference pairs)"
fi

# ---- One-way references (A mentions B; B does not mention A) --------------------
echo ""
echo "## One-way references (warning candidates for boundary blur)"
echo ""
echo "Pairs where A's description mentions B, but B's description does not mention A."
echo "If B does not state explicitly \"when it, not skill A, should be invoked\", routing can wobble."
echo ""

echo "$NAMES_SORTED" | while read -r a; do
    [ -z "$a" ] && continue
    echo "$NAMES_SORTED" | while read -r b; do
        [ -z "$b" ] && continue
        case "$a" in
            "$b") continue ;;
        esac
        # B appears in A's desc; A does not appear in B's desc
        b_in_a=$(grep -F "$b" "$TMP/desc/$a.txt" 2>/dev/null | wc -l | tr -d ' ')
        a_in_b=$(grep -F "$a" "$TMP/desc/$b.txt" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$b_in_a" -gt 0 ] && [ "$a_in_b" -eq 0 ]; then
            printf "%s\t%s\n" "$a" "$b"
        fi
    done
done > "$TMP/oneway.tsv"

if [ -s "$TMP/oneway.tsv" ]; then
    ONEWAY_COUNT=$(wc -l < "$TMP/oneway.tsv" | tr -d ' ')
    echo "Count: ${ONEWAY_COUNT}"
    echo ""
    echo "**Note**: it is structurally normal for \"central / dependency-hub skills\" (the ones many others mention — e.g. a context store, an internal search, a research entry point) to be referenced widely. The remainder, after excluding such hubs, are the essential disambiguation improvement candidates."
    echo ""
    echo "| Mentioning (A) | Mentioned (B, no back-reference) |"
    echo "|-----------|------------------|"
    head -20 "$TMP/oneway.tsv" | while IFS=$(printf '\t') read -r a b; do
        printf "| %s | %s |\n" "$a" "$b"
    done
    if [ "$ONEWAY_COUNT" -gt 20 ]; then
        echo ""
        echo "_..._ (remaining $((ONEWAY_COUNT - 20)) omitted; see \`oneway.tsv\` in full via the \`--full\` argument)"
    fi
else
    echo "(none)"
fi

# ---- waza prefix category distribution ------------------------------------------
echo ""
echo "## waza skill classification prefix distribution"
echo ""
echo "Whether the body declares \`**WORKFLOW SKILL**\` / \`**UTILITY SKILL**\` / \`**ANALYSIS SKILL**\`."
echo ""

W_WORKFLOW=0
W_UTILITY=0
W_ANALYSIS=0
W_UNTAGGED=0

printf "%s\n" "$SKILL_FILES" | while read -r f; do
    [ -z "$f" ] && continue
    name=$(extract_name "$f")
    [ -z "$name" ] && continue
    if grep -q '\*\*WORKFLOW SKILL\*\*' "$f"; then
        echo "WORKFLOW $name"
    elif grep -q '\*\*UTILITY SKILL\*\*' "$f"; then
        echo "UTILITY $name"
    elif grep -q '\*\*ANALYSIS SKILL\*\*' "$f"; then
        echo "ANALYSIS $name"
    else
        echo "UNTAGGED $name"
    fi
done > "$TMP/prefix.txt"

for cat in WORKFLOW UTILITY ANALYSIS UNTAGGED; do
    count=$(awk -v c="$cat" '$1==c' "$TMP/prefix.txt" | wc -l | tr -d ' ')
    echo "- **$cat**: $count"
done

echo ""
echo "### UNTAGGED skills (no waza prefix adopted)"
echo ""
UNTAGGED=$(awk '$1=="UNTAGGED"{print $2}' "$TMP/prefix.txt")
if [ -n "$UNTAGGED" ]; then
    echo "$UNTAGGED" | awk 'BEGIN{ORS=""} {print "- " $0 "\n"}'
else
    echo "(every skill has adopted a waza prefix)"
fi

echo ""
echo "## References"
echo ""
echo "- Axis 6 design: \`skills/plugin-audit/references/scoring.md\`"
echo "- Related: the waza disambiguation matrix (internal audit reference)"
