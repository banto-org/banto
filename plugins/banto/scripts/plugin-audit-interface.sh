#!/bin/sh
# plugin-audit-interface.sh — Axis 1 extension: argument-hint <-> documented-interface fidelity.
#
# "Does the help shown when you type the slash command (argument-hint) match the skill's real
# interface?" A skill whose body documents subcommands the argument-hint never surfaces advertises
# a capability the user cannot discover from `/<skill>` — the feature exists but is unreachable
# (violates the intent-first / discoverability principle: every command reachable by users who do
# not know it exists). The inverse — an argument-hint token with no backing in the body — is an
# advertised-but-not-delivered claim.
#
# Flags (per skill):
#   - UNDER-ADVERTISED: body documents `<skill> <sub>` (a subcommand) but argument-hint omits <sub>.
#   - OVER-ADVERTISED:  an argument-hint bareword token that never appears in the body (confirm —
#                       could be a placeholder; agent pass decides).
#
# Usage:  plugin-audit-interface.sh <plugin_dir>
# Output: Markdown to stdout. Read-only. POSIX sh (macOS / Linux / WSL).

set -u

PLUGIN_DIR="${1:-.}"
SKILLS_DIR="$PLUGIN_DIR/skills"

echo "## Axis 1: argument-hint <-> interface fidelity (slash-command help matches reality)"
echo ""

if [ ! -d "$SKILLS_DIR" ]; then
    echo "(no skills/ directory under \`$PLUGIN_DIR\` — nothing to scan)"
    exit 0
fi

# Connector words that may appear as bareword tokens inside a hint but are not subcommands.
STOP=" or and of to vs the a an for with skills name "

UNDER_F=$(mktemp 2>/dev/null || echo "/tmp/.banto-iface-under.$$")
OVER_F=$(mktemp 2>/dev/null || echo "/tmp/.banto-iface-over.$$")
: > "$UNDER_F"
: > "$OVER_F"

for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    s=$(basename "$d")
    f="$d/SKILL.md"
    [ -f "$f" ] || continue

    # Body = file with the leading frontmatter (--- ... ---) block stripped.
    body=$(awk 'NR==1 && /^---/ {fm=1; next} fm && /^---/ {fm=0; next} !fm {print}' "$f")
    hintline=$(grep -m1 '^argument-hint:' "$f" 2>/dev/null | sed 's/^argument-hint:[[:space:]]*//')

    # Body-documented subcommands: `<skill> <word>` or `/<skill> <word>` code spans.
    bodysub=$(printf '%s' "$body" | grep -oE "\`/?$s [a-z][a-z-]+\`" 2>/dev/null \
        | sed -E "s#\`/?$s ##; s#\`##" | sort -u)
    # Hint bareword tokens (lowercase ASCII), as a space-padded haystack for membership tests.
    hinttok=" $(printf '%s' "$hintline" | grep -oE '[a-z][a-z-]+' 2>/dev/null | sort -u | tr '\n' ' ') "

    # UNDER-advertised: a documented subcommand missing from the hint.
    for sub in $bodysub; do
        case "$hinttok" in
            *" $sub "*) : ;;
            *) printf '%s\t%s\n' "$s" "$sub" >> "$UNDER_F" ;;
        esac
    done

    # OVER-advertised: an advertised KEYWORD with no body backing. An advertised keyword is a hint
    # segment (split on | and /) that, trimmed of brackets/quotes/space, is EXACTLY a bareword — so a
    # descriptive placeholder embedded in a longer segment (e.g. "export-target-dir（省略時は …）") is
    # NOT treated as a keyword and does not false-flag.
    adv=$(printf '%s' "$hintline" | tr '|/' '\n\n' | tr -d "[]\"'" \
        | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -E '^[a-z][a-z-]+$' 2>/dev/null | sort -u)
    for tok in $adv; do
        case "$STOP" in *" $tok "*) continue ;; esac
        if ! printf '%s' "$body" | grep -qiw "$tok" 2>/dev/null; then
            printf '%s\t%s\n' "$s" "$tok" >> "$OVER_F"
        fi
    done
done

echo "### Under-advertised subcommands (documented in body, missing from argument-hint)"
echo ""
echo "The skill body documents \`<skill> <sub>\` but the argument-hint does not list \`<sub>\`. A user typing"
echo "\`/<skill>\` sees no hint of it → the feature is unreachable from the surfaced help. ⚠ add it to argument-hint."
echo ""
if [ -s "$UNDER_F" ]; then
    echo "| Skill | Subcommand (not in hint) |"
    echo "|-------|--------------------------|"
    sort "$UNDER_F" | while IFS="$(printf '\t')" read -r s sub; do
        printf "| %s | \`%s %s\` |\n" "$s" "$s" "$sub"
    done
else
    echo "(none — every documented subcommand is surfaced in its argument-hint)"
fi
echo ""

echo "### Over-advertised tokens (in argument-hint, no backing in body)"
echo ""
echo "An argument-hint bareword that never appears in the body — advertised but possibly not implemented."
echo "ℹ confirm (could be a placeholder noun; the agent pass decides)."
echo ""
if [ -s "$OVER_F" ]; then
    echo "| Skill | Hint token (no body backing) |"
    echo "|-------|------------------------------|"
    sort "$OVER_F" | while IFS="$(printf '\t')" read -r s tok; do
        printf "| %s | \`%s\` |\n" "$s" "$tok"
    done
else
    echo "(none)"
fi
echo ""

rm -f "$UNDER_F" "$OVER_F" 2>/dev/null || true
echo "---"
echo "_Axis 1 extension: the slash-command help (argument-hint) must match the skill's real interface — features must be discoverable._"
