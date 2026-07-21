#!/bin/sh
# writing-ja-toggle.sh <on|off|sync> — persist the writing-ja rule preference (user scope,
# survives plugin updates) and reconcile ~/.claude/rules/writing-ja.md to it.
#
# The rule is OPT-IN: no marker (or "off") = the rule is NOT deployed, even on the ja set.
# Desired state = (language == ja) AND (preference == on). Reconcile:
#   wanted  + absent            → deploy a copy from the template
#   !wanted + present + intact  → remove (personal edits are never deleted)
#
# "sync" re-applies the current preference without changing it (called by set-language.sh
# after a language switch). Called by the /set-language skill for on|off.
# Overrides for tests: BANTO_WJ_FILE / BANTO_LANG_FILE / BANTO_RULES_DIR.
set -eu

SEL=${1:?usage: writing-ja-toggle.sh <on|off|sync>}
case "$SEL" in on|off|sync) ;; *) echo "writing-ja-toggle: arg must be on|off|sync (got '$SEL')"; exit 2 ;; esac

WJ_FILE=${BANTO_WJ_FILE:-$HOME/.claude/banto-writing-ja}
LANG_FILE=${BANTO_LANG_FILE:-$HOME/.claude/banto-language}
RULES_USER=${BANTO_RULES_DIR:-$HOME/.claude/rules}

if [ "$SEL" != sync ]; then
    mkdir -p "$(dirname "$WJ_FILE")"
    printf '%s\n' "$SEL" > "$WJ_FILE"
    echo "writing-ja-toggle: preference saved ($WJ_FILE = $SEL)"
fi

PREF=$([ -f "$WJ_FILE" ] && tr -d ' \n' < "$WJ_FILE" || echo off)
LANG_NOW=$([ -f "$LANG_FILE" ] && tr -d ' \n' < "$LANG_FILE" || echo en)

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WJ_SRC="$SCRIPT_DIR/../templates/rules/writing-ja.md"
WJ_DST="$RULES_USER/writing-ja.md"

[ -f "$WJ_SRC" ] || { echo "writing-ja-toggle: template not found ($WJ_SRC) — no-op"; exit 0; }

if [ "$PREF" = on ] && [ "$LANG_NOW" = ja ]; then
    if [ ! -d "$RULES_USER" ]; then
        echo "writing-ja-toggle: rules dir missing ($RULES_USER) — run harness-setup.sh first"
    elif [ -e "$WJ_DST" ]; then
        echo "writing-ja-toggle: already deployed ($WJ_DST)"
    else
        cp "$WJ_SRC" "$WJ_DST"
        echo "writing-ja-toggle: deployed $WJ_DST"
    fi
else
    [ "$PREF" = on ] && [ "$LANG_NOW" != ja ] && echo "writing-ja-toggle: preference is on but language is '$LANG_NOW' — deploys when the language is ja"
    if [ -e "$WJ_DST" ]; then
        if cmp -s "$WJ_SRC" "$WJ_DST"; then
            rm -f "$WJ_DST"
            echo "writing-ja-toggle: removed $WJ_DST (unmodified copy)"
        else
            echo "writing-ja-toggle: $WJ_DST differs from the template — left in place (personal edits protected; remove manually to stop injection)"
        fi
    fi
fi
