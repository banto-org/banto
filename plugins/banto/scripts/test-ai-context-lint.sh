#!/bin/sh
# test-ai-context-lint.sh — ai-context-lint.sh の合成テスト
#
# 検証（lint は検出のみ・自動修正しない / 常に exit 0）:
#   1. fail-open: base / decisions 不在 → 静かに exit 0
#   2. クリーンな store → "no health issues" + exit 0
#   3. 壊れた相対リンク検出（実在リンクは検出しない / 外部 URL は無視）
#   4. 孤立ファイル検出（参照されているファイルは検出しない）
#   5. 重複（同一 H1 タイトル）検出
#   6. 陳腐化（superseded マーカー + 古い mtime）検出
#   7. 検出後も decisions/ のファイルが 1 つも変更/削除されていない（検出のみの保証）
#   8. fail-open: jq 不在 → exit 0（no-op）
#
# 隔離: 合成 HOME + 合成 store root（AI_CONTEXT_STORE_ROOT）+ 合成 mapping。
#   実 ~/.claude / 実 store には一切触れない。
# POSIX `VAR=val func` の env leak を避けるため run_lint 関数（subshell 実行）を使う。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
LINT="$DIR/scripts/ai-context-lint.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_STORE_ROOT BANTO_IGNORE_FILE BANTO_LINT_STALE_DAYS 2>/dev/null || true

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ai-lint.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude" "$TMP/tmp"
STORE="$FAKE_HOME/ai-context-store"

REPO="$TMP/proj/myrepo"
mkdir -p "$REPO"
git -C "$REPO" init -q
REPO_TOP=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)
PROJ="$STORE/myrepo"
DEC="$PROJ/decisions"
mkdir -p "$DEC" "$PROJ/docs" "$STORE"
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

run_lint() { # [extra KEY=VAL ...]
    env HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" \
        AI_CONTEXT_STORE_ROOT="$STORE" AI_CONTEXT_MAPPING="$STORE/.mapping.json" \
        "$@" sh "$LINT" "$REPO" 2>/dev/null
}

reset_dec() { rm -f "$DEC"/*.md 2>/dev/null; }

# === 1. fail-open: decisions 空（*.md 無し）→ 静かに exit 0 ===
reset_dec
OUT=$(run_lint); rc=$?
[ -z "$OUT" ] && [ "$rc" -eq 0 ] && ok "fail-open: empty decisions is silent, exit 0" || bad "fail-open: empty decisions (rc=$rc out=$OUT)"

# === 2. クリーンな store → no issues, exit 0 ===
reset_dec
cat > "$DEC/2026-01-01_a.md" <<'A'
# Decision A
本文。参照: 2026-01-02_b.md
A
cat > "$DEC/2026-01-02_b.md" <<'B'
# Decision B
本文。参照: 2026-01-01_a.md
B
OUT=$(run_lint); rc=$?
case "$OUT" in
    *"no health issues"*) ok "clean store: reports no issues" ;;
    *) bad "clean store: unexpected output ($OUT)" ;;
esac
[ "$rc" -eq 0 ] && ok "clean store: exit 0 (advisory)" || bad "clean store: nonzero exit ($rc)"

# === 3. 壊れた相対リンク（実在 + 外部 URL は検出しない） ===
reset_dec
cat > "$DEC/2026-02-01_links.md" <<'L'
# Links
[broken](./does-not-exist.md)
[ok](2026-02-02_target.md)
[ext](https://example.com/page)
L
cat > "$DEC/2026-02-02_target.md" <<'T'
# Target
referenced by 2026-02-01_links.md
T
OUT=$(run_lint)
case "$OUT" in
    *"does-not-exist.md"*) ok "broken link detected" ;;
    *) bad "broken link not detected ($OUT)" ;;
esac
case "$OUT" in
    *"example.com"*) bad "external URL wrongly flagged" ;;
    *) ok "external URL ignored" ;;
esac
case "$OUT" in
    *"2026-02-02_target.md)"*) bad "valid existing link wrongly flagged" ;;
    *) ok "valid existing link not flagged" ;;
esac

# === 4. 孤立ファイル（参照ありは検出しない） ===
reset_dec
cat > "$DEC/2026-03-01_referenced.md" <<'R'
# Referenced
R
cat > "$DEC/2026-03-02_orphan.md" <<'O'
# Orphan
O
cat > "$DEC/2026-03-03_pointer.md" <<'P'
# Pointer
see 2026-03-01_referenced.md
P
OUT=$(run_lint)
case "$OUT" in
    *"2026-03-02_orphan.md"*) ok "orphan file detected" ;;
    *) bad "orphan not detected ($OUT)" ;;
esac
# 参照されているファイル名は孤立リストの行に出てはいけない（orphan セクションのみで判定）。
# セクションは "Orphan decisions" 見出しの次行から次の "(N)" 見出し or footer まで。
ORPHAN_SEC=$(printf '%s\n' "$OUT" | awk '/Orphan decisions/{f=1;next} /^\(Fix/{f=0} /^\([0-9]\)/{f=0} f')
case "$ORPHAN_SEC" in
    *2026-03-01_referenced.md*) bad "referenced file wrongly listed as orphan" ;;
    *) ok "referenced file not listed as orphan" ;;
esac

# === 5. 重複（同一 H1 タイトル） ===
reset_dec
printf '# Same Title\nx\n' > "$DEC/2026-04-01_dup1.md"
printf '# Same Title\ny\n' > "$DEC/2026-04-02_dup2.md"
OUT=$(run_lint)
case "$OUT" in
    *"Same Title"*"dup1.md"*) ok "duplicate H1 title detected" ;;
    *"Same Title"*) ok "duplicate H1 title detected" ;;
    *) bad "duplicate title not detected ($OUT)" ;;
esac

# === 6. 陳腐化（superseded + 古い mtime） ===
reset_dec
cat > "$DEC/2020-01-01_old.md" <<'S'
# Old decision
status: superseded by a newer one
S
cat > "$DEC/2026-05-01_fresh.md" <<'F'
# Fresh
references 2020-01-01_old.md
F
# 2 年前へ mtime を戻す（BSD/GNU 両対応の touch -t）。
touch -t 202401010000 "$DEC/2020-01-01_old.md" 2>/dev/null || true
OUT=$(run_lint BANTO_LINT_STALE_DAYS=180)
case "$OUT" in
    *"Stale"*"2020-01-01_old.md"*) ok "stale superseded decision detected" ;;
    *"2020-01-01_old.md (superseded"*) ok "stale superseded decision detected" ;;
    *) bad "stale not detected ($OUT)" ;;
esac

# === 7. 検出のみ: ファイルが 1 つも変更/削除されていない ===
BEFORE=$(ls "$DEC" | sort; cat "$DEC"/*.md 2>/dev/null | md5 2>/dev/null || cat "$DEC"/*.md 2>/dev/null | md5sum 2>/dev/null)
run_lint BANTO_LINT_STALE_DAYS=180 >/dev/null
AFTER=$(ls "$DEC" | sort; cat "$DEC"/*.md 2>/dev/null | md5 2>/dev/null || cat "$DEC"/*.md 2>/dev/null | md5sum 2>/dev/null)
[ "$BEFORE" = "$AFTER" ] && ok "detection-only: decisions unchanged after lint" || bad "detection-only: lint modified files"

# === 8. fail-open: jq 不在 → exit 0（jq の無い最小 PATH で起動） ===
NOJQ_BIN="$TMP/nojq-bin"
mkdir -p "$NOJQ_BIN"
ln -s "$(command -v sh)" "$NOJQ_BIN/sh" 2>/dev/null || cp "$(command -v sh)" "$NOJQ_BIN/sh"
env -i HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" PATH="$NOJQ_BIN" \
    AI_CONTEXT_STORE_ROOT="$STORE" sh "$LINT" "$REPO" >/dev/null 2>&1
[ $? -eq 0 ] && ok "fail-open: no jq -> exit 0 (no-op)" || bad "fail-open: no-jq path did not exit 0"

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
