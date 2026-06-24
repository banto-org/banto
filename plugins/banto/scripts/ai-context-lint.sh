#!/bin/sh
# ai-context-lint.sh — store health lint（検出のみ・自動修正しない / advisory）
#
# 目的（spec 2026-06-24 ai-context-subsystem-redesign）: 中央 store の `decisions/` を走査し
#   ① 壊れた相対 markdown リンク（リンク先ファイルが無い）
#   ② 孤立ファイル（どこからも参照されていない）
#   ③ 矛盾 / 重複の疑い（高確度に限定・控えめ）
#   ④ 陳腐化（とても古い + superseded マーカー付き）
#   を**検出して報告するだけ**。decisions/docs を**絶対に編集・削除しない**（spec: lint は検出のみ）。
#
# 使い方:
#   sh ai-context-lint.sh [CWD]        … CWD（省略時 $PWD）から base を解決して lint
#   doctor サブコマンドから結線して呼ばれる（T2.6）。
#
# 終了コード: 常に 0（advisory。問題があっても作業をブロックしない）。
# fail-open: jq / base 不在 → 静かに exit 0（導入前の挙動を壊さない）。
# POSIX互換: macOS / Linux / WSL
set -u

CWD="${1:-$PWD}"

# base 解決は telemetry-log.sh と同一経路（_ai-context-paths.sh --resolve）。
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
[ -f "$PATHS" ] || exit 0

# jq は banto の必須要件。無ければ fail-open（base 解決自体が jq に依存するため）。
command -v jq >/dev/null 2>&1 || exit 0

BASE=$(sh "$PATHS" --resolve "$CWD" 2>/dev/null)
[ -n "$BASE" ] || exit 0

DECISIONS="$BASE/decisions"
[ -d "$DECISIONS" ] || exit 0

# 走査対象の md 一覧（decisions/ 直下の *.md）。0 件なら静かに終わる。
DEC_LIST=$(ls "$DECISIONS"/*.md 2>/dev/null)
[ -n "$DEC_LIST" ] || exit 0

# 全 md（decisions + docs）を「参照元」コーパスとして使う（孤立判定用）。
# docs/ が無くても decisions/ 単独で機能する。
REF_DIRS="$DECISIONS"
[ -d "$BASE/docs" ] && REF_DIRS="$REF_DIRS $BASE/docs"

# 検出結果を一時ファイルへ蓄積（heredoc/while の subshell 問題を避けるため tmp 集約）。
TMP=$(mktemp "${TMPDIR:-/tmp}/ai-context-lint.XXXXXX" 2>/dev/null) || exit 0
trap 'rm -f "$TMP" "$TMP".links "$TMP".orphan "$TMP".contra "$TMP".stale 2>/dev/null' EXIT
: > "$TMP".links
: > "$TMP".orphan
: > "$TMP".contra
: > "$TMP".stale

NOW=$(date -u +%s 2>/dev/null || date +%s)
# 陳腐化のしきい値（日）: 既定 180。とても古い + superseded のときだけ報告（控えめ）。
STALE_DAYS="${BANTO_LINT_STALE_DAYS:-180}"
STALE_SECS=$(( STALE_DAYS * 86400 ))

file_mtime() { # path → epoch（GNU / BSD 両対応。失敗時 0）
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# ===== ① 壊れた相対 markdown リンク =====
# `[text](path)` の path が相対（http(s)/# 以外）で、リンク元から相対解決して実在しないもの。
printf '%s\n' "$DEC_LIST" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    fdir=$(dirname "$f")
    # markdown リンクの (...) 中身を抽出（複数/行は grep -o で行展開）。
    grep -oE '\]\([^)]+\)' "$f" 2>/dev/null | sed -e 's/^](//' -e 's/)$//' | while IFS= read -r link; do
        [ -n "$link" ] || continue
        # アンカー / 空 / 外部スキーム / mailto は対象外。
        case "$link" in
            \#*|http://*|https://*|mailto:*|ftp://*|//*) continue ;;
        esac
        # クエリ・アンカーを剥がす。
        target=${link%%#*}
        target=${target%%\?*}
        [ -n "$target" ] || continue
        # 絶対パスはそのまま、相対はリンク元 dir 基準で解決。
        case "$target" in
            /*) resolved="$target" ;;
            *)  resolved="$fdir/$target" ;;
        esac
        if [ ! -e "$resolved" ]; then
            printf '  - %s -> %s\n' "$(basename "$f")" "$link" >> "$TMP".links
        fi
    done
done

# ===== ② 孤立ファイル（どこからも参照されていない）=====
# decisions/ の各ファイルの basename が、他の md（decisions + docs）本文に一度も現れないもの。
# 控えめ運用: 単体しか無い store では誤検知が多いので、decisions が 2 件以上のときだけ判定。
DEC_COUNT=$(printf '%s\n' "$DEC_LIST" | grep -c .)
if [ "$DEC_COUNT" -ge 2 ]; then
    printf '%s\n' "$DEC_LIST" | while IFS= read -r f; do
        [ -f "$f" ] || continue
        bn=$(basename "$f")
        # 自分以外の md から basename を検索（固定文字列・自身を除外）。
        refcount=$(grep -rlF "$bn" $REF_DIRS 2>/dev/null | grep -vxF "$f" | grep -c .)
        if [ "$refcount" -eq 0 ]; then
            printf '  - %s (referenced by no md)\n' "$bn" >> "$TMP".orphan
        fi
    done
fi

# ===== ③ 矛盾 / 重複の疑い（高確度のみ・控えめ）=====
# 高確度シグナル: 「同一 H1 タイトル（# ...）を持つ decisions が複数」= 重複の強い候補。
# タイトルを正規化（前後空白除去）して集計し、2 件以上を報告。矛盾の自動判定はしない（誤検知回避）。
printf '%s\n' "$DEC_LIST" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    title=$(grep -m1 '^# ' "$f" 2>/dev/null | sed -e 's/^#[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -n "$title" ] || continue
    printf '%s\t%s\n' "$title" "$(basename "$f")"
done | sort | awk -F'\t' '
    { titles[$1] = titles[$1] ", " $2; cnt[$1]++ }
    END { for (t in cnt) if (cnt[t] >= 2) { sub(/^, /, "", titles[t]); printf "  - same title \"%s\": %s\n", t, titles[t] } }
' >> "$TMP".contra

# ===== ④ 陳腐化（とても古い + superseded）=====
# 高確度に限定: 本文に superseded / 上書き / 廃止 / deprecated / status: superseded 相当の
# マーカーがあり、かつ mtime が STALE_DAYS より古いファイルだけを報告。
printf '%s\n' "$DEC_LIST" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    if grep -qiE 'superseded|deprecated|status:[[:space:]]*(superseded|deprecated|obsolete)|上書き|廃止|失効' "$f" 2>/dev/null; then
        mt=$(file_mtime "$f")
        age=$(( NOW - mt ))
        if [ "$age" -gt "$STALE_SECS" ]; then
            days=$(( age / 86400 ))
            printf '  - %s (superseded marker + %d days old)\n' "$(basename "$f")" "$days" >> "$TMP".stale
        fi
    fi
done

# ===== 報告（concise）=====
HAS_ANY=0
[ -s "$TMP".links ]  && HAS_ANY=1
[ -s "$TMP".orphan ] && HAS_ANY=1
[ -s "$TMP".contra ] && HAS_ANY=1
[ -s "$TMP".stale ]  && HAS_ANY=1

if [ "$HAS_ANY" = "0" ]; then
    echo "[ai-context lint] OK: no health issues detected in ${DECISIONS#"$BASE"/} (advisory; detection-only)"
    exit 0
fi

echo "=== ai-context store health (advisory -- detection only, never auto-fixes) ==="
if [ -s "$TMP".links ]; then
    echo "(1) Broken relative markdown links:"
    cat "$TMP".links
fi
if [ -s "$TMP".orphan ]; then
    echo "(2) Orphan decisions (referenced nowhere):"
    cat "$TMP".orphan
fi
if [ -s "$TMP".contra ]; then
    echo "(3) Likely duplicates (same H1 title -- review for contradiction):"
    cat "$TMP".contra
fi
if [ -s "$TMP".stale ]; then
    echo "(4) Stale (superseded marker + very old):"
    cat "$TMP".stale
fi
echo "(Fix manually or via /ai-context sort -- this lint never edits/deletes your files.)"
exit 0
