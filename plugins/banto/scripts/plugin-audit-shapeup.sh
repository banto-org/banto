#!/bin/sh
# plugin-audit-shapeup.sh — leanness "shape-up" review triggers (Axis 2 weight + cross-skill near-dup).
#
# PHILOSOPHY: every threshold here is a REVIEW TRIGGER, not a pass/fail gate. Exceeding one does not
# fail the skill — it marks content for a slimming review. A slightly-low threshold only costs an extra
# review that may exonerate the content, so the thresholds are set on the generous (catch-more) side.
# The plugin-audit `shapeup` flow then has an agent read each trigger's content and propose concrete
# slimming (or confirm it is justified). Static script = candidate generation; agent = judgment.
#
# Sections:
#   A. Per-skill weight       — SKILL.md body lines / subtree bytes / concentration vs thresholds.
#   B. Near-duplicate blocks  — >= N consecutive identical substantive lines shared by >= 2 skills.
#
# Usage:  plugin-audit-shapeup.sh <plugin_dir>
# Output: Markdown to stdout. Read-only. POSIX sh (macOS / Linux / WSL).

set -u

PLUGIN_DIR="${1:-.}"
SKILLS_DIR="$PLUGIN_DIR/skills"

# --- Thresholds (REVIEW TRIGGERS, not gates) ---------------------------------------
BODY_LINE_TRIGGER=400      # SKILL.md body lines (Axis 2 hard cap is 500; 400 = slim before the wall)
SUBTREE_BYTE_TRIGGER=51200 # whole-skill subtree bytes (50 KB) — review the reference set for trimming
CONCENTRATION_PCT=25       # a single skill over this % of total subtree weight = concentration review
DUP_MIN_LINES=8            # >= this many consecutive identical substantive lines across skills = copy

echo "## Shape-up: leanness review triggers (NOT pass/fail gates)"
echo ""

if [ ! -d "$SKILLS_DIR" ]; then
    echo "(no skills/ directory under \`$PLUGIN_DIR\` — nothing to scan)"
    exit 0
fi

echo "Each threshold below is a **review trigger**, not a gate: exceeding it marks content for a slimming"
echo "review, never a failure. Thresholds are deliberately generous (a low one only costs a review that may"
echo "exonerate the content). The agent reads each trigger's content and proposes concrete slimming."
echo ""
echo "Triggers: SKILL.md body > ${BODY_LINE_TRIGGER} lines · subtree > $((SUBTREE_BYTE_TRIGGER / 1024)) KB · single skill > ${CONCENTRATION_PCT}% of total · shared block >= ${DUP_MIN_LINES} identical lines across skills."
echo ""

# --- A. Per-skill weight -----------------------------------------------------------
# Ledger: <skill>\t<subtree_bytes>\t<body_lines>
LEDGER=$(
    for d in "$SKILLS_DIR"/*/; do
        [ -d "$d" ] || continue
        skill=$(basename "$d")
        bytes=$(find "$d" -type f -exec wc -c {} + 2>/dev/null | awk 'END{print $1+0}')
        # body_lines = SKILL.md with the leading frontmatter block stripped
        if [ -f "$d/SKILL.md" ]; then
            bl=$(awk 'NR==1 && /^---/ {fm=1; next} fm && /^---/ {fm=0; next} !fm {c++} END{print c+0}' "$d/SKILL.md")
        else
            bl=0
        fi
        printf '%s\t%s\t%s\n' "$skill" "${bytes:-0}" "${bl:-0}"
    done
)
TOTAL_BYTES=$(printf '%s\n' "$LEDGER" | awk -F'\t' '{b+=$2} END{print b+0}')
[ "$TOTAL_BYTES" -gt 0 ] || TOTAL_BYTES=1

echo "### A. Per-skill weight (review triggers)"
echo ""
WEIGHT_ROWS=$(printf '%s\n' "$LEDGER" | awk -F'\t' \
    -v bt="$BODY_LINE_TRIGGER" -v st="$SUBTREE_BYTE_TRIGGER" -v cp="$CONCENTRATION_PCT" -v tot="$TOTAL_BYTES" '
    {
        skill=$1; bytes=$2; bl=$3;
        pct = (bytes*100.0)/tot;
        t="";
        if (bl+0 > bt)      t = t (t==""?"":", ") "body>" bt "L";
        if (bytes+0 > st)   t = t (t==""?"":", ") "subtree>" int(st/1024) "KB";
        if (pct > cp)       t = t (t==""?"":", ") "conc>" cp "%";
        if (t != "") printf "%s\t%d\t%d\t%.1f\t%s\n", skill, bl, bytes, pct, t;
    }' | sort -t"$(printf '\t')" -k3,3nr)
if [ -n "$WEIGHT_ROWS" ]; then
    echo "| Skill | body lines | subtree bytes | % of total | trigger |"
    echo "|-------|-----------|---------------|-----------|---------|"
    printf '%s\n' "$WEIGHT_ROWS" | while IFS="$(printf '\t')" read -r s bl by pc t; do
        printf "| %s | %s | %s | %s%% | ⚠ %s |\n" "$s" "$bl" "$by" "$pc" "$t"
    done
else
    echo "(none — every skill is under the weight triggers)"
fi
echo ""
echo "Total skill weight: ${TOTAL_BYTES} bytes across $(printf '%s\n' "$LEDGER" | grep -c .) skills."
echo ""

# --- B. Near-duplicate blocks across skills ----------------------------------------
echo "### B. Near-duplicate blocks across skills (extract to a shared reference / rule)"
echo ""
echo "A run of >= ${DUP_MIN_LINES} consecutive identical substantive lines (blank / separator lines ignored)"
echo "appearing in >= 2 distinct skills = copy-paste. ⚠ extract the shared block into one reference or rule."
echo ""
WIN_F=$(mktemp 2>/dev/null || echo "/tmp/.banto-shapeup-win.$$")
: > "$WIN_F"
# Emit one line per sliding window: <block-joined-by-\x01>\t<skill>
find "$SKILLS_DIR" -type f \( -name '*.md' \) 2>/dev/null | sort | while read -r f; do
    rel=${f#"$SKILLS_DIR"/}
    skill=${rel%%/*}
    awk -v skill="$skill" -v n="$DUP_MIN_LINES" '
        NR==1 && /^---/ { fm=1; next }                 # skip leading frontmatter block
        fm && /^---/ { fm=0; next }                    #   (intentional field repetition is not prose dup)
        fm { next }
        { line=$0; sub(/^[[:space:]]+/,"",line); sub(/[[:space:]]+$/,"",line) }
        line=="" { next }                              # skip blank
        line ~ /^[-|:[:space:]]+$/ { next }            # skip pure separator rows
        { buf[++c]=line }
        END {
            for (i=1; i+n-1<=c; i++) {
                block=buf[i];
                for (j=1;j<n;j++) block=block "\001" buf[i+j];
                print block "\t" skill;
            }
        }' "$f" >> "$WIN_F"
done
# Group identical blocks; keep those shared by >= 2 DISTINCT skills. Collapse to one row per skill-set.
DUP_OUT=$(sort "$WIN_F" | awk -F'\t' '
    function flush(   ss, ns, sset, preview) {   # ss/ns/sset/preview are function-local (avoid clobbering $2 = s)
        if (block=="") return;
        ns=0; sset="";
        for (ss in seen) { ns++; sset = sset (sset==""?"":",") ss }
        if (ns>=2) {
            preview=block; sub(/\001.*/,"",preview);
            cnt[sset]++;
            if (!(sset in ex)) ex[sset]=preview;
        }
        delete seen; block="";
    }
    { b=$1; s=$2;
      if (b!=block) { flush(); block=b }
      seen[s]=1 }
    END { flush();
          for (k in cnt) printf "%s\t%d\t%s\n", k, cnt[k], ex[k] }
' | sort -t"$(printf '\t')" -k2,2nr)
rm -f "$WIN_F" 2>/dev/null || true
if [ -n "$DUP_OUT" ]; then
    echo "| Skills sharing the block | shared windows | sample first line |"
    echo "|--------------------------|----------------|-------------------|"
    printf '%s\n' "$DUP_OUT" | while IFS="$(printf '\t')" read -r skills cnt preview; do
        # truncate preview for table readability
        prev=$(printf '%s' "$preview" | cut -c1-70)
        printf "| %s | %s | %s |\n" "$skills" "$cnt" "$prev"
    done
else
    echo "(none — no >= ${DUP_MIN_LINES}-line block is shared across skills)"
fi
echo ""
echo "---"
echo "_Thresholds are review triggers, not gates. The plugin-audit \`shapeup\` flow reviews each trigger's content and proposes slimming._"
