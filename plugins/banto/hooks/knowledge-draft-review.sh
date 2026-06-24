#!/bin/sh
# knowledge-draft-review.sh — SessionStart hook: ドラフト溜まりに気付かせる（提示のみ）
#
# 目的（spec 2026-06-24 ai-context-subsystem-redesign / Story 3）:
#   `{base}/docs/knowledges/drafts/` の *.md 件数が閾値（BANTO_DRAFT_REVIEW_MIN 既定 10）以上なら、
#   SessionStart で 1 回だけ「N 件のドラフトがある。昇格 or 削除を確認」と提示する。
#   提示するだけ（ブロックしない・自動削除しない）。`ai-context knowledge` で処理へ誘導。
#
# 出力契約 (SessionStart): stdout がそのままセッションのコンテキストに追加される。
#   常に exit 0（never block）。
#
# スパム抑止: セッション単位の once ガード（session_id ベースの marker を TMPDIR に置く）。
#   同一セッション内で SessionStart が複数回（resume/clear/compact）走っても 1 回だけ提示する。
#   marker が書けなくても fail-open（毎回出ても害は告知のみ）。
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

# ドラフト件数（*.md のみ）。
COUNT=$(ls "$DRAFTS"/*.md 2>/dev/null | grep -c .)
[ "$COUNT" -ge "$MIN" ] || exit 0

# once ガード: 同一セッションでは 1 回だけ。session_id が取れなければ日次 marker で代用。
if [ -n "$SESSION_ID" ]; then
    GUARD="${TMPDIR:-/tmp}/banto-draft-review-${SESSION_ID}"
else
    GUARD="${TMPDIR:-/tmp}/banto-draft-review-$(date +%Y%m%d 2>/dev/null || echo d)"
fi
[ -f "$GUARD" ] && exit 0
touch "$GUARD" 2>/dev/null || true

echo "[AI Context] ${COUNT} knowledge drafts pending in docs/knowledges/drafts/ -- promote or delete via /ai-context knowledge."
echo ""
exit 0
