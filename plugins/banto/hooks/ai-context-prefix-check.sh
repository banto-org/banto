#!/bin/sh
# AI Context Prefix Check Hook (PostToolUse: Write|Edit)
# .ai-context/docs/ 配下（research/ specs/ 除く）に固定プレフィックスを強制
# POSIX互換: macOS / Linux / WSL
#
# 重要: printf '%s' "$INPUT" | jq は JSON 内の $() 等がシェル展開されて壊れるため、
# 一時ファイル経由で jq に渡す

command -v jq >/dev/null 2>&1 || exit 0

TEMP_INPUT=$(mktemp)
cat > "$TEMP_INPUT"

TOOL_NAME=$(jq -r '.tool_name // empty' "$TEMP_INPUT" 2>/dev/null)
FILE_PATH=$(jq -r '.tool_input.file_path // empty' "$TEMP_INPUT" 2>/dev/null)

rm -f "$TEMP_INPUT"

[ -z "$FILE_PATH" ] && exit 0

case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# in-repo（legacy）と中央 store（<store>/<project>/docs/）の両方を対象にする。
# central 移行後は store 絶対パスへ書くため、in-repo パターンだけだと no-op になる
# （2026-06-07: [Review] 違反ファイルが store にすり抜けた実害あり）。
# knowledges/ はプレフィックスを付けない宣言（_common-pattern.md / doctor.md）に合わせて除外。
#
# store root の導出は resolver（resolve-store-path.sh）と同じ優先順位:
# env / 既定は .mapping.json の「置き場所」で、実効 root は mapping の .store_root が正
# （ここが食い違うと resolver は別 root に書き、本 hook は黙って素通りする）。
STORE_ROOT="${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}"
STORE_ROOT="${STORE_ROOT%/}"
MAPPING="${AI_CONTEXT_MAPPING:-$STORE_ROOT/.mapping.json}"
if [ -f "$MAPPING" ]; then
    MAP_ROOT=$(jq -r '.store_root // empty' "$MAPPING" 2>/dev/null)
    case "$MAP_ROOT" in
        "~/"*) MAP_ROOT="$HOME/${MAP_ROOT#\~/}" ;;
        "~")   MAP_ROOT="$HOME" ;;
    esac
    [ -n "$MAP_ROOT" ] && STORE_ROOT="${MAP_ROOT%/}"
fi

case "$FILE_PATH" in
    *"/.ai-context/docs/research/"*|"$STORE_ROOT"/*/docs/research/*) exit 0 ;;
    *"/.ai-context/docs/specs/"*|"$STORE_ROOT"/*/docs/specs/*) exit 0 ;;
    *"/.ai-context/docs/knowledges/"*|"$STORE_ROOT"/*/docs/knowledges/*) exit 0 ;;
    *"/.ai-context/docs/"*|"$STORE_ROOT"/*/docs/*) ;;
    *) exit 0 ;;
esac

FILENAME=$(basename "$FILE_PATH")
VALID_PREFIXES='^\[(Review|QA|Audit|Status|Design|Guide|Memo|Index)\] '

if ! echo "$FILENAME" | grep -qE "$VALID_PREFIXES"; then
    cat >&2 << PREFIX_ERR
[AI Context - Prefix Error] Files under ai-context docs/ (both in-repo and central store) require a fixed prefix.
  File: $FILENAME
  Pick by intent:
    [Status]  progress / situation report     [Design]  design / plan / proposal / discussion draft
    [Guide]   how-to / explainer / overview    [Audit]   audit / analysis / inventory / comparison
    [Review]  code review result               [QA]      test / E2E report
    [Memo]    short note / jot                  [Index]   index of other docs
  Example: [Design] payment-redesign-2026-06-23.md
Rename this file.
PREFIX_ERR
    exit 2
fi
exit 0
