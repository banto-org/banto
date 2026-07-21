#!/bin/sh
# i18n-coverage-check.sh — TOTAL i18n classification gate.
#
# The older i18n gates only verify files ALREADY INSIDE the i18n trees (i18n-sync-check: ja<->en
# parity; i18n-materialize-check: canonical -> active identity; i18n-en-sanity: EN content sanity).
# None of them sees a language-bearing file that never entered the trees — which is exactly how
# templates/ shipped mixed-language rules (JA thinking-core.md next to EN quality.md) unnoticed.
#
# Contract: EVERY language-bearing distribution file must be exactly one of
#   (a) managed  — present at i18n/ja/<rel> (JA-canonical tree; EN parity is then enforced by
#                  i18n-sync-check, active identity by i18n-materialize-check), or
#   (b) exempted — listed in i18n/.coverage-exemptions with an explicit reason category
#                  (lang-specific / output-template / dev-doc / active-only / neutral).
# Anything else fails, so ADDING a new template/skill/agent file forces an explicit i18n decision.
#
# Scope (find roots + extensions):
#   templates/          *.md *.tpl *.template *.yaml
#   skills/  agents/    *.md *.yaml
#
# Usage: i18n-coverage-check.sh            (plugin root from script location or BANTO_PLUGIN_ROOT)
# exit 1 on any unclassified file. No-op when i18n/ja is absent (pre-migration tree). POSIX sh.
# Note: relies on word-splitting over find output; plugin-internal paths contain no spaces.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
I18N="$PLUGIN_ROOT/i18n"
EXEMPT="$I18N/.coverage-exemptions"

if [ ! -d "$I18N/ja" ]; then
    echo "i18n-coverage: not initialized (no i18n/ja) — skip"
    exit 0
fi

exempt_cat() {  # $1 = rel path → prints the category and returns 0 when an exemption glob matches
    [ -f "$EXEMPT" ] || return 1
    while IFS=' 	' read -r cat glob; do
        case "$cat" in ''|'#'*) continue ;; esac
        [ -n "$glob" ] || continue
        # shellcheck disable=SC2254  # unquoted on purpose: the manifest line IS the pattern
        case "$1" in $glob) printf '%s' "$cat"; return 0 ;; esac
    done < "$EXEMPT"
    return 1
}

ROOTS=""
for d in templates skills agents; do
    [ -d "$PLUGIN_ROOT/$d" ] && ROOTS="$ROOTS $PLUGIN_ROOT/$d"
done
[ -n "$ROOTS" ] || { echo "i18n-coverage: nothing to scan"; exit 0; }

BAD=0; MANAGED=0; EXEMPTED=0
# shellcheck disable=SC2086  # ROOTS is a deliberate word-split list
for f in $(find $ROOTS -type f \
        \( -name '*.md' -o -name '*.yaml' -o -name '*.tpl' -o -name '*.template' \) \
        2>/dev/null | LC_ALL=C sort); do
    rel=${f#"$PLUGIN_ROOT"/}
    if [ -f "$I18N/ja/$rel" ]; then
        MANAGED=$((MANAGED + 1))
    elif exempt_cat "$rel" >/dev/null; then
        EXEMPTED=$((EXEMPTED + 1))
    else
        echo "UNCLASSIFIED: $rel (not in i18n/ja, not in i18n/.coverage-exemptions)"
        BAD=$((BAD + 1))
    fi
done

if [ "$BAD" -gt 0 ]; then
    echo ""
    echo "i18n-coverage FAIL: $BAD file(s) are neither i18n-managed nor explicitly exempted."
    echo "→ Fix: EITHER add the file to i18n/ja/<same-path> (then i18n-gen.sh to produce EN),"
    echo "       OR list it in i18n/.coverage-exemptions with a reason category."
    exit 1
fi
echo "i18n-coverage OK (managed=$MANAGED exempted=$EXEMPTED)"
exit 0
