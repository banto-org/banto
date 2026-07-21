#!/bin/sh
# AI Context Workspace Check Hook (PostToolUse: Write|Edit)
# decisions/ または docs/ への書き込み時に WORKSPACE.md に未登録なら警告
#
# S4 自動化ギャップ: single（非 multi）モード限定で、スコープ一致が機械判定できる場合
# （新ファイルのファイル名 or 先頭行が WORKSPACE.md の topic 文字列を含む・topic 3 文字以上）は
# 「## 関連ドキュメント」へ自動追記し、実行結果のみ通知する。判定不能・multi モードは
# 従来どおり add/replace/skip の確認を提示する（multi は primary/reference の判断が必要なため
# 対象外のまま残す）。
# POSIX互換: macOS / Linux / WSL

command -v jq >/dev/null 2>&1 || exit 0

TEMP_INPUT=$(mktemp)
cat > "$TEMP_INPUT"

TOOL_NAME=$(jq -r '.tool_name // empty' "$TEMP_INPUT" 2>/dev/null)
FILE_PATH=$(jq -r '.tool_input.file_path // empty' "$TEMP_INPUT" 2>/dev/null)
CWD=$(jq -r '.cwd // empty' "$TEMP_INPUT" 2>/dev/null)

rm -f "$TEMP_INPUT"

[ -z "$FILE_PATH" ] && exit 0
[ -z "$CWD" ] && exit 0

# ai-context ベースdir を解決（central/legacy 透過・既定 legacy で挙動不変）
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi

case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# decisions/ or docs/ への書き込みのみ対象
# central mode では AI_BASE（<store>/<project>）配下の絶対パスに書くため、
# in-repo パターンに加えて AI_BASE 配下も gate に含める（prefix-check と同じ乖離の修正）
case "$FILE_PATH" in
    *"/.ai-context/decisions/"*|*"/.ai-context/docs/"*) ;;
    "$AI_BASE/decisions/"*|"$AI_BASE/docs/"*) ;;
    *) exit 0 ;;
esac

# WORKSPACE.md が存在しない場合はスキップ（per-checkout 実効ポインタを他 hook と同じ resolver で解決）
WS_FILE="$AI_BASE/WORKSPACE.md"
command -v _ai_context_ws_pointer >/dev/null 2>&1 && WS_FILE=$(_ai_context_ws_pointer "$AI_BASE" "$CWD")
[ ! -f "$WS_FILE" ] && exit 0

# multi モード判定（WORKSPACE-refs.md が存在すれば multi）
REFS_FILE="$AI_BASE/WORKSPACE-refs.md"
MULTI_MODE=0
[ -f "$REFS_FILE" ] && MULTI_MODE=1

# ファイルパスを相対パスに変換
REL_PATH=$(echo "$FILE_PATH" | sed "s|$AI_BASE/||")

# primary WORKSPACE.md / refs どちらかに既に登録されているか
if grep -qF "$REL_PATH" "$WS_FILE" 2>/dev/null; then
    exit 0
fi
if [ "$MULTI_MODE" = "1" ] && grep -qF "$REL_PATH" "$REFS_FILE" 2>/dev/null; then
    exit 0
fi

# ファイル名だけでも確認（パスの書き方が微妙に違う場合）
BASENAME=$(basename "$FILE_PATH")
if grep -qF "$BASENAME" "$WS_FILE" 2>/dev/null; then
    exit 0
fi
if [ "$MULTI_MODE" = "1" ] && grep -qF "$BASENAME" "$REFS_FILE" 2>/dev/null; then
    exit 0
fi

# i18n: 「## 関連ドキュメント」 below is the WORKSPACE.md section heading format —
#       consumed-by hooks/ai-context-auto.sh awk, skills/ws/SKILL.md (do not translate the token alone)
if [ "$MULTI_MODE" = "1" ]; then
    # primary 名を WORKSPACE.md の先頭行から抽出
    PRIMARY=$(grep -m1 '^# Workspace:' "$WS_FILE" 2>/dev/null | sed 's/^# Workspace:\s*//')
    [ -z "$PRIMARY" ] && PRIMARY="(primary)"

    # references の一覧を WORKSPACE-refs.md から抽出
    REFS=$(grep -E '^### \[' "$REFS_FILE" 2>/dev/null | sed 's/^### //' | head -5 | tr '\n' '/' | sed 's|/$||')
    [ -z "$REFS" ] && REFS="(references)"

    cat << WS_MULTI_MSG
[Workspace: multi mode] A new file is not registered in any workspace:
  File: $REL_PATH
  Primary:    $PRIMARY (write target)
  References: $REFS (read-only)

  Decision rules:
    - Normally append it to the 「## 関連ドキュメント」 (related documents) section of the primary WORKSPACE.md
    - If it belongs to a reference, confirm with the user, then edit the reference's original workspace file
    - To avoid cross-wiring, never write into WORKSPACE-refs.md itself
WS_MULTI_MSG
else
    # 機械判定によるスコープ一致チェック: WORKSPACE.md の topic 文字列が、新ファイルの
    # ファイル名 or 先頭行に含まれているか（大小文字無視・topic 3 文字未満は誤爆防止で対象外）。
    WS_TOPIC=$(grep -m1 '^# Workspace:' "$WS_FILE" 2>/dev/null | sed 's/^# Workspace:[[:space:]]*//' | sed 's/^\[[^]]*\][[:space:]]*//')
    WS_TOPIC_LC=$(printf '%s' "$WS_TOPIC" | tr '[:upper:]' '[:lower:]')
    BASENAME_LC=$(printf '%s' "$BASENAME" | tr '[:upper:]' '[:lower:]')
    MATCH=0
    if [ -n "$WS_TOPIC_LC" ] && [ "${#WS_TOPIC_LC}" -ge 3 ]; then
        case "$BASENAME_LC" in *"$WS_TOPIC_LC"*) MATCH=1 ;; esac
        if [ "$MATCH" != "1" ] && [ -f "$FILE_PATH" ]; then
            HEAD1=$(head -1 "$FILE_PATH" 2>/dev/null | tr '[:upper:]' '[:lower:]')
            case "$HEAD1" in *"$WS_TOPIC_LC"*) MATCH=1 ;; esac
        fi
    fi

    if [ "$MATCH" = "1" ]; then
        if grep -q '^## 関連ドキュメント' "$WS_FILE" 2>/dev/null; then
            TMP_WS="$WS_FILE.tmp.$$"
            awk -v rel="$REL_PATH" '
                { print }
                /^## 関連ドキュメント/ && !done { print "- " rel; done=1 }
            ' "$WS_FILE" > "$TMP_WS" 2>/dev/null && mv "$TMP_WS" "$WS_FILE" 2>/dev/null || rm -f "$TMP_WS" 2>/dev/null
        else
            { printf '\n## 関連ドキュメント\n'; printf -- '- %s\n' "$REL_PATH"; } >> "$WS_FILE" 2>/dev/null
        fi
        echo "[Workspace] auto-registered a new file under 「## 関連ドキュメント」 (scope match: topic '${WS_TOPIC}'):"
        echo "  File: $REL_PATH"
    else
        cat << WS_CHECK_MSG
[Workspace] A new file is not registered in WORKSPACE.md:
  File: $REL_PATH
  Update WORKSPACE.md:
    - add: add it to the 「## 関連ドキュメント」 (related documents) section
    - replace: swap it with an existing entry
    - skip: unrelated to this workspace (do not add)
WS_CHECK_MSG
    fi
fi

# WS 鮮度リマインダー（decision 2026-07-17）: 新しい decision / spec の保存は WS 本文の古い記述を
# 陳腐化させ得る。どの行が矛盾するかの意味判定は決定論では不可能なのでモデルへ委譲する（warn-only）。
case "$FILE_PATH" in
    */decisions/*.md|*/docs/specs/*.md)
        if [ -f "$WS_FILE" ]; then
            cat << WS_FRESH_MSG
[Workspace freshness] A new decision/spec was saved. Re-read the current workspace.md body and
check for statements this file has made stale (purpose / policy / notes). If found:
strike them through (~~old text~~) and append 「→ 最新: $REL_PATH」. Never delete the old lines.
WS_FRESH_MSG
        fi
        ;;
esac

exit 0
