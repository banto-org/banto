#!/bin/sh
# plugin-audit-odd.sh — ODD (odd.yaml) schema lint (Axis 10 extension).
#
# plugin-audit Axis 10 currently checks only presence (has_odd_yaml) + autonomy_level extraction.
# This script validates each skills/<name>/odd.yaml against templates/odd/odd.schema.yaml's
# structural constraints that a stale/concurrent edit can silently break:
#   - required keys present        (schema_version, skill, autonomy_level, in_scope, out_of_scope)
#   - no unknown top-level keys    (schema: additionalProperties:false)
#   - autonomy_level in L0..L3     (L4/L5 = out of banto scope; anything else = invalid)
#   - skill: matches directory     (skills/<name>/ ↔ skill: <name>)
#   - schema_version == 1
#   - in_scope has >= 1 item
#
# Why deterministic: a concurrent/stale session that reverts an odd.yaml to a pre-schema shape
# (e.g. the `domain:` wrapper, a stray `human_oversight:` key, an `.ai-context/` path) is invisible
# to a human eyeballing a diff but breaks the contract. This catches it in CI / SessionStart.
# Cross-skill path-spelling drift ({base}/<base>/.ai-context) is plugin-audit-consistency.sh (Axis 15).
#
# Usage:  plugin-audit-odd.sh <plugin_dir> [--strict]
# Output: Markdown to stdout. Read-only. POSIX sh (macOS bash 3.2 / Linux / WSL). No jq/yaml dep.

set -u

PLUGIN_DIR="."
STRICT=0
for a in "$@"; do
    case "$a" in
        --strict) STRICT=1 ;;
        *) PLUGIN_DIR="$a" ;;
    esac
done
SKILLS_DIR="$PLUGIN_DIR/skills"

echo "## Axis 10+: ODD schema lint (odd.yaml structural validity)"
echo ""
if [ ! -d "$SKILLS_DIR" ]; then
    echo "(no skills/ directory under \`$PLUGIN_DIR\` — nothing to scan)"
    exit 0
fi

# Adoption gate: ODD is an optional (banto-originated) mechanism, not part of the official
# plugin spec. A plugin with no skills/*/odd.yaml at all has not adopted it — report N/A
# instead of per-skill warns. Risk-driven adoption recommendation (with the what/effect/
# merit/demerit explanation) is the audit agent's job: scoring.md Axis 10.
ADOPTED=0
for d in "$SKILLS_DIR"/*/; do
    [ -f "${d}odd.yaml" ] && { ADOPTED=1; break; }
done
if [ "$ADOPTED" -eq 0 ]; then
    echo "N/A — ODD not adopted (no skills/*/odd.yaml under \`$PLUGIN_DIR\`; optional mechanism, nothing to lint)"
    exit 0
fi

# Allowed top-level keys (mirror of templates/odd/odd.schema.yaml properties).
ALLOWED=" schema_version skill autonomy_level in_scope out_of_scope safety_boundaries kill_switch_conditions approval_gates metrics "
REQUIRED="schema_version skill autonomy_level in_scope out_of_scope"

scalar() {
    # $1=file $2=key → trimmed scalar value (strip trailing inline comment + spaces)
    grep -E "^$2:" "$1" 2>/dev/null | head -1 | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//"
}

FAILS=0
MISSING=0

echo "| skill | result |"
echo "|-------|--------|"

for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    skill=$(basename "$d")
    odd="$d/odd.yaml"
    if [ ! -f "$odd" ]; then
        echo "| $skill | ⚠ no odd.yaml |"
        MISSING=$((MISSING + 1))
        continue
    fi

    problems=""

    # top-level keys = lines starting at column 0 with `key:`
    keys=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*:' "$odd" 2>/dev/null | sed -E 's/:.*$//')

    # required present
    for r in $REQUIRED; do
        printf '%s\n' "$keys" | grep -qx "$r" || problems="$problems missing:$r"
    done

    # unknown keys (additionalProperties:false)
    for k in $keys; do
        case "$ALLOWED" in
            *" $k "*) : ;;
            *) problems="$problems unknown-key:$k" ;;
        esac
    done

    # autonomy_level enum + banto range
    al=$(scalar "$odd" autonomy_level)
    case "$al" in
        L0|L1|L2|L3) : ;;
        L4|L5) problems="$problems autonomy-out-of-banto:$al" ;;
        "") problems="$problems autonomy-missing" ;;
        *) problems="$problems autonomy-invalid:$al" ;;
    esac

    # skill name matches directory
    sname=$(scalar "$odd" skill)
    [ -n "$sname" ] && [ "$sname" != "$skill" ] && problems="$problems skill-mismatch:$sname"

    # schema_version == 1
    sv=$(scalar "$odd" schema_version)
    [ -n "$sv" ] && [ "$sv" != "1" ] && problems="$problems schema_version:$sv"

    # in_scope has >= 1 list item (a `-` line before the next top-level key)
    in_items=$(awk '
        /^in_scope:/ {grab=1; next}
        grab && /^[A-Za-z_][A-Za-z0-9_]*:/ {grab=0}
        grab && /^[[:space:]]*-[[:space:]]/ {n++}
        END {print n+0}
    ' "$odd")
    [ "${in_items:-0}" -lt 1 ] && problems="$problems in_scope-empty"

    if [ -n "$problems" ]; then
        echo "| $skill | ❌ FAIL —$problems |"
        FAILS=$((FAILS + 1))
    else
        echo "| $skill | OK |"
    fi
done

echo ""
echo "Summary: FAIL=$FAILS / no-odd=$MISSING"
echo ""
echo "_Schema: \`templates/odd/odd.schema.yaml\`. Path-spelling drift across skills is \`plugin-audit-consistency.sh\` (Axis 15)._"

if [ "$STRICT" -eq 1 ] && [ "$FAILS" -gt 0 ]; then
    exit 1
fi
exit 0
