#!/bin/sh
# test-lexicon-distill-autoapply.sh — lexicon-distill.sh の自動追記（S4）検証
#
# 検証:
#   1. 機械判定を満たす候補（freq >= 3・非 stopword・未収載）→ search-lexicon.md へ直接追記し
#      「auto-applied」を報告する
#   2. 冪等: 追記済みの語は 2 回目に再度追記されない（重複行なし・出力も無し）
#   3. fail-open: 追記に失敗する（書き込み不可）→ 従来どおりの「候補提示のみ」メッセージへ
#      フォールバックし、失敗を明示する
#
# 隔離: 合成 BASE 直下に decisions/ を用意し、lexicon-distill.sh を直接 CWD 引数で起動する。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$DIR/scripts/lexicon-distill.sh"
PATHS="$DIR/scripts/_ai-context-paths.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_STORE_ROOT BANTO_IGNORE_FILE 2>/dev/null || true

TMP=$(mktemp -d "${TMPDIR:-/tmp}/lexicon-autoapply.XXXXXX")
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"
STORE="$FAKE_HOME/ai-context-store"

REPO="$TMP/proj/myrepo"
mkdir -p "$REPO"
git -C "$REPO" init -q
REPO_TOP=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)
PROJ="$STORE/myrepo"
DEC="$PROJ/decisions"
mkdir -p "$DEC" "$STORE"
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

run() {
    HOME="$FAKE_HOME" AI_CONTEXT_STORE_ROOT="$STORE" AI_CONTEXT_MAPPING="$STORE/.mapping.json" \
        sh "$SCRIPT" "$REPO" 2>/dev/null
}

LEXICON="$PROJ/search-lexicon.md"

# === 1. freq >= 3 の候補が自動追記される ===
printf '# decision\n\nwidgetize widgetize widgetize the pipeline\n' > "$DEC/2026-01-01-000000.md"
OUT=$(run)
case "$OUT" in *"auto-applied"*) ok "1: reports auto-applied" ;; *) bad "1: missing auto-applied notice ($OUT)" ;; esac
[ -f "$LEXICON" ] && grep -qi 'widgetize' "$LEXICON" && ok "1: term appended to search-lexicon.md" \
    || bad "1: term not found in search-lexicon.md"

# === 2. 冪等: 2 回目は追記も出力もされない ===
OUT2=$(run)
[ -z "$OUT2" ] && ok "2: second run is silent (already listed)" || bad "2: second run re-emitted output ($OUT2)"
N=$(grep -ci 'widgetize' "$LEXICON" 2>/dev/null || echo 0)
[ "$N" -eq 1 ] && ok "2: no duplicate line written" || bad "2: expected 1 occurrence, found $N"

# === 3. fail-open: 追記できない（既存 search-lexicon.md を読み取り専用に）→ 候補提示のみへフォールバック ===
printf '# decision\n\nsprocketify sprocketify sprocketify the widget\n' > "$DEC/2026-01-02-000000.md"
chmod u-w "$LEXICON"
OUT3=$(run)
chmod u+w "$LEXICON"
case "$OUT3" in
    *"addition candidates"*) ok "3: fallback to propose-only wording on write failure" ;;
    *) bad "3: did not fall back on write failure ($OUT3)" ;;
esac
case "$OUT3" in *"sprocketify"*) ok "3: candidate still surfaced for manual review" ;; *) bad "3: candidate lost on fallback ($OUT3)" ;; esac
grep -qi 'sprocketify' "$LEXICON" 2>/dev/null && bad "3: term should NOT have been written on failure" \
    || ok "3: lexicon file not mutated on write failure"

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
