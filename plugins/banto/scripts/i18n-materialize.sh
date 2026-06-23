#!/bin/sh
# i18n-materialize.sh <ja|en> — apply a language to the ACTIVE plugin dirs.
#
# Copies every file under i18n/<lang>/{skills,agents} onto the corresponding active
# path (skills/, agents/), then stamps skills/.banto-lang with "<lang> <plugin-version>".
#
# Incremental by design: only files that exist under i18n/<lang> are applied, so during
# the migration the not-yet-translated skills stay as shipped. Once every skill/agent is
# under i18n/, a materialize fully swaps the active set.
#
# Used by: the /set-language skill (after recording the preference) and the
# i18n-reconcile.sh SessionStart hook (to re-apply the chosen language after a plugin update).
#
# Override BANTO_PLUGIN_ROOT to target a fixture (unit tests). Plugin paths contain no spaces.
set -eu

LANG_SEL=${1:?usage: i18n-materialize.sh <ja|en>}
case "$LANG_SEL" in ja|en) ;; *) echo "i18n-materialize: lang must be ja|en (got '$LANG_SEL')"; exit 2 ;; esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
SRC="$PLUGIN_ROOT/i18n/$LANG_SEL"

if [ ! -d "$SRC" ]; then
    echo "i18n-materialize: no such language tree: $SRC" >&2
    exit 1
fi
VER=$(jq -r '.version // "?"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")

applied=0
for sub in skills agents; do
    [ -d "$SRC/$sub" ] || continue
    for f in $(find "$SRC/$sub" -type f); do
        rel=${f#"$SRC"/}                 # e.g. skills/memo/SKILL.md
        dst="$PLUGIN_ROOT/$rel"
        mkdir -p "$(dirname "$dst")"
        cp "$f" "$dst"
        applied=$((applied+1))
    done
done

mkdir -p "$PLUGIN_ROOT/skills"
printf '%s %s\n' "$LANG_SEL" "$VER" > "$PLUGIN_ROOT/skills/.banto-lang"
echo "i18n-materialize: applied $applied files for lang=$LANG_SEL (plugin $VER). Restart Claude Code to load."
