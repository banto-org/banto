#!/bin/sh
# set-language.sh <ja|en> — persist the banto language preference (user scope, survives
# plugin updates) and materialize the chosen language onto the active skill/agent set.
#
# Called by the /set-language skill. Override BANTO_LANG_FILE for tests.
set -eu

LANG_SEL=${1:?usage: set-language.sh <ja|en>}
case "$LANG_SEL" in ja|en) ;; *) echo "set-language: lang must be ja|en (got '$LANG_SEL')"; exit 2 ;; esac

LANG_FILE=${BANTO_LANG_FILE:-$HOME/.claude/banto-language}
mkdir -p "$(dirname "$LANG_FILE")"
printf '%s\n' "$LANG_SEL" > "$LANG_FILE"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$SCRIPT_DIR/i18n-materialize.sh" "$LANG_SEL"

# 言語固有ルール（writing-ja）を ~/.claude/rules/ で言語 + 個別設定に追従させる。
# 配置の正は writing-ja-toggle.sh の reconcile（ja かつ preference=on のときだけ配置。既定 off。
# 個人改変されたコピーは削除しない）。
sh "$SCRIPT_DIR/writing-ja-toggle.sh" sync

echo "set-language: preference saved ($LANG_FILE = $LANG_SEL). Restart Claude Code to load the '$LANG_SEL' skill set."
