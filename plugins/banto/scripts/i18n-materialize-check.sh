#!/bin/sh
# i18n-materialize-check.sh — verify the ACTIVE materialized set (skills/, agents/) matches its
# CANONICAL source i18n/<active-lang>/.
#
# Failure mode this catches: someone edits the materialized copy (skills/<x>) directly and forgets
# the canonical (i18n/ja/<x>). i18n-sync-check.sh only compares ja<->en, so it never sees this; a
# later `i18n-materialize.sh` then silently REVERTS the edit by overwriting skills/ from the stale
# canonical. This gate makes that divergence a hard CI failure.
#
# Direction: every canonical file under i18n/<lang>/{skills,agents} must have an identical
# materialized copy. The active set MAY contain extra active-only files (set-language invariant) —
# those are allowed; we only flag canonical files that are missing or differ in the active set.
#
# No-op (exit 0) when i18n/ja does not exist (pre-migration trees). exit 1 on drift.
# Wired into CI (.github/workflows/ci.yml) and scripts/pre-push-check.sh. POSIX sh.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
I18N="$PLUGIN_ROOT/i18n"

if [ ! -d "$I18N/ja" ]; then
    echo "i18n-materialize-check: not initialized (no i18n/ja) — skip"
    exit 0
fi

# Active language: first token of skills/.banto-lang (format e.g. "ja 1.1.0"); default ja.
ACTIVE=ja
LANGFILE="$PLUGIN_ROOT/skills/.banto-lang"
if [ -f "$LANGFILE" ]; then
    READLANG=$(awk 'NR==1{print $1}' "$LANGFILE" 2>/dev/null || true)
    [ -n "$READLANG" ] && ACTIVE="$READLANG"
fi

SRC="$I18N/$ACTIVE"
if [ ! -d "$SRC" ]; then
    echo "i18n-materialize-check: no canonical tree for active lang '$ACTIVE' — skip"
    exit 0
fi

DRIFT=0
for cf in $(find "$SRC" -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
    rel=${cf#"$SRC"/}                       # e.g. skills/ws/SKILL.md or agents/architect.md
    active="$PLUGIN_ROOT/$rel"
    if [ ! -e "$active" ]; then
        echo "MISSING: $rel (canonical exists in i18n/$ACTIVE, materialized copy absent)"
        DRIFT=$((DRIFT + 1))
    elif ! cmp -s "$cf" "$active"; then
        echo "DRIFT:   $rel (active set differs from canonical i18n/$ACTIVE)"
        DRIFT=$((DRIFT + 1))
    fi
done

if [ "$DRIFT" -gt 0 ]; then
    echo ""
    echo "i18n-materialize-check: FAIL — $DRIFT file(s) diverge between i18n/$ACTIVE (canonical) and the active set."
    echo "Cause: a materialized copy (skills/ or agents/) was edited directly instead of the canonical i18n/$ACTIVE/."
    echo "Fix: move the edits to i18n/$ACTIVE/, re-materialize (i18n-materialize.sh $ACTIVE), then regen EN (i18n-gen.sh)."
    exit 1
fi

echo "i18n-materialize-check: OK — active set matches i18n/$ACTIVE canonical ($(find "$SRC" -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null | wc -l | tr -d ' ') files)."
exit 0
