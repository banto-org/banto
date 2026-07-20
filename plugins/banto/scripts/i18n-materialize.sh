#!/bin/sh
# i18n-materialize.sh <ja|en> — apply a language to the ACTIVE plugin dirs.
#
# Copies every file under i18n/<lang>/{skills,agents,templates} onto the corresponding active
# path (skills/, agents/, templates/), then stamps skills/.banto-lang with "<lang> <plugin-version>".
# templates/ is only partially language-managed: files absent from the i18n trees (lang-specific
# assets like rules/writing-ja.md, output templates, neutral configs) stay in place untouched;
# i18n-coverage-check.sh enforces that every language-bearing template is explicitly classified.
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

_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# --- drift guard (closes the local-live-sync gap in decisions/2026-07-04-130957) ---
# i18n-materialize-check.sh (CI/pre-push only) catches a hand-edited active tree AFTER
# the fact; nothing ran it on the local-sync path (SessionStart reconcile / set-language),
# so a stale canonical silently overwrote the hand-edit. Guard here instead, at the one
# choke point both callers share.
#
# IMPORTANT: compare active files against the STATE RECORDED AT THE LAST SUCCESSFUL
# materialize (.materialize-state.json), NOT against the current canonical. Comparing
# against current canonical would false-positive on the normal, expected workflow of
# "edit canonical, then materialize" (active is merely stale, not hand-edited). Only a
# mismatch against the last-recorded state means someone edited the active copy directly.
STATE="$PLUGIN_ROOT/i18n/.materialize-state.json"
MARKER_PRE="$PLUGIN_ROOT/skills/.banto-lang"
if [ -f "$MARKER_PRE" ] && [ -f "$STATE" ] && command -v jq >/dev/null 2>&1 && [ "${BANTO_MATERIALIZE_FORCE:-}" != "1" ]; then
    CUR_LANG_PRE=$(awk 'NR==1{print $1}' "$MARKER_PRE" 2>/dev/null || true)
    STATE_LANG=$(jq -r '.lang // empty' "$STATE" 2>/dev/null || true)
    if [ -n "$CUR_LANG_PRE" ] && [ "$STATE_LANG" = "$CUR_LANG_PRE" ]; then
        DRIFT_PRE=0
        for rel in $(jq -r '.files | keys[]' "$STATE" 2>/dev/null); do
            active="$PLUGIN_ROOT/$rel"
            [ -e "$active" ] || continue
            recorded=$(jq -r --arg k "$rel" '.files[$k]' "$STATE")
            [ "$(_hash "$active")" = "$recorded" ] || { echo "PRE-DRIFT: $rel (active differs from what was last materialized)" >&2; DRIFT_PRE=$((DRIFT_PRE + 1)); }
        done
        if [ "$DRIFT_PRE" -gt 0 ]; then
            echo "i18n-materialize: REFUSED — $DRIFT_PRE file(s) in the active set were hand-edited since the last materialize." >&2
            echo "Cause: the materialized copy was edited directly; applying '$LANG_SEL' now would silently discard that edit." >&2
            echo "Fix: move the edits to i18n/$CUR_LANG_PRE/ (canonical), then re-run. Or force with BANTO_MATERIALIZE_FORCE=1." >&2
            exit 1
        fi
    fi
fi

VER=$(jq -r '.version // "?"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")

applied=0
tmp_state=$(mktemp)
printf '{"lang":"%s","files":{}}' "$LANG_SEL" > "$tmp_state"
for sub in skills agents templates; do
    [ -d "$SRC/$sub" ] || continue
    for f in $(find "$SRC/$sub" -type f); do
        rel=${f#"$SRC"/}                 # e.g. skills/memo/SKILL.md
        dst="$PLUGIN_ROOT/$rel"
        mkdir -p "$(dirname "$dst")"
        cp "$f" "$dst"
        applied=$((applied+1))
        if command -v jq >/dev/null 2>&1; then
            jq --arg k "$rel" --arg h "$(_hash "$dst")" '.files[$k] = $h' "$tmp_state" > "$tmp_state.2" && mv "$tmp_state.2" "$tmp_state"
        fi
    done
done
if command -v jq >/dev/null 2>&1; then
    mv "$tmp_state" "$STATE"
else
    rm -f "$tmp_state"
fi

mkdir -p "$PLUGIN_ROOT/skills"
printf '%s %s\n' "$LANG_SEL" "$VER" > "$PLUGIN_ROOT/skills/.banto-lang"
echo "i18n-materialize: applied $applied files for lang=$LANG_SEL (plugin $VER). Restart Claude Code to load."
