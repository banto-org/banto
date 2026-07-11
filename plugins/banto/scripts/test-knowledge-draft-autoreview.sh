#!/bin/sh
# test-knowledge-draft-autoreview.sh — knowledge-draft-review.sh の自動昇格/自動アーカイブ（S4）検証
#
# 検証:
#   1. 14 日超 + decisions/ で言及済み → knowledges/ 直下へ自動昇格・結果通知
#   2. 14 日超 + 未言及 → drafts/archive/ へ自動アーカイブ・結果通知
#   3. 14 日未満 → 何もしない（drafts/ に残る）
#   4. 冪等: 2 回目の実行では同じファイルを重複処理しない（既に drafts/ から消えているため）
#   5. しきい値は BANTO_DRAFT_AUTO_AGE_DAYS で可変
#
# 隔離: 合成 HOME + 合成 store root + 合成 TMPDIR。実 store には一切触れない。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$DIR/hooks/knowledge-draft-review.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_STORE_ROOT BANTO_IGNORE_FILE \
      BANTO_DRAFT_REVIEW_MIN BANTO_DRAFT_AUTO_AGE_DAYS 2>/dev/null || true

TMP=$(mktemp -d "${TMPDIR:-/tmp}/draft-autoreview.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude" "$TMP/tmp"
STORE="$FAKE_HOME/ai-context-store"

REPO="$TMP/proj/myrepo"
mkdir -p "$REPO"
git -C "$REPO" init -q
REPO_TOP=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)
PROJ="$STORE/myrepo"
DRAFTS="$PROJ/docs/knowledges/drafts"
KNOWLEDGES="$PROJ/docs/knowledges"
DECISIONS="$PROJ/decisions"
mkdir -p "$DRAFTS" "$DECISIONS" "$STORE"
[ -f "$STORE/.ai-context-store" ] || touch "$STORE/.ai-context-store"
cat > "$STORE/.mapping.json" <<MAP
{
  "version": 2,
  "store_root": "$STORE",
  "projects": { "$REPO_TOP": { "project": "myrepo" } }
}
MAP

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

run_hook() { # payload [extra KEY=VAL ...]
    _pl="$1"; shift
    printf '%s' "$_pl" | env HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" \
        AI_CONTEXT_STORE_ROOT="$STORE" AI_CONTEXT_MAPPING="$STORE/.mapping.json" \
        "$@" sh "$HOOK" 2>/dev/null
}

set_days_ago() { # file days
    _ts=$(date -v-"$2"d +%Y%m%d%H%M 2>/dev/null || date -d "$2 days ago" +%Y%m%d%H%M 2>/dev/null)
    [ -n "$_ts" ] && touch -t "$_ts" "$1" 2>/dev/null
}

reset() {
    rm -f "$DRAFTS"/*.md 2>/dev/null
    rm -rf "$DRAFTS/archive" 2>/dev/null
    rm -f "$KNOWLEDGES"/*.md 2>/dev/null
    rm -f "$DECISIONS"/*.md 2>/dev/null
}

# === 1. 15 日前 + decisions/ で言及済み → 自動昇格 ===
reset
printf '# referenced-topic\n\ncontent\n' > "$DRAFTS/referenced-topic.md"
set_days_ago "$DRAFTS/referenced-topic.md" 15
printf '# decision\n\nsee referenced-topic for background\n' > "$DECISIONS/2026-01-01-000000.md"
OUT=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-promote\"}")
[ ! -f "$DRAFTS/referenced-topic.md" ] && ok "1: promoted draft removed from drafts/" || bad "1: draft still in drafts/"
[ -f "$KNOWLEDGES/referenced-topic.md" ] && ok "1: promoted draft landed in knowledges/" || bad "1: draft not found in knowledges/"
case "$OUT" in *"promoted 1"*) ok "1: notice reports promoted 1" ;; *) bad "1: notice missing promoted count ($OUT)" ;; esac

# === 2. 15 日前 + 未言及 → 自動アーカイブ ===
reset
printf '# orphan-topic\n\ncontent\n' > "$DRAFTS/orphan-topic.md"
set_days_ago "$DRAFTS/orphan-topic.md" 15
OUT=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-archive\"}")
[ ! -f "$DRAFTS/orphan-topic.md" ] && ok "2: archived draft removed from drafts/" || bad "2: draft still in drafts/"
[ -f "$DRAFTS/archive/orphan-topic.md" ] && ok "2: archived draft landed in drafts/archive/" || bad "2: draft not found in archive/"
case "$OUT" in *"archived 1"*) ok "2: notice reports archived 1" ;; *) bad "2: notice missing archived count ($OUT)" ;; esac

# === 3. 5 日前（14 日未満）→ 何もしない ===
reset
printf '# fresh-topic\n\ncontent\n' > "$DRAFTS/fresh-topic.md"
set_days_ago "$DRAFTS/fresh-topic.md" 5
OUT=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-fresh\"}")
[ -f "$DRAFTS/fresh-topic.md" ] && ok "3: fresh draft left untouched in drafts/" || bad "3: fresh draft was moved"
case "$OUT" in *"auto-review"*) bad "3: unexpectedly reported an auto action ($OUT)" ;; *) ok "3: no auto-action notice for a fresh draft" ;; esac

# === 4. 冪等: 昇格済みファイルの 2 回目実行では再処理されない ===
reset
printf '# referenced-topic\n\ncontent\n' > "$DRAFTS/referenced-topic.md"
set_days_ago "$DRAFTS/referenced-topic.md" 15
printf '# decision\n\nsee referenced-topic for background\n' > "$DECISIONS/2026-01-01-000000.md"
run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-idem-1\"}" >/dev/null
OUT2=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-idem-2\"}")
case "$OUT2" in *"promoted"*) bad "4: second run re-reported a promotion ($OUT2)" ;; *) ok "4: second run is a no-op (file already gone from drafts/)" ;; esac

# === 5. しきい値は env で可変（BANTO_DRAFT_AUTO_AGE_DAYS=3 → 5 日前でもアーカイブ対象） ===
reset
printf '# orphan-topic\n\ncontent\n' > "$DRAFTS/orphan-topic.md"
set_days_ago "$DRAFTS/orphan-topic.md" 5
OUT=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-env-age\"}" BANTO_DRAFT_AUTO_AGE_DAYS=3)
[ -f "$DRAFTS/archive/orphan-topic.md" ] && ok "5: env age threshold (3d) archives a 5d draft" || bad "5: env age threshold not honored"

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
