#!/bin/sh
# AI Context Prefix Check Hook (PostToolUse: Write|Edit)
# .ai-context/docs/ 配下（research/ specs/ 除く）に固定プレフィックスを強制（block）+
# 命名正典（2026-07-23）の日付プレフィックス位置を検査（warn-only）
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
    *"/.ai-context/docs/research/"*|"$STORE_ROOT"/*/docs/research/*|*"/.ai-context/docs/specs/"*|"$STORE_ROOT"/*/docs/specs/*)
        # front-matter 最小スキーマの警告（decision 2026-07-17: 監査で research 5% / specs 0% と判明。
        # provenance の機械抽出（検索 age_days / 学習 export）に必要。warn-only・never block）
        case "$FILE_PATH" in *.md) ;; *) exit 0 ;; esac
        [ -f "$FILE_PATH" ] || exit 0
        if [ "$(head -1 "$FILE_PATH" 2>/dev/null)" != "---" ]; then
            cat >&2 << FM_WARN
[AI Context - Front-matter] research/specs files should start with minimal YAML front-matter
(provenance for search freshness + training export):
  ---
  date: YYYY-MM-DD
  topic: {one line}
  status: active    # research: active|stale / specs: draft|accepted|shipped|superseded
  ---
Add it to: $(basename "$FILE_PATH")  (warn-only; the filename date stays the freshness source of truth)
FM_WARN
        fi
        exit 0 ;;
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

# 日付位置チェック（命名正典 2026-07-23: docs/ は日付プレフィックス `[Prefix] YYYY-MM-DD_slug`）。
# 日付を含むのに先頭・`_` 区切りになっていない（末尾サフィックス等）ものを警告。
# 日付を含まない資料（[Index] 等）は対象外。warn-only（既存ファイルの移行を壊さない）。
if echo "$FILENAME" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
   && ! echo "$FILENAME" | grep -qE '^\[[A-Za-z]+\] [0-9]{4}-[0-9]{2}-[0-9]{2}_'; then
    cat >&2 << DATE_WARN
[AI Context - Naming] docs/ の命名は日付プレフィックス: [Prefix] YYYY-MM-DD_slug[_variant].ext
  File: $FILENAME
  日付が先頭・_ 区切りになっていない（末尾サフィックス等の可能性）。
  例: [Guide] 2026-07-19_banto-clear-doc_fable.html （warn-only; 日付なしの [Index] 等は対象外）
DATE_WARN
fi

# reason: front-matter 警告（docs/ 直下、.md 限定。research/specs は専用スキーマで上流にて
# warn 済み、knowledges/ は front-matter 対象外で既に除外済み。HTML/office は front-matter
# 不可なので対象外。warn-only・block しない — 作成インデックスの reason 抽出元）
case "$FILE_PATH" in
    *.md)
        [ -f "$FILE_PATH" ] || exit 0
        HAS_REASON=0
        if [ "$(head -1 "$FILE_PATH" 2>/dev/null)" = "---" ] \
           && awk 'NR==1{next} /^---$/{exit} /^reason:/{f=1; exit} END{exit !f}' "$FILE_PATH" >/dev/null 2>&1; then
            HAS_REASON=1
        fi
        if [ "$HAS_REASON" -eq 0 ]; then
            cat >&2 << REASON_WARN
[AI Context - Front-matter] docs/ files should include a one-line reason: in front-matter
(why this file was created — feeds {base}/meta/creation-index.md):
  ---
  reason: {one line}
  ---
Add it to: $(basename "$FILE_PATH")  (warn-only)
REASON_WARN
        fi
        ;;
esac
exit 0
