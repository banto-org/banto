#!/bin/sh
# plugin-audit-assets.sh — Axis 14 (hygiene) + Axis 2 (slimming) extended to the WHOLE skill subtree.
#
# plugin-audit-collect.sh audits only SKILL.md (one row per component), so reference files and any
# nested files under skills/<name>/ are never inspected for content quality. This script walks every
# file under each <plugin>/skills/*/ subtree (references/ + odd.yaml + eval-cases + any nested dir)
# and reports:
#   1. Subtree inventory   — files / bytes / lines per skill (where weight concentrates)
#   2. Unnecessary files   — junk that must never be committed (.DS_Store / *.bak / *.tmp / empty / ...)
#   3. Orphan references   — a references/*.md not linked from SKILL.md nor any sibling reference
#   3b. Dangling refs      — a references/X.md pointer (link / code-span / prose) whose target is missing
#   4. Slimming candidates — oversized reference files (Info: references may be long, but flag the heaviest)
#   5. Duplicate files     — identical content across the tree (by cksum) → dedupe candidate
#   6. Axis 14 hygiene     — per non-SKILL.md file: pasted run output / abs paths / emails / registry names
#
# Usage:  plugin-audit-assets.sh <plugin_dir>
# Output: Markdown to stdout. Read-only. POSIX sh (macOS / Linux / WSL).
#
# The hygiene / abs-path / email / proprietary-name patterns are the SAME as plugin-audit-collect.sh
# (that file is the source of truth — keep these in sync if they change there).

set -u

PLUGIN_DIR="."
STRICT=0
for a in "$@"; do
    case "$a" in
        --strict) STRICT=1 ;;
        *) PLUGIN_DIR="$a" ;;
    esac
done
HARD_FAIL=0
SKILLS_DIR="$PLUGIN_DIR/skills"

if [ ! -d "$SKILLS_DIR" ]; then
    echo "## Axis 14+ / Axis 2: skill subtree assets"
    echo ""
    echo "(no skills/ directory under \`$PLUGIN_DIR\` — nothing to scan)"
    exit 0
fi

# ---- Patterns (mirror of plugin-audit-collect.sh — source of truth) ----------------
HYGIENE_RUNLOG_PAT='^exit=[0-9]|\bALL PASS\b|subagent_tokens|duration_ms=|/private/tmp/claude|/var/folders/|\(eval\):[0-9]|^✓ |^✗ |[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}'
ABS_PATH_PAT='/Users/[A-Za-z0-9_.-]+/|C:[\\/]Users[\\/]|/home/[A-Za-z0-9_.-]+/'
EMAIL_PAT='[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
# Proprietary-name detection is REGISTRY-DRIVEN (never hardcode internal names in this public script).
NAME_REGISTRY="${BANTO_NAME_REGISTRY:-$HOME/.claude/banto-name-registry}"
PROJ_NAME_PAT=""
if [ -f "$NAME_REGISTRY" ]; then
    PROJ_NAME_PAT=$(grep -v '^[[:space:]]*#' "$NAME_REGISTRY" 2>/dev/null | grep -v '^re:' | grep -v '^[[:space:]]*$' | paste -sd'|' - 2>/dev/null)
fi

# Junk filenames that should never be committed into a skill subtree
JUNK_NAME_PAT='(^|/)\.DS_Store$|(^|/)Thumbs\.db$|\.bak$|\.old$|\.tmp$|\.orig$|\.rej$|\.swp$|~$|\.pyc$|(^|/)__pycache__(/|$)|(^|/)\.ipynb_checkpoints(/|$)|\.log$'

SLIM_LINE_THRESHOLD=500   # references over this are flagged as slimming candidates (Info)

count_pat() {
    # $1=file, $2=pattern → number of matching occurrences (match parity with collect.sh)
    grep -oE "$2" "$1" 2>/dev/null | wc -l | tr -d ' '
}

# ---- Walk every skill subtree, build a file ledger ---------------------------------
# Ledger line: <skill>\t<relpath>\t<category>\t<bytes>\t<lines>\t<cksum>
LEDGER=$(
    for d in "$SKILLS_DIR"/*/; do
        [ -d "$d" ] || continue
        skill=$(basename "$d")
        find "$d" -type f 2>/dev/null | sort | while read -r f; do
            rel=${f#"$SKILLS_DIR"/}
            base=$(basename "$f")
            case "$rel" in
                ("$skill"/SKILL.md)            cat=skill ;;
                ("$skill"/odd.yaml)            cat=odd ;;
                ("$skill"/eval-cases.yaml|"$skill"/verify-cases.yaml) cat=eval ;;
                ("$skill"/references/*)        cat=reference ;;
                (*)                            cat=other ;;
            esac
            bytes=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
            lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
            sum=$(cksum "$f" 2>/dev/null | awk '{print $1"-"$2}')
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$skill" "$rel" "$cat" "${bytes:-0}" "${lines:-0}" "${sum:-x}"
        done
    done
)

echo "## Axis 14+ / Axis 2: skill subtree assets (hygiene · junk · slimming)"
echo ""
echo "Scope: **every file under \`skills/*/\`** — SKILL.md + odd.yaml + references/ + any nested dir."
echo "Extends Axis 14 (content hygiene) and Axis 2 (structure / slimming) beyond SKILL.md, which is all"
echo "\`plugin-audit-collect.sh\` covers. SKILL.md hygiene is reported there; sections 1–6 below cover the rest."
echo ""

# ---- 1. Subtree inventory ----------------------------------------------------------
echo "### 1. Subtree inventory (heaviest first)"
echo ""
echo "| Skill | files | bytes | lines | references |"
echo "|-------|-------|-------|-------|------------|"
printf '%s\n' "$LEDGER" | awk -F'\t' '
    $1!="" {
        files[$1]++; bytes[$1]+=$4; lines[$1]+=$5;
        if ($3=="reference") refs[$1]++;
    }
    END {
        for (s in files) printf "%s\t%d\t%d\t%d\t%d\n", s, files[s], bytes[s], lines[s], refs[s]+0;
    }
' | sort -t"$(printf '\t')" -k3,3nr | while IFS="$(printf '\t')" read -r s nf nb nl nr; do
    printf "| %s | %s | %s | %s | %s |\n" "$s" "$nf" "$nb" "$nl" "$nr"
done
echo ""
TOTAL_BYTES=$(printf '%s\n' "$LEDGER" | awk -F'\t' '$1!=""{b+=$4} END{print b+0}')
TOTAL_FILES=$(printf '%s\n' "$LEDGER" | awk -F'\t' '$1!=""{n++} END{print n+0}')
echo "Total: ${TOTAL_FILES} files / ${TOTAL_BYTES} bytes under \`skills/\`."
echo ""

# ---- 2. Unnecessary / junk files ---------------------------------------------------
echo "### 2. Unnecessary files (junk — must not be committed)"
echo ""
echo "Patterns: \`.DS_Store\` / \`Thumbs.db\` / \`*.bak|.old|.tmp|.orig|.rej|.swp\` / \`*~\` / \`*.pyc\` / \`__pycache__/\` / \`.ipynb_checkpoints/\` / \`*.log\`, plus **empty (0-byte) files**. ❌ remove."
echo ""
JUNK=$(printf '%s\n' "$LEDGER" | awk -F'\t' -v pat="$JUNK_NAME_PAT" '
    $1!="" {
        is_junk = ($2 ~ pat) ? 1 : 0;
        if ($4==0) is_junk = 1;                 # empty file
        if (is_junk) printf "%s\t%s\t%s\n", $1, $2, ($4==0 ? "empty (0 bytes)" : "junk filename");
    }
')
if [ -n "$JUNK" ]; then
    echo "| Skill | File | Why |"
    echo "|-------|------|-----|"
    printf '%s\n' "$JUNK" | while IFS="$(printf '\t')" read -r s rel why; do
        printf "| %s | %s | %s |\n" "$s" "${rel#"$s"/}" "$why"
    done
else
    echo "(none — clean)"
fi
echo ""

# ---- 3. Orphan references ----------------------------------------------------------
echo "### 3. Orphan references (unreachable → slimming candidate)"
echo ""
echo "A \`references/*.md\` whose basename appears in **neither SKILL.md nor any sibling reference**."
echo "Unreachable = dead weight loaded by no path. ⚠ confirm (could be loaded via a non-link prose path), then remove or link."
echo ""
ORPHANS=""
for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    skill=$(basename "$d")
    refdir="$d/references"
    [ -d "$refdir" ] || continue
    skillmd="$d/SKILL.md"
    for rf in "$refdir"/*.md; do
        [ -f "$rf" ] || continue
        rb=$(basename "$rf")
        reachable=0
        # linked from SKILL.md?
        if [ -f "$skillmd" ] && grep -qF "$rb" "$skillmd" 2>/dev/null; then
            reachable=1
        fi
        # else linked from a sibling reference (exclude self)?
        if [ "$reachable" -eq 0 ]; then
            for sib in "$refdir"/*.md; do
                [ "$sib" = "$rf" ] && continue
                if grep -qF "$rb" "$sib" 2>/dev/null; then reachable=1; break; fi
            done
        fi
        if [ "$reachable" -eq 0 ]; then
            bytes=$(wc -c < "$rf" 2>/dev/null | tr -d ' ')
            ORPHANS="${ORPHANS}$(printf '%s\t%s\t%s\n' "$skill" "references/${rb}" "$bytes")
"
        fi
    done
done
if [ -n "$(printf '%s' "$ORPHANS" | tr -d '[:space:]')" ]; then
    echo "| Skill | File | bytes |"
    echo "|-------|------|-------|"
    printf '%s' "$ORPHANS" | while IFS="$(printf '\t')" read -r s rel bytes; do
        [ -n "$s" ] || continue
        printf "| %s | %s | %s |\n" "$s" "$rel" "$bytes"
    done
else
    echo "(none — every reference is reachable)"
fi
echo ""

# ---- 3b. Dangling references (pointer to a references/*.md that does not exist) -----
echo "### 3b. Dangling references (pointer to a non-existent references/*.md)"
echo ""
echo "A token \`references/X.md\` in any subtree file (markdown link OR code-span OR prose) whose target"
echo "does not exist in that skill's \`references/\`. Inverse of orphan (orphan = file nobody points to;"
echo "dangling = pointer to a missing file). Cross-skill paths (\`skills/<other>/references/...\`) and"
echo "placeholder names are excluded. ❌ broken pointer — fix the link or remove it."
echo ""
DANGLING_PLACEHOLDER='^([XxYyZzNn]|foo|bar|baz|qux|example|name|topic|slug|path|sub|ext1|ext2)$'
for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    skill=$(basename "$d")
    find "$d" -type f -name '*.md' 2>/dev/null | sort | while read -r f; do
        rel=${f#"$SKILLS_DIR"/}
        # strip cross-skill full paths first (skills/<other>/references/...), then grab bare references/X.md
        sed -E 's#skills/[A-Za-z0-9_-]+/references/[A-Za-z0-9_.-]+\.md##g' "$f" 2>/dev/null \
          | grep -oE 'references/[A-Za-z0-9_-]+\.md' 2>/dev/null | sort -u | while read -r ref; do
            rbase=$(basename "$ref" .md)
            printf '%s\n' "$rbase" | grep -qE "$DANGLING_PLACEHOLDER" && continue
            [ -e "$d/$ref" ] && continue
            printf '%s\t%s\t%s\n' "$skill" "$rel" "$ref"
        done
    done
done > /tmp/.banto-assets-dangling.$$ 2>/dev/null || true
if [ -s /tmp/.banto-assets-dangling.$$ ]; then
    HARD_FAIL=1
    echo "| Skill | In file | Dangling ref (missing target) |"
    echo "|-------|---------|-------------------------------|"
    sort -u /tmp/.banto-assets-dangling.$$ | while IFS="$(printf '\t')" read -r s rel ref; do
        printf "| %s | %s | %s |\n" "$s" "${rel#"$s"/}" "$ref"
    done
else
    echo "(none — every \`references/X.md\` pointer resolves)"
fi
rm -f /tmp/.banto-assets-dangling.$$ 2>/dev/null || true
echo ""

# ---- 4. Slimming candidates (oversized references) ---------------------------------
echo "### 4. Slimming candidates (oversized references, over ${SLIM_LINE_THRESHOLD} lines)"
echo ""
echo "References may be long (Runtime layer is uncapped), but the heaviest are the best split / trim targets. ℹ Info."
echo ""
OVERSIZED=$(printf '%s\n' "$LEDGER" | awk -F'\t' -v t="$SLIM_LINE_THRESHOLD" '$3=="reference" && $5>t {print $1"\t"$2"\t"$5"\t"$4}' | sort -t"$(printf '\t')" -k3,3nr)
if [ -n "$OVERSIZED" ]; then
    echo "| Skill | File | lines | bytes |"
    echo "|-------|------|-------|-------|"
    printf '%s\n' "$OVERSIZED" | while IFS="$(printf '\t')" read -r s rel nl nb; do
        printf "| %s | %s | %s | %s |\n" "$s" "$rel" "$nl" "$nb"
    done
else
    echo "(none over ${SLIM_LINE_THRESHOLD} lines)"
fi
echo ""

# ---- 5. Duplicate files (identical content) ----------------------------------------
echo "### 5. Duplicate files (identical content across the tree → dedupe candidate)"
echo ""
# Exclude 0-byte files (empty files collide trivially and are already flagged as junk).
DUP_HASHES=$(printf '%s\n' "$LEDGER" | awk -F'\t' '$1!="" && $6!="x" && $4>0{print $6}' | sort | uniq -d)
if [ -n "$DUP_HASHES" ]; then
    echo "| Files with identical content |"
    echo "|------------------------------|"
    printf '%s\n' "$DUP_HASHES" | while read -r h; do
        [ -n "$h" ] || continue
        files=$(printf '%s\n' "$LEDGER" | awk -F'\t' -v h="$h" '$6==h && $4>0{print $2}' | paste -sd', ' -)
        printf "| %s |\n" "$files"
    done
else
    echo "(none — no two files share identical content)"
fi
echo ""

# ---- 6. Axis 14 hygiene over non-SKILL.md files ------------------------------------
echo "### 6. Axis 14 hygiene — references + nested files (per-file pattern hits)"
echo ""
echo "Same patterns as \`plugin-audit-collect.sh\`: pasted run output / session debris, absolute home paths,"
echo "email addresses, and registry-driven internal names. SKILL.md is covered by collect.sh; this covers"
echo "everything else in the subtree. ⚠ Warn — review each (a documented format spec is fine; pasted dogfood output is not)."
echo ""
HYG_ROWS=""
printf '%s\n' "$LEDGER" | awk -F'\t' '$1!="" && $3!="skill"{print $1"\t"$2}' | while IFS="$(printf '\t')" read -r skill rel; do
    f="$SKILLS_DIR/$rel"
    [ -f "$f" ] || continue
    runlog=$(count_pat "$f" "$HYGIENE_RUNLOG_PAT")
    abspath=$(count_pat "$f" "$ABS_PATH_PAT")
    email=$(count_pat "$f" "$EMAIL_PAT")
    if [ -n "$PROJ_NAME_PAT" ]; then
        name=$(count_pat "$f" "$PROJ_NAME_PAT")
    else
        name=0
    fi
    total=$((runlog + abspath + email + name))
    [ "$total" -gt 0 ] && printf "| %s | %s | %s | %s | %s | %s | %s |\n" "$skill" "${rel#"$skill"/}" "$runlog" "$abspath" "$email" "$name" "$total"
done > /tmp/.banto-assets-hyg.$$ 2>/dev/null || true
if [ -s /tmp/.banto-assets-hyg.$$ ]; then
    echo "| Skill | File | runlog | abs-path | email | name | total |"
    echo "|-------|------|--------|----------|-------|------|-------|"
    cat /tmp/.banto-assets-hyg.$$
else
    echo "(none — clean)"
fi
rm -f /tmp/.banto-assets-hyg.$$ 2>/dev/null || true
echo ""
echo "---"
echo "_Source of truth for patterns: \`plugin-audit-collect.sh\`. This script is the subtree extension of Axis 14 + Axis 2._"

# --strict: hard-fail (exit 1) if dangling references (section 3b) were found. Other sections are
# informational review triggers (Info/Warn), so they never gate; only the broken-pointer ❌ does.
if [ "$STRICT" -eq 1 ] && [ "$HARD_FAIL" -eq 1 ]; then
    exit 1
fi
