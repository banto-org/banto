#!/bin/sh
# plugin-audit-permissions.sh
# Axis 12 (permission-scope minimality) — deterministic static backing.
#
# For each skill, diff the declared `allowed-tools` (frontmatter) against the tools
# the SKILL.md body + references/ actually evidence:
#   - OVER-GRANT   : declared but no usage idiom found  → drop candidate
#   - UNDER-DECLARE: usage idiom found but not declared  → blocked at runtime (review)
#
# Usage is detected by idioms, not just the bare tool name, because SKILL.md bodies are
# prose, not code: Bash counts ``` ```bash ``` / `sh ...` / `$(...)`; Agent counts
# `subagent_type`; etc. Even so this is a CANDIDATE generator — the Axis 12 agent pass
# confirms (a prose-only skill that never names Read/Write can still legitimately use them).
# Scoped grants (`Bash(git:*)`) are matched on their base tool. Agent and Task are one tool.
#
# POSIX sh (macOS / Linux / WSL). Output: Markdown.
#
# Usage:
#   ./plugin-audit-permissions.sh [PLUGIN_DIR]   (PLUGIN_DIR defaults to the current directory)

set -u
PLUGIN_DIR=${1:-.}

# Canonical built-in tool tokens a skill may declare or use. MCP tools (mcp__*) are
# matched by their declared literal. Agent/Task collapse to one logical tool.
CANON_TOOLS="Read Write Edit MultiEdit NotebookEdit Glob Grep Bash BashOutput KillShell Agent Skill Workflow WebSearch WebFetch TodoWrite SlashCommand"
# Tools whose names double as common English verbs → under-declare is lower-confidence.
PROSE_NOISY="Read Write Edit"

# ---- Extract the frontmatter block (CRLF / LF compatible) ----------------------
extract_frontmatter() {
    awk '
        { gsub(/\r/, "") }
        BEGIN{n=0}
        /^---$/{n++; if(n==2)exit; next}
        n==1 {print}
    ' "$1"
}

# ---- Extract a given field value from the frontmatter (single line, unquoted) --
field_value() {
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

# ---- Strip a scoped qualifier and collapse the Agent/Task synonym --------------
base_tool() {
    _bt=$(printf '%s' "$1" | sed 's/(.*//')   # Bash(git:*) -> Bash
    case "$_bt" in Task) echo "Agent" ;; *) echo "$_bt" ;; esac
}

# ---- Is a tool (base name) evidenced in TEXT by name or usage idiom? ------------
tool_used() {
    # $1=base tool, $2=text
    case "$1" in
        Agent)  _tu_pat='\b(Agent|Task)\b|subagent_type' ;;
        Bash)   _tu_pat='\bBash\b|```[[:space:]]*(bash|sh|shell)|\$\(|(^|[^[:alnum:]])sh[[:space:]]+"?\$|(^|[^[:alnum:]])sh[[:space:]]+(plugins|scripts)/' ;;
        mcp__*) _tu_pat=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9_]/./g') ;;
        *)      _tu_pat="\\b$1\\b" ;;
    esac
    printf "%s" "$2" | grep -Eq "$_tu_pat"
}

in_list() {
    for _il in $2; do [ "$_il" = "$1" ] && return 0; done
    return 1
}

# ---- Header --------------------------------------------------------------------
printf '## Axis 12a/12b — allowed-tools vs actual usage (static)\n\n'
printf '| Skill | Declared | 12a Over-grant (declared, unused) | 12b Under-declare (used, undeclared = runtime block) |\n'
printf '|---|---|---|---|\n'

find "$PLUGIN_DIR/skills" -name "SKILL.md" 2>/dev/null | sort | while read -r f; do
    skill=$(basename "$(dirname "$f")")
    FM=$(extract_frontmatter "$f")
    AT_RAW=$(field_value "$FM" "allowed-tools")

    # usage surface = body + references/ (frontmatter is excluded on purpose: a tool named
    # only in the allowed-tools line is a declaration, not evidence of use)
    BODY=$(extract_body "$f")
    refdir="$(dirname "$f")/references"
    if [ -d "$refdir" ]; then
        SURFACE="$BODY
$(cat "$refdir"/*.md 2>/dev/null)"
    else
        SURFACE="$BODY"
    fi

    if [ -z "$AT_RAW" ]; then
        printf '| %s | _(none — inherits all)_ | — | _n/a_ |\n' "$skill"
        continue
    fi

    # Declared set as base tool names (qualifier stripped, Agent/Task collapsed)
    DECLARED=""
    for t in $(printf '%s' "$AT_RAW" | tr ',' ' '); do
        bt=$(base_tool "$t")
        in_list "$bt" "$DECLARED" || DECLARED="$DECLARED $bt"
    done

    OVER=""
    for t in $DECLARED; do
        tool_used "$t" "$SURFACE" || OVER="$OVER $t"
    done

    UNDER=""
    for t in $CANON_TOOLS; do
        in_list "$t" "$DECLARED" && continue
        in_list "$t" "$UNDER" && continue
        if tool_used "$t" "$SURFACE"; then
            if in_list "$t" "$PROSE_NOISY"; then UNDER="$UNDER ${t}?"; else UNDER="$UNDER $t"; fi
        fi
    done

    over_disp=$(printf '%s' "$OVER" | sed 's/^ *//'); [ -z "$over_disp" ] && over_disp="—"
    under_disp=$(printf '%s' "$UNDER" | sed 's/^ *//'); [ -z "$under_disp" ] && under_disp="—"
    decl_disp=$(printf '%s' "$DECLARED" | sed 's/^ *//')
    printf '| %s | %s | %s | %s |\n' "$skill" "$decl_disp" "$over_disp" "$under_disp"
done

printf '\n'
printf '> Candidate generator (idiom-based; confirm with the Axis 12 agent pass). `?` = prose-noisy (Read/Write/Edit). 12a over-grant = unused grant to drop (minimality); 12b under-declare = add it or the tool is blocked at runtime (correctness — higher severity). Scoped grants (`Bash(git:*)`) match on the base tool.\n'
