#!/bin/sh
# knowledge-draft-review.sh — SessionStart hook: ドラフトを経過日数 + 参照有無で自動昇格/自動アーカイブする
#
# 目的（spec 2026-06-24 ai-context-subsystem-redesign / Story 3、S4 で自動適用へ拡張）:
#   `{base}/docs/knowledges/drafts/` の各ファイルについて、更新から
#   BANTO_DRAFT_AUTO_AGE_DAYS（既定 14）日を超えたものだけを判定対象にする:
#     - decisions/ または knowledges/ 本体（drafts/ 自身を除く）で言及済み（＝既参照）→ 自動昇格
#       （`knowledges/` 直下へ mv。git 管理下なら `git mv`）
#     - 言及なし（＝未参照）→ 自動アーカイブ（`drafts/archive/` へ mv。削除はしない）
#   実行結果のみ通知する（提示して人間の判断を待つのではなく、既に完了した事実を報告する）。
#   14 日未満で残っているドラフトは従来どおり手つかずで、件数が閾値
#   （BANTO_DRAFT_REVIEW_MIN 既定 10）以上のときだけ旧来の「レビューして」提示を残す。
#
# 出力契約 (SessionStart): stdout がそのままセッションのコンテキストに追加される。
#   常に exit 0（never block）。
#
# 自動アクション自体は毎回試みる（mv 後はファイルが drafts/ から消えるため冪等・再実行安全）。
# スパム抑止は「14 日未満の残件数が閾値以上」のときの旧来メッセージにのみ適用する
# （セッション単位の once ガード。session_id ベースの marker を TMPDIR に置く）。
#
# fail-open: jq / base 不在 / drafts ディレクトリ無し → 静かに exit 0。
# POSIX互換: macOS / Linux / WSL
set -u

# jq は base 解決の必須要件。無ければ fail-open。
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || echo '{}')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# 閾値（既定 10）。0 以下なら無効化扱いで静かに終了。
MIN="${BANTO_DRAFT_REVIEW_MIN:-10}"
case "$MIN" in
    ''|*[!0-9]*) MIN=10 ;;
esac
[ "$MIN" -le 0 ] && exit 0

# base 解決は telemetry-log.sh / lint と同一経路。
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
[ -f "$PATHS" ] || exit 0

BASE=$(sh "$PATHS" --resolve "$CWD" 2>/dev/null)
[ -n "$BASE" ] || exit 0

DRAFTS="$BASE/docs/knowledges/drafts"
[ -d "$DRAFTS" ] || exit 0

KNOWLEDGES="$BASE/docs/knowledges"
ARCHIVE="$DRAFTS/archive"
DECISIONS="$BASE/decisions"

# 経過日数しきい値（既定 14）。0 以下なら自動アクションを無効化（従来どおり提示のみ）。
AGE_DAYS="${BANTO_DRAFT_AUTO_AGE_DAYS:-14}"
case "$AGE_DAYS" in ''|*[!0-9]*) AGE_DAYS=14 ;; esac
AGE_SEC=$(( AGE_DAYS * 86400 ))

# NOW が取れない環境では age 判定が常に「まだ新しい」側へ倒れる（負の経過秒 <= しきい値 →
# 何もアクションしない）ので安全側 fail-open。
NOW=$(date +%s 2>/dev/null)
[ -z "$NOW" ] && NOW=0

mtime_of() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

PROMOTED=""
ARCHIVED=""
PROMOTED_N=0
ARCHIVED_N=0

if [ "$AGE_DAYS" -gt 0 ]; then
    for f in "$DRAFTS"/*.md; do
        [ -f "$f" ] || continue
        MT=$(mtime_of "$f")
        case "$MT" in ''|*[!0-9]*) continue ;; esac
        [ $(( NOW - MT )) -gt "$AGE_SEC" ] || continue

        BN=$(basename "$f")
        # 参照判定: decisions/ または knowledges/ 本体（drafts/ 自身を除く）でトピック名
        # （拡張子抜きのファイル名）が言及されていれば「既参照」とみなす（機械判定・保守的）。
        TOPIC="${BN%.md}"
        REFERENCED=0
        HIT=$(grep -rlF -- "$TOPIC" "$DECISIONS" "$KNOWLEDGES" 2>/dev/null | grep -v "/drafts/")
        [ -n "$HIT" ] && REFERENCED=1

        if [ "$REFERENCED" = "1" ]; then
            mkdir -p "$KNOWLEDGES" 2>/dev/null
            if command -v git >/dev/null 2>&1 && git -C "$BASE" rev-parse >/dev/null 2>&1; then
                git -C "$BASE" mv -- "$f" "$KNOWLEDGES/$BN" >/dev/null 2>&1 || mv "$f" "$KNOWLEDGES/$BN" 2>/dev/null
            else
                mv "$f" "$KNOWLEDGES/$BN" 2>/dev/null
            fi
            if [ -f "$KNOWLEDGES/$BN" ]; then
                PROMOTED="${PROMOTED}- ${BN} (referenced, ${AGE_DAYS}d+)
"
                PROMOTED_N=$((PROMOTED_N + 1))
            fi
        else
            mkdir -p "$ARCHIVE" 2>/dev/null
            mv "$f" "$ARCHIVE/$BN" 2>/dev/null
            if [ -f "$ARCHIVE/$BN" ]; then
                ARCHIVED="${ARCHIVED}- ${BN} (unreferenced, ${AGE_DAYS}d+)
"
                ARCHIVED_N=$((ARCHIVED_N + 1))
            fi
        fi
    done
fi

# 実行結果は毎回通知する（一度動いたファイルは drafts/ から消えるため再通知の心配はない）。
if [ "$PROMOTED_N" -gt 0 ] || [ "$ARCHIVED_N" -gt 0 ]; then
    echo "[AI Context] knowledge draft auto-review: promoted ${PROMOTED_N} / archived ${ARCHIVED_N} (age > ${AGE_DAYS}d)."
    [ -n "$PROMOTED" ] && printf '%s' "$PROMOTED"
    [ -n "$ARCHIVED" ] && printf '%s' "$ARCHIVED"
    echo ""
fi

# 14 日未満で残っているドラフトが閾値件数以上あれば、従来どおりの提示（once ガード付き）。
COUNT=$(ls "$DRAFTS"/*.md 2>/dev/null | grep -c .)
if [ "$COUNT" -ge "$MIN" ]; then
    if [ -n "$SESSION_ID" ]; then
        GUARD="${TMPDIR:-/tmp}/banto-draft-review-${SESSION_ID}"
    else
        GUARD="${TMPDIR:-/tmp}/banto-draft-review-$(date +%Y%m%d 2>/dev/null || echo d)"
    fi
    if [ ! -f "$GUARD" ]; then
        touch "$GUARD" 2>/dev/null || true
        echo "[AI Context] ${COUNT} knowledge drafts pending in docs/knowledges/drafts/ -- promote or delete via /ai-context knowledge."
        echo ""
    fi
fi
exit 0
