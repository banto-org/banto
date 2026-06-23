#!/bin/sh
# plugin-audit-report.sh
# Reads the TSV output of plugin-audit-collect.sh and generates the
# static structural audit report in Markdown.
#
# 2026-05-14: waza-style Sensei scoring (Low/Medium/Medium-High/High) was retired.
# Migrating to the multi-axis evaluation system. Details: skills/plugin-audit/references/scoring.md
#
# Usage:
#   ./plugin-audit-collect.sh . | ./plugin-audit-report.sh
#   ./plugin-audit-report.sh < audit.tsv
#
# TSV column order (47 columns):
#   Base metrics: 1=type 2=path 3=desc_len 4=body_lines 5=body_tokens
#             6=disable_invocation 7=has_waza_prefix 8=has_heavyskill
#   Axis 1: 9-26 (official 19-field coverage)
#   Axis 3: 27=desc_starts_use_when 28=has_negative_example 29=desc_long_warn
#   Axis 2 extension: 30=ref_count 31=ref_broken_count 32=has_references_dir
#   Axis 7: 33=abs_path_count 34=proj_name_count 35=tool_mac_count
#           36=tool_win_count 37=tool_linux_count 38=email_count
#   Axis 9: 39=rule_should_path_scope 40=rule_hard_constraint (meaningful for rules only)
#   Axis 9 extension: 41=hook_event 42=hook_matcher 43=hook_blocks 44=hook_warns (hooks only)
#   Axis 10: 45=has_odd_yaml 46=odd_autonomy_level (skills only)
#   Axis 14: 47=hygiene_runlog_count (pasted run output / session debris)

set -u
TSV=$(cat)

# Strip header
DATA=$(printf "%s\n" "$TSV" | tail -n +2)

total_count() {
    printf "%s\n" "$DATA" | awk -F'\t' -v t="$1" '$1==t' | wc -l | tr -d ' '
}

TOTAL_SKILL=$(total_count "skill")
TOTAL_AGENT=$(total_count "agent")
TOTAL_RULE=$(total_count "rule")
TOTAL_CMD=$(total_count "command")
TOTAL_HOOK=$(total_count "hook")

echo "# Plugin Static Audit Report"
echo ""
echo "_Generated: $(date '+%Y-%m-%d %H:%M')_"
echo ""
echo "**Note**: this report covers the static axes (1/2/3/7-static/9/10/14-static). The judgment axes — Axis 4 (routing-precision eval), Axis 5 (HeavySkill applicability), Axis 6 (disambiguation boundary), Axis 7 (semantic generality), Axis 8 (generality / rule-externalization fitness), Axis 12 (permission minimality), Axis 13 (hook containment), Axis 14 (semantic hygiene) — are run by the plugin-audit skill via independent subagents (Reviewer = Fresh Agent)."
echo "Details: \`skills/plugin-audit/references/scoring.md\`"
echo ""
echo "**How to read**: each \`###\` heading names a *check*, not a finding. A heading whose body is \`✓ none\` is clean — only rows in a table are actual findings. Do not read a bare \`❌\`/\`⚠️\` heading as a hit."
echo ""
echo "## Summary"
echo ""
echo "| Type | Count |"
echo "|------|------|"
[ "$TOTAL_SKILL" != "0" ] && echo "| skill | $TOTAL_SKILL |"
[ "$TOTAL_AGENT" != "0" ] && echo "| agent | $TOTAL_AGENT |"
[ "$TOTAL_RULE" != "0" ]  && echo "| rule  | $TOTAL_RULE |"
[ "$TOTAL_CMD" != "0" ]   && echo "| command | $TOTAL_CMD |"
[ "$TOTAL_HOOK" != "0" ]  && echo "| hook  | $TOTAL_HOOK |"

# ---- Axis 1: YAML structural validity ----------------------------------------
echo ""
echo "## Axis 1: YAML structural validity"
echo ""

echo "### ❌ Critical: no invocation path (DMI=true + user-invocable=false)"
echo ""
echo "Neither Claude auto-firing nor explicit invocation is possible — permanently unreachable."
echo ""
CRITICAL_NO_ENTRY=0
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$6=="1" && $14=="false" {print $1"\t"$2}')
if [ -n "$TBL" ]; then
    echo "| Type | File |"
    echo "|------|------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s |\n" "$type" "$short"
        CRITICAL_NO_ENTRY=$((CRITICAL_NO_ENTRY+1))
    done
else
    echo "✓ none"
fi

echo ""
echo "### ❌ Critical: context: fork without agent (schema violation)"
echo ""
echo "Subagent fork mode (fork) without a target agent specified."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$20=="fork" && $21=="0" {print $1"\t"$2}')
if [ -n "$TBL" ]; then
    echo "| Type | File |"
    echo "|------|------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s |\n" "$type" "$short"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ⚠️ Warn: comma-separated allowed-tools (unofficial format)"
echo ""
echo "The official spec is space-separated or a YAML list. Comma separation can cause tool-name parsing errors."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$17=="1" {print $1"\t"$2}')
if [ -n "$TBL" ]; then
    echo "| Type | File |"
    echo "|------|------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s |\n" "$type" "$short"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ℹ️ Info: suspected over-spec (model: opus + body < 30 lines)"
echo ""
echo "Specifying opus for a short skill may be excessive. Final judgment is delegated to an Agent (Phase E)."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$18=="opus" && $4<30 && $1!="rule" {print $1"\t"$2"\t"$4}')
if [ -n "$TBL" ]; then
    echo "| Type | File | Lines |"
    echo "|------|------|-------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path lines; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s |\n" "$type" "$short" "$lines"
    done
else
    echo "✓ none"
fi

echo ""
echo "### description over the character caps (official spec)"
echo ""
echo "- Open Standard: description alone ≤ **1,024 chars**"
echo "- Claude Code: description + when_to_use combined ≤ **1,536 chars**"
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$3 > 1024 && $1!="rule" {print $1"\t"$2"\t"$3}')
if [ -n "$TBL" ]; then
    echo "| Type | File | Length |"
    echo "|------|------|--------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path desc_len; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        if [ "$desc_len" -gt 1536 ]; then
            st="❌ ${desc_len} (over combined cap 1,536)"
        else
            st="⚠️ ${desc_len} (over Open Standard cap 1,024)"
        fi
        printf "| %s | %s | %s |\n" "$type" "$short" "$st"
    done
else
    echo "✓ none"
fi

echo ""
echo "### 19-field coverage (skill / agent only)"
echo ""
echo "Adoption rate of each field across skills. name/description under \"identity\" are required, DMI/user-invocable under \"firing control\" are best practice, and license/compatibility/metadata under \"Open Standard\" prepare for future distribution."
echo ""

# adoption counts
count_field() {
    # $1 = column number, $2 = predicate ("1" or "true"/"false"/"empty", etc.)
    printf "%s\n" "$DATA" | awk -F'\t' -v col="$1" -v val="$2" '$1!="rule" && $col==val' | wc -l | tr -d ' '
}

NON_RULE=$((TOTAL_SKILL + TOTAL_AGENT + TOTAL_CMD))
[ "$NON_RULE" = "0" ] && NON_RULE=1

pct() {
    awk -v n="$1" -v d="$NON_RULE" 'BEGIN{printf "%d", n*100/d}'
}

C_NAME=$(count_field 9 1)
C_DESC=$(count_field 10 1)
C_WTU=$(count_field 11 1)
C_AHINT=$(count_field 12 1)
C_ARGS=$(count_field 13 1)
C_UI_TRUE=$(count_field 14 "true")
C_UI_FALSE=$(count_field 14 "false")
C_PATHS=$(count_field 15 1)
C_AT=$(count_field 16 1)
C_MODEL_SET=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $18!="empty"' | wc -l | tr -d ' ')
C_EFFORT=$(count_field 19 1)
C_CTX_SET=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $20!="empty"' | wc -l | tr -d ' ')
C_AGENT=$(count_field 21 1)
C_SHELL=$(count_field 22 1)
C_HOOKS=$(count_field 23 1)
C_LIC=$(count_field 24 1)
C_COMPAT=$(count_field 25 1)
C_META=$(count_field 26 1)
C_DMI_TRUE=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $6=="1"' | wc -l | tr -d ' ')

echo "| Category | Field | Adopted | Rate |"
echo "|---------|-----------|------|--------|"
echo "| Identity | name | $C_NAME / $NON_RULE | $(pct $C_NAME)% |"
echo "| Identity | description | $C_DESC / $NON_RULE | $(pct $C_DESC)% |"
echo "| Identity | when_to_use | $C_WTU / $NON_RULE | $(pct $C_WTU)% |"
echo "| Arguments | argument-hint | $C_AHINT / $NON_RULE | $(pct $C_AHINT)% |"
echo "| Arguments | arguments | $C_ARGS / $NON_RULE | $(pct $C_ARGS)% |"
echo "| Firing control | disable-model-invocation: true | $C_DMI_TRUE / $NON_RULE | $(pct $C_DMI_TRUE)% |"
echo "| Firing control | user-invocable: true | $C_UI_TRUE / $NON_RULE | $(pct $C_UI_TRUE)% |"
echo "| Firing control | user-invocable: false | $C_UI_FALSE / $NON_RULE | $(pct $C_UI_FALSE)% |"
echo "| Firing control | paths | $C_PATHS / $NON_RULE | $(pct $C_PATHS)% |"
echo "| Execution | allowed-tools | $C_AT / $NON_RULE | $(pct $C_AT)% |"
echo "| Execution | model (set) | $C_MODEL_SET / $NON_RULE | $(pct $C_MODEL_SET)% |"
echo "| Execution | effort | $C_EFFORT / $NON_RULE | $(pct $C_EFFORT)% |"
echo "| Execution | context (set) | $C_CTX_SET / $NON_RULE | $(pct $C_CTX_SET)% |"
echo "| Execution | agent | $C_AGENT / $NON_RULE | $(pct $C_AGENT)% |"
echo "| Execution | shell | $C_SHELL / $NON_RULE | $(pct $C_SHELL)% |"
echo "| Execution | hooks | $C_HOOKS / $NON_RULE | $(pct $C_HOOKS)% |"
echo "| Open Standard | license | $C_LIC / $NON_RULE | $(pct $C_LIC)% |"
echo "| Open Standard | compatibility | $C_COMPAT / $NON_RULE | $(pct $C_COMPAT)% |"
echo "| Open Standard | metadata | $C_META / $NON_RULE | $(pct $C_META)% |"

# ---- Axis 3: description routing format --------------------------------------
echo ""
echo "## Axis 3: description routing format"
echo ""
echo "Based on official Perplexity findings. Displayed as feedback indicators, not surface word-match scoring (no score is computed). Final precision judgment is deferred to Axis 4 (eval)."
echo ""

# "Use when" format adoption rate
C_USE_WHEN=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $27=="1"' | wc -l | tr -d ' ')
C_NEG=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $28=="1"' | wc -l | tr -d ' ')
C_LONG=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $29=="1"' | wc -l | tr -d ' ')

echo "### Summary (skill / agent / command only, N=${NON_RULE})"
echo ""
echo "| Indicator | Count | Rate |"
echo "|------|------|-----|"
echo "| Starts with \"Use when...\" | $C_USE_WHEN / $NON_RULE | $(pct $C_USE_WHEN)% |"
echo "| Has negative examples | $C_NEG / $NON_RULE | $(pct $C_NEG)% |"
echo "| description too long (> 250 chars, ≈ over 50 words) | $C_LONG / $NON_RULE | $(pct $C_LONG)% |"

echo ""
echo "### ⚠️ Warn: no negative examples (no explicit load-suppression examples near the boundary)"
echo ""
echo "Official Perplexity guidance treats **negative examples as the most important primary signal**."
echo "Borderline cases become prone to mis-firing, so state explicit anti-triggers in the description, e.g. \"do not use when\", \"X is sufficient\", \"out of scope\", \"dedicated to\"."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $28=="0" {print $1"\t"$2"\t"$3}')
if [ -n "$TBL" ]; then
    echo "| Type | File | desc_len |"
    echo "|------|------|----------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path desc_len; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s |\n" "$type" "$short" "$desc_len"
    done
else
    echo "(none — every skill has negative examples)"
fi

echo ""
echo "### ⚠️ Warn: description too long (> 250 chars, ≈ over 50 words)"
echo ""
echo "Bloats index-layer tokens and adds noise to routing decisions. Compress to the essentials and move details into the SKILL.md body."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $29=="1" {print $1"\t"$2"\t"$3}')
if [ -n "$TBL" ]; then
    echo "| Type | File | desc_len |"
    echo "|------|------|----------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path desc_len; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s |\n" "$type" "$short" "$desc_len"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ℹ️ Info: \"Use when...\" format not adopted"
echo ""
echo "The official Perplexity style recommends the \"Use when [the user is trying to ...]\" format."
echo "Even for Japanese-language skills, leading with an equivalent \"use when\" pattern may improve routing precision."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1!="rule" && $27=="0" {print $1"\t"$2}')
if [ -n "$TBL" ]; then
    echo "| Type | File |"
    echo "|------|------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s |\n" "$type" "$short"
    done
else
    echo "(none — every skill adopts the Use when format)"
fi

# ---- Axis 2: body structural validity ----------------------------------------
echo ""
echo "## Axis 2: body structural validity"
echo ""
echo "### SKILL.md over 500 lines (recommended cap)"
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$4 > 500 && $1!="rule" {print $1"\t"$2"\t"$4}')
if [ -n "$TBL" ]; then
    echo "| Type | File | Lines |"
    echo "|------|------|-------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path body_lines; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s |\n" "$type" "$short" "$body_lines"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ❌ Critical: broken references (link target file missing)"
echo ""
echo "Links of the form \`[text](references/foo.md)\` in the body whose target file does not exist."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$31 > 0 {print $1"\t"$2"\t"$31"\t"$30}')
if [ -n "$TBL" ]; then
    echo "| Type | File | Broken / Total |"
    echo "|------|------|----------------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path broken total; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s / %s |\n" "$type" "$short" "$broken" "$total"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ℹ️ Info: 3-layer progressive loading adoption"
echo ""
echo "Whether the skill directory has a \`references/\` subdirectory. For large skills the 3-layer Index → Load → Runtime split is recommended."
echo ""
C_REFDIR=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="skill" && $32=="1"' | wc -l | tr -d ' ')
echo "Skills with a references/ directory: ${C_REFDIR} / ${TOTAL_SKILL}"
echo ""
echo "#### Split-recommended candidates (over 500 lines OR over 1,000 tokens, without references/)"
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="skill" && $32=="0" && ($4>500 || $5>1000) {print $2"\t"$4"\t"$5}')
if [ -n "$TBL" ]; then
    echo "| File | Lines | Tokens |"
    echo "|------|-------|--------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r path lines tokens; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s |\n" "$short" "$lines" "$tokens"
    done
else
    echo "(none — every large skill already adopts references/)"
fi

echo ""
echo "### Token overage (warn=500 / hard=1000, body estimate)"
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$5 > 500 {print $1"\t"$2"\t"$5}')
if [ -n "$TBL" ]; then
    echo "| Type | File | Tokens | Status |"
    echo "|------|------|--------|--------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path body_tokens; do
        if [ "$body_tokens" -gt 1000 ]; then
            st="❌ HARD"
        else
            st="⚠️  WARN"
        fi
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s | %s |\n" "$type" "$short" "$body_tokens" "$st"
    done
else
    echo "✓ none"
fi

# ---- Explicit-invocation-only skills ------------------------------------------
echo ""
echo "## Explicit-invocation-only skills (disable-model-invocation: true)"
echo ""
echo "These are never auto-fired by Claude and run only via the user's explicit \`/skill-name\` invocation."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$6=="1" {print $1"\t"$2}')
if [ -n "$TBL" ]; then
    echo "| Type | File |"
    echo "|------|------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s |\n" "$type" "$short"
    done
else
    echo "✓ none"
fi

# ---- Axis 7: generality evaluation (static detection) --------------------------
echo ""
echo "## Axis 7: generality evaluation (static regex)"
echo ""
echo "Detection to delineate public distribution / in-org use / personal use. Agent judgments (business-knowledge dependence / language dependence / license) are handled separately, tied to Phase E."
echo ""
echo "**Generality score**:"
echo "- **Generic**: 0 violations, works in every environment"
echo "- **Light-locked**: minor dependencies (OS-specific commands, etc.) — warning"
echo "- **Locked**: personal names / org names / absolute paths present — error, must fix"
echo ""

# Per-file score (OS-specific → Light, absolute paths / emails → Locked)
echo "### Summary"
echo ""
C_LOCKED=$(printf "%s\n" "$DATA" | awk -F'\t' '$33>0 || $38>0' | wc -l | tr -d ' ')
C_LIGHT=$(printf "%s\n" "$DATA" | awk -F'\t' '$33==0 && $38==0 && ($35>0 || $36>0 || $37>0)' | wc -l | tr -d ' ')
TOTAL_ALL=$(printf "%s\n" "$DATA" | wc -l | tr -d ' ')
C_GENERIC=$((TOTAL_ALL - C_LOCKED - C_LIGHT))

echo "| Score | Count | Rate |"
echo "|--------|------|-----|"
[ "$TOTAL_ALL" -gt 0 ] && {
    echo "| Generic | $C_GENERIC / $TOTAL_ALL | $(awk -v n=$C_GENERIC -v d=$TOTAL_ALL 'BEGIN{printf "%d", n*100/d}')% |"
    echo "| Light-locked | $C_LIGHT / $TOTAL_ALL | $(awk -v n=$C_LIGHT -v d=$TOTAL_ALL 'BEGIN{printf "%d", n*100/d}')% |"
    echo "| Locked | $C_LOCKED / $TOTAL_ALL | $(awk -v n=$C_LOCKED -v d=$TOTAL_ALL 'BEGIN{printf "%d", n*100/d}')% |"
}

echo ""
echo "### ❌ Locked: absolute paths / emails detected (must fix; breaks public distribution)"
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$33>0 || $38>0 {print $1"\t"$2"\t"$33"\t"$38}')
if [ -n "$TBL" ]; then
    echo "| Type | File | abs_path | email |"
    echo "|------|------|----------|-------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path absp em; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s | %s |\n" "$type" "$short" "$absp" "$em"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ⚠️ Warn: proprietary names (registry-driven)"
echo ""
echo "Names matched against the egress name registry (~/.claude/banto-name-registry). Without a registry this check is a no-op — set one up to detect internal/client names in docs."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$34>0 {print $1"\t"$2"\t"$34}')
if [ -n "$TBL" ]; then
    echo "| Type | File | proj_name hits |"
    echo "|------|------|------------------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path c; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s |\n" "$type" "$short" "$c"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ⚠️ Light-locked: OS-specific commands detected"
echo ""
echo "Commands specific to Mac / Windows / Linux. Consider fallbacks for cross-platform distribution."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$35>0 || $36>0 || $37>0 {print $1"\t"$2"\t"$35"\t"$36"\t"$37}')
if [ -n "$TBL" ]; then
    echo "| Type | File | Mac | Win | Linux |"
    echo "|------|------|-----|-----|-------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path mac win lin; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s | %s | %s |\n" "$type" "$short" "$mac" "$win" "$lin"
    done
else
    echo "✓ none"
fi

# ---- Axis 14: content hygiene --------------------------------------------------
echo ""
echo "## Axis 14: content hygiene (no leaked specifics / pasted run output)"
echo ""
echo "Detects content that should never live in skill/agent/rule documents:"
echo "- **Pasted run output / session debris**: terminal result lines (\`exit=N\`, ✓/✗ result lines, \"ALL PASS\"), task-notification fragments (subagent_tokens / duration_ms), tool tmp paths (/private/tmp/claude\\*, /var/folders/), full datetime log lines."
echo "- **Proprietary names**: covered by the registry-driven check above (Axis 7 Warn table)."
echo ""
echo "Hits are **Warn-level**: review each — intentional display-format specs (e.g. a documented ✓-summary template) are fine; pasted dogfood output is not."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$47>0 {print $1"\t"$2"\t"$47}')
if [ -n "$TBL" ]; then
    echo "| Type | File | runlog hits |"
    echo "|------|------|-------------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path c; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s | %s |\n" "$type" "$short" "$c"
    done
else
    echo "(none — clean)"
fi

# ---- Axis 5: HeavySkill -------------------------------------------------------
echo ""
echo "## Axis 5: HeavySkill 4-component adoption"
echo ""
echo "Whether the body exhibits all 4 components — Activation Conditions / Parallel Protocol / Deliberation / Output Constraints — as **literal headers OR semantic equivalents** (genuine fan-out skills implement them in prose, not under the literal headings). Skills listed below are **candidates** that show all 4; the Axis 5 agent pass confirms applicability (recommend / fine-as-is / mis-applied). An empty list means no skill exhibits the full structure — it is not by itself a defect."
echo "Source: arxiv 2605.02396. Skill design guidance for complex reasoning tasks."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$8=="1" && $1!="rule" {print $1"\t"$2}')
if [ -n "$TBL" ]; then
    echo "| Type | File |"
    echo "|------|------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s |\n" "$type" "$short"
    done
else
    echo "✓ none"
fi

# ---- Axis 6 material: skill classification prefix --------------------------------
echo ""
echo "## Axis 6 material: skill classification prefix adoption"
echo ""
echo "Whether the body declares \`**WORKFLOW SKILL**\` / \`**UTILITY SKILL**\` / \`**ANALYSIS SKILL**\`."
echo "Used as material for domain categorization (leveraged by the Axis 6 disambiguation matrix)."
echo ""
TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$7=="1" && $1!="rule" {print $1"\t"$2}')
if [ -n "$TBL" ]; then
    echo "| Type | File |"
    echo "|------|------|"
    printf "%s\n" "$TBL" | while IFS=$(printf '\t') read -r type path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | %s |\n" "$type" "$short"
    done
else
    echo "✓ none"
fi

echo ""
echo "## Axis 9: Layer 3 harness-engineering consistency"
echo ""
echo "Source: harness-engineering conceptual framework (internal audit reference)."
echo "Rule without \`paths:\` whose body mentions extensions / path globs → path-scoping recommended."
echo "Rule body with enforcement wording (must / forbidden / MUST / NEVER) → candidate for deterministic hook enforcement."
echo ""

echo "### ⚠️ Warning: path-scoping recommended (rules only)"
echo ""
PS_TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="rule" && $39=="1" {print $2}')
if [ -n "$PS_TBL" ]; then
    echo "| File | Impact |"
    echo "|------|------|"
    printf "%s\n" "$PS_TBL" | while read -r path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | Always injected → context bloat. Recommend switching to conditional injection via \`paths:\` frontmatter |\n" "$short"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ℹ️ Info: hook enforce candidates (rules only)"
echo ""
echo "The rule contains enforcement wording, but rules are obeyed probabilistically (AGENTIF: tool constraint 43.2%). If it can be converted into a deterministic check around tool calls, consider promoting it to a hook (AgentSpec: 90-100% blocking)."
echo ""
HC_TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="rule" && $40=="1" {print $2}')
if [ -n "$HC_TBL" ]; then
    echo "| File | Consideration |"
    echo "|------|---------|"
    printf "%s\n" "$HC_TBL" | while read -r path; do
        short=$(printf "%s" "$path" | sed 's|^\./||')
        printf "| %s | Contains enforcement wording (must / forbidden / MUST / NEVER). Room to leverage permission deny / PreToolUse hooks |\n" "$short"
    done
else
    echo "✓ none"
fi

echo ""
echo "## Axis 9 extension: hooks consistency"
echo ""
echo "Scans hooks/*.sh and their registration status in hooks.json. A starting point for manually reviewing whether a hook provides deterministic enforcement for rules with \`rule_hard_constraint=1\`."
echo ""

echo "### Hook list (event / matcher / block & warn patterns)"
echo ""
HOOK_TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="hook" {print $2"\t"$41"\t"$42"\t"$43"\t"$44"\t"$4}')
if [ -n "$HOOK_TBL" ]; then
    echo "| Hook | Event | Matcher | Blocks | Warns | Lines |"
    echo "|------|-------|---------|--------|-------|-------|"
    printf "%s\n" "$HOOK_TBL" | while IFS=$(printf '\t') read -r path event matcher blocks warns lines; do
        short=$(printf "%s" "$path" | sed 's|^\./||; s|.*/hooks/||')
        [ -z "$event" ] && event="-"
        [ -z "$matcher" ] && matcher="-"
        bk="-"; [ "$blocks" = "1" ] && bk="✅"
        wn="-"; [ "$warns" = "1" ] && wn="✅"
        printf "| %s | %s | %s | %s | %s | %s |\n" "$short" "$event" "$matcher" "$bk" "$wn" "$lines"
    done
else
    echo "✓ none"
fi

echo ""
echo "### ❌ Critical: hook scripts not registered in hooks.json"
echo ""
echo "Scripts under hooks/ that are not bound to an event in hooks.json. Possibly dead code or a bug."
echo ""
UNREG_TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="hook" && $41=="unregistered" {print $2}')
if [ -n "$UNREG_TBL" ]; then
    echo "| Hook |"
    echo "|------|"
    printf "%s\n" "$UNREG_TBL" | while read -r path; do
        short=$(printf "%s" "$path" | sed 's|.*/hooks/||')
        printf "| %s |\n" "$short"
    done
else
    echo "(none — every hook is registered)"
fi

echo ""
echo "### ⚠️ Warn: PreToolUse hooks without a blocking pattern"
echo ""
echo "PreToolUse hooks earn their value when they can deterministically block tool execution. A PreToolUse hook without a blocking pattern such as exit 2 may amount to little more than an annotation."
echo ""
WARN_TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="hook" && $41=="PreToolUse" && $43=="0" {print $2"\t"$42}')
if [ -n "$WARN_TBL" ]; then
    echo "| Hook | Matcher |"
    echo "|------|---------|"
    printf "%s\n" "$WARN_TBL" | while IFS=$(printf '\t') read -r path matcher; do
        short=$(printf "%s" "$path" | sed 's|.*/hooks/||')
        printf "| %s | %s |\n" "$short" "$matcher"
    done
else
    echo "(none — every PreToolUse hook has a blocking pattern)"
fi

echo ""
echo "### 🔍 Coverage check: hard_constraint rules × hooks cross-reference"
echo ""
echo "Manually review whether a hook deterministically enforces the constraint implied by each rule with \`rule_hard_constraint=1\`. Fully automatic matching is hard (semantic judgment), so both sides are listed for comparison."
echo ""
HC_RULES=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="rule" && $40=="1" {print $2}')
BLOCK_HOOKS=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="hook" && $43=="1" {print $2"\t"$41"\t"$42}')

if [ -n "$HC_RULES" ]; then
    echo "**Rules with hard_constraint:**"
    echo ""
    printf "%s\n" "$HC_RULES" | while read -r p; do
        short=$(printf "%s" "$p" | sed 's|.*/rules/||')
        printf -- "- %s\n" "$short"
    done
    echo ""
fi

if [ -n "$BLOCK_HOOKS" ]; then
    echo "**Hooks with a blocking pattern (exit 2, etc.):**"
    echo ""
    echo "| Hook | Event | Matcher |"
    echo "|------|-------|---------|"
    printf "%s\n" "$BLOCK_HOOKS" | while IFS=$(printf '\t') read -r path event matcher; do
        short=$(printf "%s" "$path" | sed 's|.*/hooks/||')
        printf "| %s | %s | %s |\n" "$short" "$event" "$matcher"
    done
else
    echo "(none — no blocking-pattern hooks implemented)"
fi

echo ""
echo "**Manual review checklist**:"
echo "- Can each prohibition in the rules above be stopped by one of the hooks above at PreToolUse / PostToolUse time?"
echo "- For rules with improvement headroom from AGENTIF (tool constraint 43.2%) to AgentSpec (90-100% blocking via hooks), consider promoting them to hooks"
echo ""

echo ""
echo "## Axis 10: ODD (Operational Design Domain) adoption"
echo ""
echo "Source: layer-4 operations-engineering conceptual framework + ODD spec (internal audit reference)."
echo "Whether each skill has odd.yaml and whether autonomy_level is correctly declared as L0-L5."
echo ""

# ODD adoption rate
ODD_TOTAL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="skill"' | wc -l | tr -d ' ')
ODD_APPLIED=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="skill" && $45=="1"' | wc -l | tr -d ' ')
[ "$ODD_TOTAL" = "0" ] && ODD_TOTAL=1

echo "### Summary"
echo ""
echo "| Indicator | Value |"
echo "|------|-----|"
echo "| Skills with ODD applied | $ODD_APPLIED / $ODD_TOTAL ($(awk -v n=$ODD_APPLIED -v d=$ODD_TOTAL 'BEGIN{printf "%d", n*100/d}')%) |"

# autonomy_level distribution
for lv in L0 L1 L2 L3 L4 L5; do
    c=$(printf "%s\n" "$DATA" | awk -F'\t' -v lv="$lv" '$1=="skill" && $46==lv' | wc -l | tr -d ' ')
    [ "$c" -gt 0 ] && echo "| autonomy_level: $lv | $c |"
done

echo ""
echo "### ⚠️ Warn: skills without ODD"
echo ""
echo "Skills lacking odd.yaml. Optional for L0 lightweight utility skills (10-line rule); recommended for L1-L3."
echo ""
NO_ODD_TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="skill" && $45=="0" {print $2}')
if [ -n "$NO_ODD_TBL" ]; then
    echo "| Skill |"
    echo "|-------|"
    printf "%s\n" "$NO_ODD_TBL" | while read -r path; do
        name=$(printf "%s" "$path" | sed -E 's|.*/skills/([^/]+)/SKILL\.md|\1|')
        printf "| %s |\n" "$name"
    done
else
    echo "(none — every skill has ODD applied)"
fi

echo ""
echo "### ❌ Critical: autonomy_level is L4 / L5"
echo ""
echo "banto covers L0-L3 only. Skills at L4+ should be split into a separate plugin (\`banto-autonomy\`)."
echo ""
L45_TBL=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="skill" && ($46=="L4" || $46=="L5") {print $2"\t"$46}')
if [ -n "$L45_TBL" ]; then
    echo "| Skill | Level |"
    echo "|-------|-------|"
    printf "%s\n" "$L45_TBL" | while IFS=$(printf '\t') read -r path lv; do
        name=$(printf "%s" "$path" | sed -E 's|.*/skills/([^/]+)/SKILL\.md|\1|')
        printf "| %s | %s |\n" "$name" "$lv"
    done
else
    echo "(none — L0-L3 only, per banto policy)"
fi

echo ""
echo "### ℹ️ Info: autonomy_level not set (odd.yaml exists but level extraction failed)"
echo ""
EMPTY_LV=$(printf "%s\n" "$DATA" | awk -F'\t' '$1=="skill" && $45=="1" && $46=="empty" {print $2}')
if [ -n "$EMPTY_LV" ]; then
    echo "| Skill |"
    echo "|-------|"
    printf "%s\n" "$EMPTY_LV" | while read -r path; do
        name=$(printf "%s" "$path" | sed -E 's|.*/skills/([^/]+)/SKILL\.md|\1|')
        printf "| %s |\n" "$name"
    done
else
    echo "✓ none"
fi

echo ""
echo "## References"
echo ""
echo "- Evaluation criteria (axis definitions): \`skills/plugin-audit/references/scoring.md\`"
echo "- Background research (official plugin docs / HeavySkill / skill routing) and the multi-axis"
echo "  retirement decision are internal audit references."
