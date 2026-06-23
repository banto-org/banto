#!/bin/sh
# plugin-audit-collect.sh
# Parses the frontmatter and body of skills / agents / rules / commands and
# outputs the metrics needed for the static structural audit as TSV.
#
# 2026-05-14: waza-style Sensei scoring (Low/Medium/Medium-High/High) was retired.
# Details: skills/plugin-audit/references/scoring.md (axis definitions)
#          .ai-context/decisions/2026-05-14_plugin-audit-quality-perfect-score_*.md
#
# Official basis: .ai-context/docs/research/2026-05-10_official-plugin-docs-comprehensive.md
# Internal refs:  2026-05-10_microsoft-waza.md / 2026-05-10_arxiv-2605-02396-heavyskill.md
#
# Usage:
#   ./plugin-audit-collect.sh [PLUGIN_DIR]
#   PLUGIN_DIR defaults to the current directory.
#
# Output columns (TSV):
#   Base metrics (material for Axis 2 / 5 / 6):
#     1=type 2=path 3=desc_len 4=body_lines 5=body_tokens
#     6=disable_invocation 7=has_waza_prefix 8=has_heavyskill
#   Axis 1: official 19-field coverage:
#     9=has_name 10=has_description 11=has_when_to_use
#     12=has_argument_hint 13=has_arguments
#     14=user_invocable_value (true/false/empty)
#     15=has_paths 16=has_allowed_tools
#     17=allowed_tools_has_comma
#     18=model_value (opus/sonnet/haiku/other/empty)
#     19=has_effort
#     20=context_value (fork/main/other/empty)
#     21=has_agent 22=has_shell 23=has_hooks
#     24=has_license 25=has_compatibility 26=has_metadata
#   Axis 3: description routing format (not scored; Warn / Info indicators only):
#     27=desc_starts_use_when (1/0)
#     28=has_negative_example (1/0)
#     29=desc_long_warn (1/0, desc_len > 250 chars)
#   Axis 2 extension: reference validity + 3-layer structure:
#     30=ref_count (number of references/ links in the body)
#     31=ref_broken_count (links whose target file is missing; subset of ref_count)
#     32=has_references_dir (references/ subdirectory exists = 3-layer structure adopted)
#   Axis 7: generality evaluation (static regex only; Agent judgment is Phase E):
#     33=abs_path_count (absolute paths: /Users/ / C:\\Users\\ / /home/)
#     34=proj_name_count (proprietary names matched via the egress name registry; empty registry = 0)
#     35=tool_mac_count (Mac-only: open -a / pbcopy / pbpaste / osascript / defaults / launchctl)
#     36=tool_win_count (Windows-only: winget / choco / cmd /c / .exe extension)
#     37=tool_linux_count (Linux-only: apt-get / systemctl / yum / dnf)
#     38=email_count (email addresses detected)
#   Axis 9: Layer 3 harness-engineering consistency (meaningful for rules only; always 0 for skill/agent):
#     39=rule_should_path_scope (rule body mentions extensions/globs/paths & has_paths=0 → path-scoping recommended)
#     40=rule_hard_constraint (rule body has enforcement wording (JP imperatives / MUST / NEVER, etc.) → hook enforce candidate)
#   Axis 9 extension (meaningful for hooks only; otherwise 0/empty):
#     41=hook_event (SessionStart/UserPromptSubmit/PreToolUse/PostToolUse/Stop/PreCompact/unregistered)
#     42=hook_matcher (tool the hook reacts to: Bash/Write|Edit/Task/* etc.)
#     43=hook_blocks (script body has a blocking pattern such as exit 2 / "BLOCKED")
#     44=hook_warns (script body has a warning pattern such as "WARN" / stderr output)
#   Axis 10: ODD (Operational Design Domain) adoption (skills only):
#     45=has_odd_yaml (skills/{name}/odd.yaml exists)
#     46=odd_autonomy_level (autonomy_level in odd.yaml: L0-L5 / empty)

set -u
PLUGIN_DIR=${1:-.}

# ---- Plugin-root resolution (Axis 7 generality: audit ANY plugin layout, not just banto) -------
# collect scans $PLUGIN_DIR/{skills,agents,commands,hooks,templates/rules}. Marketplace-installed
# plugins sometimes nest content under a child dir (e.g. <cache>/<plugin>/unknown/), so pointing at
# the install root would silently find nothing. If the given dir has no auditable components but a
# single child does, descend to it. If nothing is found anywhere, warn (stderr) so an empty report
# is never mistaken for a clean one.
_pa_has_components() {  # $1 = dir
    [ -d "$1/skills" ] || [ -d "$1/agents" ] || [ -d "$1/commands" ] || [ -d "$1/hooks" ] \
        || [ -d "$1/templates/rules" ] || [ -f "$1/.claude-plugin/plugin.json" ] || [ -f "$1/plugin.json" ]
}
if ! _pa_has_components "$PLUGIN_DIR"; then
    for _pa_c in "$PLUGIN_DIR"/*/; do
        [ -d "$_pa_c" ] || continue
        if _pa_has_components "${_pa_c%/}"; then PLUGIN_DIR="${_pa_c%/}"; break; fi
    done
fi
if ! _pa_has_components "$PLUGIN_DIR"; then
    echo "plugin-audit: WARNING — no auditable components (skills/agents/commands/hooks/rules or plugin.json) under '$PLUGIN_DIR'. Is this the plugin root? The report below will be empty (NOT a clean pass)." >&2
fi

# ---- Detection pattern definitions (egrep-compatible) --------------------------
# i18n: the Japanese alternatives inside these patterns are detection logic
# (they match JP skill/rule wording) — do not translate.
WAZA_PREFIX_PAT='\*\*WORKFLOW SKILL\*\*|\*\*UTILITY SKILL\*\*|\*\*ANALYSIS SKILL\*\*'
# Each component matches the literal HeavySkill header OR a semantic-equivalent
# (genuine HeavySkills implement the 4 components in prose, not under literal headers).
# Final applicability is still agent-judged (Axis 5 = static detection + agent confirmation).
HEAVYSKILL_PAT_1='Activation Conditions|活性化条件|when to (use|route|fire)|どちらを使う|search vs|vs\.? *research|Subcommand|サブコマンド|execution modes?|division of'
HEAVYSKILL_PAT_2='Parallel Protocol|並列プロトコル|Parallel Reasoning|in parallel|並列で|fan.?out|run_in_background|Reviewer = Fresh Agent|model=(haiku|sonnet|opus)|model: .(haiku|sonnet|opus)|multiple .{0,15}[Aa]gents|[0-9]+[ -]*(in parallel|並列|agents)'
HEAVYSKILL_PAT_3='Deliberation|審議|Deliberation Prompt|reasoning step|Step [0-9]|Phase [0-9]|手順|ranking|scoring|スコアリング|tiers?|段階|Tier'
HEAVYSKILL_PAT_4='Output Constraints|出力制約|Output format|出力形式|report format|レポート|報告フォーマット|TL;DR|deliverable|出力フォーマット'

# Axis 3: description routing format
# "Use when" leading match (official Perplexity-style "Use when..." pattern; JP equivalents included)
USE_WHEN_PAT='^Use when|^Use for|^USE FOR|^use when'
# Negative-example keywords (explicit load-suppression examples near the boundary; JP + EN)
NEGATIVE_EXAMPLE_PAT='使ってはいけない|使わない|で十分|は別|対象外|不要|べきではない|専用|明示要求時のみ|発動しない|適用しない|DO NOT USE|禁止|だけなら|では発動しない|の方が良い|skip|スキップ|[Dd]o not use|[Dd]on'"'"'t use|is (sufficient|enough)|out of scope|not needed|should not|dedicated to|reserved for|never (auto-)?fires?|does not fire|no auto-fire|instead'

# Axis 7: generality evaluation (static regex only)
# Absolute paths: /Users/[name] / C:\Users\[name] / /home/[name]
ABS_PATH_PAT='/Users/[A-Za-z0-9_.-]+/|C:[\\/]Users[\\/]|/home/[A-Za-z0-9_.-]+/'
# Proprietary-name detection is REGISTRY-DRIVEN (Axis 7 / Axis 14): internal names must never
# be hardcoded in this (public) script. Literals come from the egress name registry
# (user scope, never committed). Absent registry → empty pattern → check is a no-op (fail-open).
NAME_REGISTRY="${BANTO_NAME_REGISTRY:-$HOME/.claude/banto-name-registry}"
PROJ_NAME_PAT=""
if [ -f "$NAME_REGISTRY" ]; then
    PROJ_NAME_PAT=$(grep -v '^[[:space:]]*#' "$NAME_REGISTRY" 2>/dev/null | grep -v '^re:' | grep -v '^[[:space:]]*$' | paste -sd'|' - 2>/dev/null)
fi

# Axis 14: content hygiene — pasted run output / session debris that should never live in docs
# (terminal result lines, task-notification fragments, tool tmp paths, full datetimes = log lines)
HYGIENE_RUNLOG_PAT='^exit=[0-9]|\bALL PASS\b|subagent_tokens|duration_ms=|/private/tmp/claude|/var/folders/|\(eval\):[0-9]|^✓ |^✗ |[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}'
# Mac-only commands
TOOL_MAC_PAT='\bopen[[:space:]]+-a\b|\bpbcopy\b|\bpbpaste\b|\bosascript\b|\bdefaults[[:space:]]+(read|write)\b|\blaunchctl\b'
# Windows-only commands / extensions
TOOL_WIN_PAT='\bwinget\b|\bchoco\b|\bcmd[[:space:]]+/c\b|\.exe\b|\bGet-Content\b|\bSet-Content\b|\bInvoke-Expression\b'
# Linux-only commands
TOOL_LINUX_PAT='\bapt-get\b|\bapt[[:space:]]+install\b|\bsystemctl\b|\byum[[:space:]]+install\b|\bdnf[[:space:]]+install\b|\bpacman[[:space:]]+-S\b'
# Email addresses
EMAIL_PAT='[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# Axis 9: Layer 3 harness-engineering consistency (rules only)
# Mentions of file types / path globs / specific file names (path-scoping candidate signal)
PATH_SCOPE_HINT_PAT='\.(ts|tsx|js|jsx|mjs|cjs|py|rs|go|rb|java|kt|swift|c|cpp|h|hpp|sh|bash|zsh|php|lua|dart|scala|vue|svelte|md|json|yaml|yml|toml|env|lock|sql|html|css|scss)\b|\bsrc/|\bapp/|\bpages/|\btests?/|\b__tests__/|\bapi/|package\.json|pyproject\.toml|Cargo\.toml|go\.mod|Gemfile|requirements\.txt'
# Enforcement wording (rule content that is a candidate for deterministic hook enforcement)
# i18n: JP imperatives (必ず/禁止/...) are detection logic — do not translate.
HARD_CONSTRAINT_PAT='必ず|禁止|してはいけない|やってはいけない|絶対に|\bMUST\b|\bNEVER\b|\bALWAYS\b|\bdo[[:space:]]+not\b|\bnever\b|\bmust\b|\balways\b'

# ---- Extract frontmatter description + when_to_use (CRLF / LF compatible) ------
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

# ---- Extract the frontmatter block (CRLF / LF compatible) ----------------------
extract_frontmatter() {
    awk '
        { gsub(/\r/, "") }
        BEGIN{n=0}
        /^---$/{n++; if(n==2)exit; next}
        n==1 {print}
    ' "$1"
}

# ---- Check whether a given field exists in the frontmatter (1/0) ---------------
field_exists() {
    # $1=frontmatter text, $2=field name
    printf "%s\n" "$1" | grep -E -q "^${2}:" 2>/dev/null && echo 1 || echo 0
}

# ---- Extract a given field's value from the frontmatter (single line, unquoted) -
field_value() {
    # $1=frontmatter text, $2=field name
    printf "%s\n" "$1" | awk -v field="$2" '
        $0 ~ ("^" field ":[[:space:]]*") {
            sub("^" field ":[[:space:]]*", "")
            sub(/^"/, ""); sub(/"$/, "")
            sub(/^'\''/, ""); sub(/'\''$/, "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }
    '
}

# ---- Extract the body (after frontmatter) (CRLF / LF compatible) ---------------
extract_body() {
    awk '
        { gsub(/\r/, "") }
        BEGIN{n=0}
        /^---$/{n++; next}
        n>=2 || (n==0 && NR>1) {print}
    ' "$1"
}

# ---- Normalize the model value into 5 buckets ----------------------------------
normalize_model() {
    case "$1" in
        ""|null) echo "empty" ;;
        opus|*opus*) echo "opus" ;;
        sonnet|*sonnet*) echo "sonnet" ;;
        haiku|*haiku*) echo "haiku" ;;
        inherit) echo "inherit" ;;
        *) echo "other" ;;
    esac
}

# ---- Normalize the context value ------------------------------------------------
normalize_context() {
    case "$1" in
        ""|null) echo "empty" ;;
        fork) echo "fork" ;;
        main) echo "main" ;;
        *) echo "other" ;;
    esac
}

# ---- Normalize the user-invocable value ------------------------------------------
normalize_user_invocable() {
    case "$1" in
        true) echo "true" ;;
        false) echo "false" ;;
        *) echo "empty" ;;
    esac
}

# ---- File scan -------------------------------------------------------------------
collect_file() {
    TYPE="$1"
    FILE="$2"

    if [ "$TYPE" = "rule" ]; then
        DESC=""
        DESC_LEN=0
        # Rules have no description, but since Layer 3 path-scoping they may carry frontmatter (paths:)
        FM=$(extract_frontmatter "$FILE")
        if [ -n "$FM" ]; then
            BODY=$(extract_body "$FILE")
        else
            BODY=$(cat "$FILE")
        fi
    else
        DESC=$(extract_desc "$FILE" | tr -d '\n')
        DESC_LEN=$(printf "%s" "$DESC" | wc -m | tr -d ' ')
        BODY=$(extract_body "$FILE")
        FM=$(extract_frontmatter "$FILE")
    fi

    BODY_LINES=$(printf "%s" "$BODY" | wc -l | tr -d ' ')
    BODY_CHARS=$(printf "%s" "$BODY" | wc -m | tr -d ' ')
    BODY_TOKENS=$((BODY_CHARS / 4))

    has_pat() {
        printf "%s" "$1" | grep -E -q "$2" 2>/dev/null && echo 1 || echo 0
    }

    # Base metrics ---------------------------------------------------------------
    HAS_WAZA=$(has_pat "$BODY" "$WAZA_PREFIX_PAT")
    HS1=$(has_pat "$BODY" "$HEAVYSKILL_PAT_1")
    HS2=$(has_pat "$BODY" "$HEAVYSKILL_PAT_2")
    HS3=$(has_pat "$BODY" "$HEAVYSKILL_PAT_3")
    HS4=$(has_pat "$BODY" "$HEAVYSKILL_PAT_4")
    if [ "$HS1" = "1" ] && [ "$HS2" = "1" ] && [ "$HS3" = "1" ] && [ "$HS4" = "1" ]; then
        HAS_HS=1
    else
        HAS_HS=0
    fi

    # Axis 1: 19-field coverage ---------------------------------------------------
    if [ "$TYPE" = "rule" ]; then
        # Rules normally have no frontmatter, but path-scoping may add paths:.
        # Other fields (name/description, etc.) do not exist for rules conceptually.
        HAS_NAME=0; HAS_DESC=0; HAS_WTU=0; HAS_AHINT=0; HAS_ARGS=0
        UI_VAL="empty"; DMI_VAL="0"; HAS_AT=0; AT_COMMA=0
        MODEL_VAL="empty"; HAS_EFFORT=0; CTX_VAL="empty"
        HAS_AGENT=0; HAS_SHELL=0; HAS_HOOKS=0
        HAS_LIC=0; HAS_COMPAT=0; HAS_META=0
        if [ -n "$FM" ]; then
            HAS_PATHS=$(field_exists "$FM" "paths")
        else
            HAS_PATHS=0
        fi
    else
        HAS_NAME=$(field_exists "$FM" "name")
        HAS_DESC=$(field_exists "$FM" "description")
        HAS_WTU=$(field_exists "$FM" "when_to_use")
        HAS_AHINT=$(field_exists "$FM" "argument-hint")
        HAS_ARGS=$(field_exists "$FM" "arguments")

        UI_RAW=$(field_value "$FM" "user-invocable")
        UI_VAL=$(normalize_user_invocable "$UI_RAW")

        DMI_RAW=$(field_value "$FM" "disable-model-invocation")
        if [ "$DMI_RAW" = "true" ]; then
            DMI_VAL="1"
        else
            DMI_VAL="0"
        fi

        HAS_PATHS=$(field_exists "$FM" "paths")
        HAS_AT=$(field_exists "$FM" "allowed-tools")

        # Does the allowed-tools value contain a comma? (detects the unofficial format)
        if [ "$HAS_AT" = "1" ]; then
            AT_VAL=$(field_value "$FM" "allowed-tools")
            if printf "%s" "$AT_VAL" | grep -q ','; then
                AT_COMMA=1
            else
                AT_COMMA=0
            fi
        else
            AT_COMMA=0
        fi

        MODEL_RAW=$(field_value "$FM" "model")
        MODEL_VAL=$(normalize_model "$MODEL_RAW")

        HAS_EFFORT=$(field_exists "$FM" "effort")

        CTX_RAW=$(field_value "$FM" "context")
        CTX_VAL=$(normalize_context "$CTX_RAW")

        HAS_AGENT=$(field_exists "$FM" "agent")
        HAS_SHELL=$(field_exists "$FM" "shell")
        HAS_HOOKS=$(field_exists "$FM" "hooks")

        HAS_LIC=$(field_exists "$FM" "license")
        HAS_COMPAT=$(field_exists "$FM" "compatibility")
        HAS_META=$(field_exists "$FM" "metadata")
    fi

    # Axis 3: description routing format ------------------------------------------
    if [ "$TYPE" = "rule" ]; then
        DESC_USE_WHEN=0; HAS_NEG=0; DESC_LONG=0
    else
        if printf "%s" "$DESC" | grep -E -q "$USE_WHEN_PAT" 2>/dev/null; then
            DESC_USE_WHEN=1
        else
            DESC_USE_WHEN=0
        fi
        if printf "%s" "$DESC" | grep -E -q "$NEGATIVE_EXAMPLE_PAT" 2>/dev/null; then
            HAS_NEG=1
        else
            HAS_NEG=0
        fi
        if [ "$DESC_LEN" -gt 250 ]; then
            DESC_LONG=1
        else
            DESC_LONG=0
        fi
    fi

    # Axis 2 extension: reference validity + 3-layer structure ---------------------
    BASE_DIR=$(dirname "$FILE")
    # Extract all references/ links in the body ([text](references/path) form)
    REFS=$(printf "%s" "$BODY" | grep -oE '\(references/[^) ]+\)' | sed -E 's/^\(//; s/\)$//')
    if [ -z "$REFS" ]; then
        REF_COUNT=0
        REF_BROKEN=0
    else
        REF_COUNT=$(printf "%s\n" "$REFS" | grep -c .)
        REF_BROKEN=0
        OLDIFS=$IFS
        IFS='
'
        for ref in $REFS; do
            if [ ! -f "$BASE_DIR/$ref" ]; then
                REF_BROKEN=$((REF_BROKEN + 1))
            fi
        done
        IFS=$OLDIFS
    fi

    if [ -d "$BASE_DIR/references" ]; then
        HAS_REFDIR=1
    else
        HAS_REFDIR=0
    fi

    # Axis 7: generality evaluation -------------------------------------------------
    count_pat() {
        # $1=haystack, $2=pattern
        printf "%s" "$1" | grep -oE "$2" 2>/dev/null | wc -l | tr -d ' '
    }
    # Rules are scanned over the full text as well (no frontmatter, body only)
    if [ "$TYPE" = "rule" ]; then
        AXIS7_TARGET="$BODY"
    else
        AXIS7_TARGET="$FM
$BODY"
    fi
    ABS_PATH_C=$(count_pat "$AXIS7_TARGET" "$ABS_PATH_PAT")
    if [ -n "$PROJ_NAME_PAT" ]; then
        PROJ_NAME_C=$(count_pat "$AXIS7_TARGET" "$PROJ_NAME_PAT")
    else
        PROJ_NAME_C=0
    fi
    HYGIENE_C=$(count_pat "$AXIS7_TARGET" "$HYGIENE_RUNLOG_PAT")
    TOOL_MAC_C=$(count_pat "$AXIS7_TARGET" "$TOOL_MAC_PAT")
    TOOL_WIN_C=$(count_pat "$AXIS7_TARGET" "$TOOL_WIN_PAT")
    TOOL_LINUX_C=$(count_pat "$AXIS7_TARGET" "$TOOL_LINUX_PAT")
    EMAIL_C=$(count_pat "$AXIS7_TARGET" "$EMAIL_PAT")

    # Axis 9: Layer 3 consistency (rules only; always 0 for skill/agent) -------------
    RULE_SHOULD_PATHSCOPE=0
    RULE_HARD_CONSTRAINT=0
    if [ "$TYPE" = "rule" ]; then
        # path-scoping candidate: no paths: & body mentions extensions/path globs
        if [ "$HAS_PATHS" = "0" ]; then
            if printf "%s" "$BODY" | grep -E -q "$PATH_SCOPE_HINT_PAT" 2>/dev/null; then
                RULE_SHOULD_PATHSCOPE=1
            fi
        fi
        # hook enforce candidate: enforcement wording present
        if printf "%s" "$BODY" | grep -E -q "$HARD_CONSTRAINT_PAT" 2>/dev/null; then
            RULE_HARD_CONSTRAINT=1
        fi
    fi

    # Axis 10: ODD adoption (skills only) ---------------------------------------------
    HAS_ODD=0
    ODD_LEVEL=""
    if [ "$TYPE" = "skill" ]; then
        ODD_FILE="$(dirname "$FILE")/odd.yaml"
        if [ -f "$ODD_FILE" ]; then
            HAS_ODD=1
            # Extract autonomy_level: L0-L5 only
            ODD_LEVEL=$(awk '
                /^autonomy_level:/{
                    sub(/^autonomy_level:[[:space:]]*/, "")
                    sub(/[[:space:]]*#.*$/, "")
                    sub(/^"/, ""); sub(/"$/, "")
                    sub(/[[:space:]]+$/, "")
                    print
                    exit
                }
            ' "$ODD_FILE")
            [ -z "$ODD_LEVEL" ] && ODD_LEVEL="empty"
        else
            ODD_LEVEL="empty"
        fi
    else
        ODD_LEVEL="empty"
    fi

    printf "%s\t%s\t%d\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%d\t%d\t%d\t%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%d\t%d\t%d\t%s\t%d\n" \
        "$TYPE" "$FILE" "$DESC_LEN" "$BODY_LINES" "$BODY_TOKENS" "$DMI_VAL" "$HAS_WAZA" "$HAS_HS" \
        "$HAS_NAME" "$HAS_DESC" "$HAS_WTU" "$HAS_AHINT" "$HAS_ARGS" \
        "$UI_VAL" "$HAS_PATHS" "$HAS_AT" "$AT_COMMA" \
        "$MODEL_VAL" "$HAS_EFFORT" "$CTX_VAL" \
        "$HAS_AGENT" "$HAS_SHELL" "$HAS_HOOKS" \
        "$HAS_LIC" "$HAS_COMPAT" "$HAS_META" \
        "$DESC_USE_WHEN" "$HAS_NEG" "$DESC_LONG" \
        "$REF_COUNT" "$REF_BROKEN" "$HAS_REFDIR" \
        "$ABS_PATH_C" "$PROJ_NAME_C" "$TOOL_MAC_C" "$TOOL_WIN_C" "$TOOL_LINUX_C" "$EMAIL_C" \
        "$RULE_SHOULD_PATHSCOPE" "$RULE_HARD_CONSTRAINT" \
        "" "" "0" "0" \
        "$HAS_ODD" "$ODD_LEVEL" "$HYGIENE_C"
}

# ---- Extract hook registrations from hooks.json --------------------------------
# Output: <script_basename>\t<event>\t<matcher> (one per line; multiple registrations supported)
# Simple awk parse without depending on jq (hooks.json has a known format + simple structure).
parse_hooks_json() {
    HJSON="$1"
    [ ! -f "$HJSON" ] && return 0
    awk '
        BEGIN{event=""; matcher=""}
        # Detect event keys ("SessionStart": [, "PreToolUse": [, ...)
        /^[[:space:]]+"[A-Z][A-Za-z]+":[[:space:]]*\[$/ {
            line=$0
            gsub(/[[:space:]"\[]/, "", line)
            sub(/:.*/, "", line)
            event=line
            matcher=""
            next
        }
        # Detect the matcher key
        /"matcher":[[:space:]]*"[^"]*"/ {
            line=$0
            sub(/.*"matcher":[[:space:]]*"/, "", line)
            sub(/".*/, "", line)
            matcher=line
            next
        }
        # Detect the command key (the actual script path)
        /"command":[[:space:]]*"[^"]*"/ {
            line=$0
            sub(/.*"command":[[:space:]]*"/, "", line)
            sub(/".*/, "", line)
            # ${CLAUDE_PLUGIN_ROOT}/hooks/foo.sh → extract foo.sh only
            sub(/.*\//, "", line)
            # "foo.sh arg" (registration with arguments) → strip trailing args
            sub(/[[:space:]].*$/, "", line)
            cmd=line
            mm = matcher
            if (mm == "") mm = "*"
            printf "%s\t%s\t%s\n", cmd, event, mm
        }
    ' "$HJSON"
}

# ---- Hook detection patterns ---------------------------------------------------
# i18n: 警告 (= "warning") inside HOOK_WARN_PAT is detection logic — do not translate.
HOOK_BLOCK_PAT='exit[[:space:]]+2|exit[[:space:]]+1|BLOCKED|\bdeny\b|\breject\b|\babort\b|\berror\b'
HOOK_WARN_PAT='WARN|⚠️|警告|stderr|>&2'

collect_hook() {
    FILE="$1"
    BASE=$(basename "$FILE")
    BODY=$(cat "$FILE" 2>/dev/null)
    BODY_LINES=$(printf "%s" "$BODY" | wc -l | tr -d ' ')
    BODY_CHARS=$(printf "%s" "$BODY" | wc -m | tr -d ' ')
    BODY_TOKENS=$((BODY_CHARS / 4))

    # Look up this hook's own registration in hooks.json
    REG=$(parse_hooks_json "$PLUGIN_DIR/hooks/hooks.json" | awk -F'\t' -v b="$BASE" '$1==b' | head -1)
    if [ -n "$REG" ]; then
        EVENT=$(printf "%s" "$REG" | awk -F'\t' '{print $2}')
        MATCHER=$(printf "%s" "$REG" | awk -F'\t' '{print $3}')
    else
        EVENT="unregistered"
        MATCHER="-"
    fi
    # Set empty matchers to "-" as well, to avoid TSV column misalignment
    [ -z "$MATCHER" ] && MATCHER="-"

    has_pat() {
        printf "%s" "$1" | grep -E -q "$2" 2>/dev/null && echo 1 || echo 0
    }

    HOOK_BLOCKS=$(has_pat "$BODY" "$HOOK_BLOCK_PAT")
    HOOK_WARNS=$(has_pat "$BODY" "$HOOK_WARN_PAT")

    # Axis 7: generality evaluation (hooks included)
    count_pat() {
        printf "%s" "$1" | grep -oE "$2" 2>/dev/null | wc -l | tr -d ' '
    }
    ABS_PATH_C=$(count_pat "$BODY" "$ABS_PATH_PAT")
    PROJ_NAME_C=$(count_pat "$BODY" "$PROJ_NAME_PAT")
    TOOL_MAC_C=$(count_pat "$BODY" "$TOOL_MAC_PAT")
    TOOL_WIN_C=$(count_pat "$BODY" "$TOOL_WIN_PAT")
    TOOL_LINUX_C=$(count_pat "$BODY" "$TOOL_LINUX_PAT")
    EMAIL_C=$(count_pat "$BODY" "$EMAIL_PAT")

    # The remaining columns carry little meaning for hooks, so fill with 0 / empty
    printf "hook\t%s\t0\t%d\t%d\t0\t0\t0\t0\t0\t0\t0\t0\tempty\t0\t0\t0\tempty\t0\tempty\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t%d\t%d\t%d\t%d\t%d\t%d\t0\t0\t%s\t%s\t%d\t%d\t0\tempty\t0\n" \
        "$FILE" "$BODY_LINES" "$BODY_TOKENS" \
        "$ABS_PATH_C" "$PROJ_NAME_C" "$TOOL_MAC_C" "$TOOL_WIN_C" "$TOOL_LINUX_C" "$EMAIL_C" \
        "$EVENT" "$MATCHER" "$HOOK_BLOCKS" "$HOOK_WARNS"
}

# ---- Header --------------------------------------------------------------------
printf "type\tpath\tdesc_len\tbody_lines\tbody_tokens\tdisable_invocation\thas_waza_prefix\thas_heavyskill\thas_name\thas_description\thas_when_to_use\thas_argument_hint\thas_arguments\tuser_invocable_value\thas_paths\thas_allowed_tools\tallowed_tools_has_comma\tmodel_value\thas_effort\tcontext_value\thas_agent\thas_shell\thas_hooks\thas_license\thas_compatibility\thas_metadata\tdesc_starts_use_when\thas_negative_example\tdesc_long_warn\tref_count\tref_broken_count\thas_references_dir\tabs_path_count\tproj_name_count\ttool_mac_count\ttool_win_count\ttool_linux_count\temail_count\trule_should_path_scope\trule_hard_constraint\thook_event\thook_matcher\thook_blocks\thook_warns\thas_odd_yaml\todd_autonomy_level\thygiene_runlog_count\n"

# ---- skill ------------------------------------------------------------------
find "$PLUGIN_DIR/skills" -name "SKILL.md" 2>/dev/null | sort | while read -r f; do
    collect_file "skill" "$f"
done

# ---- agent ------------------------------------------------------------------
find "$PLUGIN_DIR/agents" -maxdepth 2 -name "*.md" 2>/dev/null | sort | while read -r f; do
    collect_file "agent" "$f"
done

# ---- rule ------------------------------------------------------------------
find "$PLUGIN_DIR/templates/rules" -name "*.md" 2>/dev/null | sort | while read -r f; do
    collect_file "rule" "$f"
done

# ---- command ----------------------------------------------------------------
find "$PLUGIN_DIR/commands" -maxdepth 2 -name "*.md" 2>/dev/null | sort | while read -r f; do
    collect_file "command" "$f"
done

# ---- hook -------------------------------------------------------------------
find "$PLUGIN_DIR/hooks" -maxdepth 1 -name "*.sh" 2>/dev/null | sort | while read -r f; do
    collect_hook "$f"
done
