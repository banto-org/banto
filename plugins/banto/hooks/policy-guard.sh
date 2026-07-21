#!/bin/sh
# policy-guard.sh — PreToolUse(Write|Edit|NotebookEdit) guard。
# repo 別ポリシー正典 {base}/meta/policy.json の .ignore.no_edit[]（編集禁止パターン）に一致する
# ファイルへの書き込みをブロックする。パターンは repo ルート相対の glob（`**` は `*` に正規化。
# POSIX case-glob では `*` が `/` もまたぐため階層マッチになる）。basename 単体にも照合する
# （`*.env` のような拡張子パターン用）。
#
# 関連: policy.json のスキーマは {"grants": {...}, "ignore": {"no_edit": [], "no_sync": []}}。
#   grants は _ai-context-paths.sh の _ai_context_grant が解決（release-guard / prod-guard）。
#   no_sync は ai-context-sync.sh が store の .git/info/exclude へ反映。
#
# escape: BANTO_ALLOW_POLICY=1（前置代入で単発 escape 可）
# fail-open: jq 不在 / payload 不正 / base 解決不能 / policy 無し / repo 外パス → exit 0
#
# POSIX 互換: macOS / Linux / WSL
set -u

[ "${BANTO_ALLOW_POLICY:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || true)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ -z "$CWD" ] && exit 0

# ai-context base を解決（central store の {base}/meta/policy.json を読む）
SCRIPTS=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$SCRIPTS" ] && SCRIPTS=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
[ -n "$SCRIPTS" ] && [ -f "$SCRIPTS/_ai-context-paths.sh" ] || exit 0
AI_PATHS="$SCRIPTS/_ai-context-paths.sh"
. "$AI_PATHS"
AI_BASE=$(_ai_context_base_dir "$CWD" 2>/dev/null || true)
[ -n "$AI_BASE" ] || exit 0
POL="$AI_BASE/meta/policy.json"
[ -f "$POL" ] || exit 0

# 対象ファイルを repo ルート相対へ
ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || ROOT="$CWD"
case "$FILE" in
    /*) ABS="$FILE" ;;
    *)  ABS="$CWD/$FILE" ;;
esac
case "$ABS" in
    "$ROOT"/*) REL=${ABS#"$ROOT"/} ;;
    *) exit 0 ;;   # repo 外は対象外（store への書き込み等）
esac
BASENAME=$(basename "$ABS")

# no_edit パターン照合（最初の一致を出力。while はサブシェルなので出力で受ける）
HIT=$(jq -r '.ignore.no_edit[]? // empty' "$POL" 2>/dev/null | while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    p=$(printf '%s' "$pat" | sed 's/\*\*/\*/g')
    # shellcheck disable=SC2254  # glob 照合のため意図的に非引用。
    # パターンを (p) と括るのは bash 3.2 の $(...) 内 case 構文バグ回避（閉じ括弧の誤認）。
    case "$REL" in
        ($p) printf '%s' "$pat"; break ;;
    esac
    case "$BASENAME" in
        ($p) printf '%s' "$pat"; break ;;
    esac
done)

[ -z "$HIT" ] && exit 0

printf '[policy guard] edit blocked by per-repo policy (ignore.no_edit: "%s"): %s\n' "$HIT" "$REL" >&2
printf 'Options:\n' >&2
printf '  1. Edit a different file (this path is protected for this repo)\n' >&2
printf '  2. One-shot escape with reason: BANTO_ALLOW_POLICY=1 (prefix assignment)\n' >&2
printf '  3. Change the policy: %s (.ignore.no_edit) — via the policy console or conversation\n' "$POL" >&2
exit 2
