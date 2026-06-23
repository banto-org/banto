#!/bin/sh
# i18n-reconcile.sh — SessionStart hook. Keeps the ACTIVE skill/agent language in sync
# with the user's persisted choice (~/.claude/banto-language), so the chosen language
# survives plugin updates.
#
# A `claude plugin update` reinstalls the plugin and reverts the active set to the shipped
# default (EN). This hook detects that (marker lang/version != preference) and re-applies
# the user's language by calling i18n-materialize.sh — making the choice sticky across updates.
#
# No-op when no preference file exists (never disturbs users who never ran /set-language) —
# same fail-open philosophy as the egress guard.
#
# Overridable for tests: BANTO_LANG_FILE, BANTO_PLUGIN_ROOT.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)        # real hooks/ dir (from $0)
REAL_PLUGIN=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)           # real plugin root (has scripts/)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$REAL_PLUGIN}                 # target tree (active set + marker)
LANG_FILE=${BANTO_LANG_FILE:-$HOME/.claude/banto-language}
MARKER="$PLUGIN_ROOT/skills/.banto-lang"

# No persisted preference → nothing to enforce.
[ -f "$LANG_FILE" ] || exit 0
PREF=$(tr -d '[:space:]' < "$LANG_FILE" 2>/dev/null || true)
case "$PREF" in ja|en) ;; *) exit 0 ;; esac   # ignore empty/garbage

VER=$(jq -r '.version // "?"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")
CUR_LANG=""; CUR_VER=""
if [ -f "$MARKER" ]; then
    read -r CUR_LANG CUR_VER < "$MARKER" 2>/dev/null || true
fi

# Already applied for this plugin version → no-op.
if [ "$CUR_LANG" = "$PREF" ] && [ "$CUR_VER" = "$VER" ]; then
    exit 0
fi

# Drift detected (fresh install / plugin update / version bump): re-apply the chosen language.
# materialize lives in scripts/ (sibling of hooks/); it targets $PLUGIN_ROOT via BANTO_PLUGIN_ROOT.
if sh "$REAL_PLUGIN/scripts/i18n-materialize.sh" "$PREF" >/dev/null 2>&1; then
    echo "[banto i18n] Re-applied language '$PREF' after update (was: ${CUR_LANG:-none}/${CUR_VER:-none}). Restart Claude Code to load the '$PREF' skill set."
fi
exit 0
