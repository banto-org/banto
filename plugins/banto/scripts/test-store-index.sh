#!/bin/sh
# test-store-index.sh — store_index_gen.py + store-query.sh の合成 fixture テスト。
# 検証: 構築 / doc_type / 鮮度スキップ / 原子的差し替え先 / gitignore 冪等 / project 絞り込み /
#       --all 横断 / 短語 LIKE フォールバック / legacy（マーカー無し）配置 / fail-open。
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GEN="$SCRIPT_DIR/store_index_gen.py"
QUERY="$SCRIPT_DIR/store-query.sh"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

command -v python3 >/dev/null 2>&1 || { echo "test-store-index: python3 not found — skipped"; exit 0; }
python3 -c "import sqlite3; sqlite3.connect(':memory:').execute(\"CREATE VIRTUAL TABLE t USING fts5(x, tokenize='trigram')\")" 2>/dev/null \
    || { echo "test-store-index: FTS5/trigram unavailable — skipped (fail-open path)"; exit 0; }

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

# fixture: store ルート（マーカーあり）+ 2 プロジェクト
touch "$ROOT/.ai-context-store"
mkdir -p "$ROOT/projA/decisions" "$ROOT/projB/docs"
cat > "$ROOT/projA/decisions/2026-07-02-120000_fts-adoption_tester.md" << 'MD'
---
title: FTS 採用の決定
status: accepted
author: tester
---

# FTS 採用の決定

## 根拠

横断検索と規模ヘッドルームのため採用する。台帳は census 専用のまま。
MD
cat > "$ROOT/projB/docs/[Memo] pruning-notes.md" << 'MD'
# Pruning notes

## Importance scoring

Layer-adaptive importance scoring for expert pruning.
MD

# --- 1) 構築（store ルート横断） ---
python3 "$GEN" --base "$ROOT/projA" >/dev/null 2>&1
[ -f "$ROOT/.store-index.db" ] && ok "build: db created at store root" || fail "build: db missing"

NDOCS=$(sqlite3 "$ROOT/.store-index.db" "SELECT count(*) FROM docs" 2>/dev/null)
[ "$NDOCS" = "2" ] && ok "build: 2 docs indexed (cross-project)" || fail "build: docs=$NDOCS (want 2)"

DT=$(sqlite3 "$ROOT/.store-index.db" "SELECT doc_type FROM docs WHERE project='projA'" 2>/dev/null)
[ "$DT" = "decision" ] && ok "build: doc_type=decision" || fail "build: doc_type=$DT"

ST=$(sqlite3 "$ROOT/.store-index.db" "SELECT status FROM docs WHERE project='projA'" 2>/dev/null)
[ "$ST" = "accepted" ] && ok "build: frontmatter status captured" || fail "build: status=$ST"

grep -q '^\.store-index\.db\*$' "$ROOT/.gitignore" 2>/dev/null && ok "gitignore: entry added" || fail "gitignore: entry missing"

# --- 2) 鮮度スキップ（md 変更なし → mtime 不変） ---
M1=$(python3 -c "import os;print(os.stat('$ROOT/.store-index.db').st_mtime_ns)")
sleep 1
python3 "$GEN" --base "$ROOT/projA" >/dev/null 2>&1
M2=$(python3 -c "import os;print(os.stat('$ROOT/.store-index.db').st_mtime_ns)")
[ "$M1" = "$M2" ] && ok "freshness: unchanged store skips rebuild" || fail "freshness: rebuilt without changes"

# --- 3) md 追加 → 再構築される ---
echo "# New doc" > "$ROOT/projB/docs/new.md"
python3 "$GEN" --base "$ROOT/projA" >/dev/null 2>&1
NDOCS=$(sqlite3 "$ROOT/.store-index.db" "SELECT count(*) FROM docs" 2>/dev/null)
[ "$NDOCS" = "3" ] && ok "freshness: newer md triggers rebuild" || fail "freshness: docs=$NDOCS (want 3)"

# gitignore 冪等（2 回目の構築で重複追記しない）
NGI=$(grep -c '^\.store-index\.db\*$' "$ROOT/.gitignore" 2>/dev/null)
[ "$NGI" = "1" ] && ok "gitignore: idempotent (no duplicates)" || fail "gitignore: $NGI entries"

if command -v sqlite3 >/dev/null 2>&1; then
    # --- 4) query: --all 横断 ---
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --all "importance" "pruning" 2>/dev/null)
    printf '%s' "$OUT" | grep -q "projB" && ok "query: --all reaches other project" || fail "query: --all no cross hit"

    # --- 5) query: --project 絞り込み(0 件は黙らず明示・他プロジェクトへは漏れない) ---
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --project projA "importance" "pruning" 2>/dev/null)
    if printf '%s' "$OUT" | grep -q "0 hits" && ! printf '%s' "$OUT" | grep -q "projB"; then
        ok "query: --project filter excludes others (0-hit reported, not silent)"
    else
        fail "query: filter leaked or 0-hit silent: $OUT"
    fi

    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --project projA "横断検索" 2>/dev/null)
    printf '%s' "$OUT" | grep -q "projA" && ok "query: japanese trigram match" || fail "query: ja match failed"

    # --- 6) 短語 LIKE フォールバック（2 文字） ---
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --all "台帳" 2>/dev/null)
    printf '%s' "$OUT" | grep -q "projA" && ok "query: short-term LIKE fallback" || fail "query: short-term failed"

    # --- 7) 行範囲の妥当性（L 開始-終了 を返す） ---
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --all "importance" "pruning" 2>/dev/null)
    printf '%s' "$OUT" | grep -qE 'L[0-9]+-[0-9]+' && ok "query: line ranges present" || fail "query: no line ranges"

    # --- 7.1) AND 0 件 → OR 緩和を明示して再検索（R8: 無言 0 件で弱モデルが諦める問題の修正） ---
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --project projB "importance" "zzznope" 2>/dev/null)
    if printf '%s' "$OUT" | grep -q "OR に緩和" && printf '%s' "$OUT" | grep -q "projB"; then
        ok "query: AND-miss relaxes to OR with explicit notice"
    else
        fail "query: OR relaxation missing: $OUT"
    fi

    # --- 7.2) 完全 0 件でも無言にしない（次の一手を必ず出力） ---
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --all "zzznope9x" 2>/dev/null)
    printf '%s' "$OUT" | grep -q "0 hits" && ok "query: total miss reports next steps" || fail "query: silent 0-hit"
else
    echo "  skip: sqlite3 CLI not found — query tests skipped"
fi

# --- 7.5) [Ref] 所在カード: uri 捕捉 + related: 抽出 + --related 芋づる ---
mkdir -p "$ROOT/projA/docs"
cat > "$ROOT/projA/docs/[Ref] external-sheet.md" << 'MD'
---
title: 外部の集計シート
source: fileserver
uri: smb://nas/share/集計.xlsx
fetched: 2026-07-03
related:
  - decisions/2026-07-02-120000_fts-adoption
---
# 外部の集計シート

FTS 採用の裏付けに使った外部集計。正本は NAS。
MD
python3 "$GEN" --base "$ROOT/projA" --force >/dev/null 2>&1
if command -v sqlite3 >/dev/null 2>&1; then
    U=$(sqlite3 "$ROOT/.store-index.db" "SELECT uri FROM docs WHERE doc_type='ref'")
    [ "$U" = "smb://nas/share/集計.xlsx" ] && ok "ref: uri captured" || fail "ref: uri=$U"
    N=$(sqlite3 "$ROOT/.store-index.db" "SELECT count(*) FROM refs WHERE kind='related'")
    [ "$N" = "1" ] && ok "ref: related edge extracted" || fail "ref: refs=$N (want 1)"
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --related "external-sheet" 2>/dev/null)
    printf '%s' "$OUT" | grep -q "fts-adoption_tester.md" && ok "--related: outgoing resolved (prefix → full path)" || fail "--related: outgoing unresolved"
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --related "fts-adoption" 2>/dev/null)
    printf '%s' "$OUT" | grep -q "external-sheet" && ok "--related: incoming (referenced by) found" || fail "--related: incoming missing"

    # --- 7.6) store ルート直下のファイルを project として索引しない（README.md 残骸の混入防止） ---
    echo "# store readme" > "$ROOT/README.md"
    python3 "$GEN" --base "$ROOT/projA" --force >/dev/null 2>&1
    NR=$(sqlite3 "$ROOT/.store-index.db" "SELECT count(*) FROM docs WHERE project='README.md'")
    [ "$NR" = "0" ] && ok "build: root-level files not indexed as projects" || fail "build: README.md indexed as project (count=$NR)"
fi

# --- 10) rank: decision が同語の doc より上位に来る（doc_type 重み付け） ---
cat > "$ROOT/projA/decisions/2026-07-02-140000_weight-test_tester.md" << 'MD'
---
title: 重み付けテスト用decision
status: accepted
author: tester
---

# 重み付けテスト用decision

## 本文

rankweightprobe を含む一次文書サンプル行。
MD
cat > "$ROOT/projA/docs/weight-test-doc.md" << 'MD'
# 重み付けテスト用doc

## 本文

rankweightprobe を含む派生文書サンプル行。
MD
python3 "$GEN" --base "$ROOT/projA" --force >/dev/null 2>&1
if command -v sqlite3 >/dev/null 2>&1; then
    OUT=$(STORE_QUERY_DB="$ROOT/.store-index.db" sh "$QUERY" --project projA "rankweightprobe" 2>/dev/null)
    FIRSTLINE=$(printf '%s\n' "$OUT" | head -1)
    printf '%s' "$FIRSTLINE" | grep -q "decisions/" && ok "rank: decision weighted above same-term doc" || fail "rank: decision not first: $FIRSTLINE"
fi

# --- 11) sessions/ 配下の md は索引に載らない（checkpoint 除外） ---
mkdir -p "$ROOT/projA/sessions"
cat > "$ROOT/projA/sessions/2026-07-02-150000_checkpoint.md" << 'MD'
# checkpoint

## メモ

セッション checkpoint 本文。
MD
python3 "$GEN" --base "$ROOT/projA" --force >/dev/null 2>&1
if command -v sqlite3 >/dev/null 2>&1; then
    NSESS=$(sqlite3 "$ROOT/.store-index.db" "SELECT count(*) FROM docs WHERE relpath LIKE '%sessions/%'" 2>/dev/null)
    [ "$NSESS" = "0" ] && ok "sessions: checkpoint excluded from index" || fail "sessions: indexed count=$NSESS (want 0)"
fi

# --- 12) fail-open 文言: combined.txt が消え、Grep 案内になっている ---
if grep -q 'combined.txt' "$QUERY"; then
    fail "fail-open: combined.txt reference still present in store-query.sh"
else
    ok "fail-open: combined.txt reference removed"
fi
grep -q 'Grep' "$QUERY" && ok "fail-open: Grep guidance present" || fail "fail-open: Grep guidance missing"

# --- 8) legacy（マーカー無し）: db は base 直下 ---
LEG=$(mktemp -d)
mkdir -p "$LEG/base/decisions"
echo "# Solo doc" > "$LEG/base/decisions/2026-07-02-130000_solo_tester.md"
python3 "$GEN" --base "$LEG/base" >/dev/null 2>&1
[ -f "$LEG/base/.store-index.db" ] && ok "legacy: db placed under base" || fail "legacy: db missing"
rm -rf "$LEG"

# --- 9) fail-open: 存在しない base で exit 0 ---
python3 "$GEN" --base /nonexistent-banto-test 2>/dev/null
[ "$?" = "0" ] && ok "fail-open: missing base exits 0" || fail "fail-open: nonzero exit"

echo ""
echo "test-store-index: $PASS passed, $FAIL failed"
[ "$FAIL" = "0" ] || exit 1
exit 0
