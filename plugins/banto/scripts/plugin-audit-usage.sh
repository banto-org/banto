#!/bin/sh
# plugin-audit-usage.sh — measures skill usage (plugin-audit Axis 11: usage)
#
# Aggregates git log activity over the past N days + mentions inside .ai-context
# + last-modified date, then classifies into active / mentioned / dormant / likely-trim.
# (Reuse of the analysis that surfaced obsidian / pnpm-standard in the 2026-05-29 skill cleanup)
#
# Usage:
#   plugin-audit-usage.sh <plugin_dir> [since_days]        # measure all skills
#   plugin-audit-usage.sh --skill <skill_dir> [since_days] # measure a single skill (per-skill)
#
# Output: Markdown table (| skill | commits | mentions | last-mod | category |)
# POSIX compatible: macOS / Linux / WSL

set -u

SINCE_DAYS=30
MODE=plugin
TARGET=""

while [ $# -gt 0 ]; do
    case "$1" in
        --skill) MODE=skill; TARGET="$2"; shift 2 ;;
        --*) echo "unknown option: $1" >&2; exit 2 ;;
        *)
            if [ -z "$TARGET" ]; then TARGET="$1"; else SINCE_DAYS="$1"; fi
            shift ;;
    esac
done

[ -z "$TARGET" ] && { echo "usage: plugin-audit-usage.sh <plugin_dir> [since_days] | --skill <skill_dir> [since_days]" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "plugin-audit-usage: git is required" >&2; exit 2; }

# Determine the repo root and the since date
REPO_ROOT=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && { echo "plugin-audit-usage: run inside a git repo" >&2; exit 2; }

# since date (POSIX date splits into -d / -v, so use git's relative spec instead)
SINCE_SPEC="${SINCE_DAYS} days ago"

# Resolve the ai-context base (store-first; falls back to legacy in-repo .ai-context).
# Without this, mentions are counted against a non-existent in-repo path in store-first
# environments and the mention axis is always 0.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
AI_CTX=""
if [ -f "$PATHS" ]; then
    AI_CTX=$(sh "$PATHS" --resolve "$REPO_ROOT" 2>/dev/null)
fi
[ -z "$AI_CTX" ] && AI_CTX="$REPO_ROOT/.ai-context"

# Determine the list of skill directories
if [ "$MODE" = "skill" ]; then
    SKILL_DIRS="$TARGET"
else
    SKILL_DIRS=$(find "$TARGET/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
fi
[ -z "$SKILL_DIRS" ] && { echo "plugin-audit-usage: no skills found ($TARGET)" >&2; exit 2; }

# Measure one skill → "name<TAB>commits<TAB>mentions<TAB>lastmod<TAB>category"
measure_one() {
    _dir=$1
    _name=$(basename "$_dir")
    _skillmd="$_dir/SKILL.md"

    # commits: number of commits touching the skill path in the past N days
    _commits=$(git -C "$REPO_ROOT" log --since="$SINCE_SPEC" --oneline -- "$_dir" 2>/dev/null | wc -l | tr -d ' ')

    # mentions: number of files in .ai-context/{decisions,docs} mentioning the skill name
    _mentions=0
    if [ -d "$AI_CTX" ]; then
        _mentions=$(grep -rIl --include="*.md" -e "$_name" "$AI_CTX/decisions" "$AI_CTX/docs" 2>/dev/null | wc -l | tr -d ' ')
    fi

    # last-mod: SKILL.md's last commit date (or "(uncommitted)" if none)
    _lastmod=$(git -C "$REPO_ROOT" log -1 --format=%cs -- "$_skillmd" 2>/dev/null)
    [ -z "$_lastmod" ] && _lastmod="(uncommitted)"

    # category classification
    if [ "$_commits" -ge 3 ] || { [ "$_commits" -ge 1 ] && [ "$_mentions" -ge 10 ]; }; then
        _cat="active"
    elif [ "$_commits" -ge 1 ] || [ "$_mentions" -ge 5 ]; then
        _cat="mentioned"
    elif [ "$_mentions" -ge 1 ]; then
        _cat="dormant"
    else
        _cat="likely-trim"
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "$_name" "$_commits" "$_mentions" "$_lastmod" "$_cat"
}

echo "# Skill Usage Report (Axis 11)"
echo ""
echo "- Window: past ${SINCE_DAYS} days (git log)"
echo "- mentions: number of files in \`.ai-context/{decisions,docs}\` containing the skill name"
echo "- Categories: active / mentioned / dormant (review) / likely-trim (removal candidate)"
echo ""
echo "| skill | commits | mentions | last-mod | category |"
echo "|---|---|---|---|---|"

TRIM_LIST=""
for d in $SKILL_DIRS; do
    [ -f "$d/SKILL.md" ] || continue
    line=$(measure_one "$d")
    name=$(printf '%s' "$line" | cut -f1)
    commits=$(printf '%s' "$line" | cut -f2)
    mentions=$(printf '%s' "$line" | cut -f3)
    lastmod=$(printf '%s' "$line" | cut -f4)
    cat=$(printf '%s' "$line" | cut -f5)
    flag=""
    [ "$cat" = "likely-trim" ] && { flag=" ⚠️"; TRIM_LIST="$TRIM_LIST $name"; }
    [ "$cat" = "dormant" ] && flag=" ⚠"
    printf '| %s | %s | %s | %s | %s%s |\n' "$name" "$commits" "$mentions" "$lastmod" "$cat" "$flag"
done

if [ -n "$TRIM_LIST" ]; then
    echo ""
    echo "## ⚠️ Removal candidates (likely-trim)"
    echo ""
    echo "The following had zero commits and zero mentions in the past ${SINCE_DAYS} days:"
    for s in $TRIM_LIST; do echo "- \`$s\` (consider converting to a rule / merging / removing)"; done
fi
