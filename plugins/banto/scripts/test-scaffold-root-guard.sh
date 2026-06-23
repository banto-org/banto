#!/bin/sh
# test-scaffold-root-guard.sh — store-first scaffold の検証
# 「repo 内に生成されない + store 側に登録・生成される」を保証する（spec 2026-06-11
# store-first-architecture / 受け入れ基準 2・4・5）。旧テスト（local 生成の toplevel
# ガード）は store-first flip で反転した。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
# 実 plugin cache / 実 store に触れない（テスト決定論）
unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING
. "$DIR/hooks/_ai-context-scaffold.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/scaffold-guard-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# テスト環境の ~/.claude/banto-ignore / 実 store に影響されないよう隔離
BANTO_IGNORE_FILE="$TMP/empty-ignore"
AI_CONTEXT_STORE_ROOT="$TMP/store"
export BANTO_IGNORE_FILE AI_CONTEXT_STORE_ROOT
touch "$BANTO_IGNORE_FILE"
MAP="$TMP/store/.mapping.json"

# case 1: git repo root → repo 内には何も作られず、store 側に登録 + skeleton
R="$TMP/repo"
mkdir -p "$R"
git -C "$R" init -q
_ai_context_scaffold "$R" >/dev/null
[ ! -e "$R/.ai-context" ] && ok "repo root: no local .ai-context" || bad "repo root: local .ai-context created"
[ ! -e "$R/.gitignore" ] && ok "repo root: no local .gitignore" || bad "repo root: local .gitignore created"
[ -d "$TMP/store/repo/decisions" ] && ok "repo root: store skeleton created" || bad "repo root: store skeleton missing"
[ -f "$TMP/store/.ai-context-store" ] && ok "repo root: store marker created" || bad "repo root: store marker missing"
[ "$(jq '.projects | length' "$MAP" 2>/dev/null)" = "1" ] && ok "repo root: mapping registered" || bad "repo root: mapping not registered"

# case 2: repo のサブディレクトリ → repo 側にも store 側にも何も起きない
S="$R/sub/dir"
mkdir -p "$S"
_ai_context_scaffold "$S" >/dev/null
[ ! -e "$S/.ai-context" ] && ok "subdir: no local .ai-context" || bad "subdir: .ai-context created"
[ "$(jq '.projects | length' "$MAP")" = "1" ] && ok "subdir: no new store registration" || bad "subdir: store registration leaked"

# case 3: 非 git dir → どちら側にも生成されない
N="$TMP/plain"
mkdir -p "$N"
_ai_context_scaffold "$N" >/dev/null
[ ! -e "$N/.ai-context" ] && ok "non-git: no local .ai-context" || bad "non-git: .ai-context created"
[ ! -e "$TMP/store/plain" ] && ok "non-git: no store dir" || bad "non-git: store dir created"

# case 4: should_skip はサブディレクトリを素通りする（hook の注入系は止めない責務分離）
if _ai_context_should_skip "$S"; then
    bad "should_skip: subdir unexpectedly skipped (workspace injection would die)"
else
    ok "should_skip: subdir still passes (hook keeps running, only scaffold is gated)"
fi

# case 5: 冪等性 — 2 回目は再登録せず無言で成功（受け入れ基準 2）
OUT=$(_ai_context_scaffold "$R")
[ -z "$OUT" ] && [ "$(jq '.projects | length' "$MAP")" = "1" ] \
    && ok "idempotent: second run silent, no duplicate registration" \
    || bad "idempotent: second run re-registered or emitted output"

# case 6: dirname 衝突 → 決定論 suffix で別 project dir（受け入れ基準 4）
R2="$TMP/other/repo"
mkdir -p "$R2"
git -C "$R2" init -q
_ai_context_scaffold "$R2" >/dev/null
[ -d "$TMP/store/repo-2/decisions" ] && ok "collision: second 'repo' derives repo-2" || bad "collision: suffix not applied"
B1=$(sh "$DIR/scripts/_ai-context-paths.sh" --resolve "$R")
B2=$(sh "$DIR/scripts/_ai-context-paths.sh" --resolve "$R2")
[ "$B1" != "$B2" ] && ok "collision: two repos resolve to distinct dirs" || bad "collision: same dir ($B1)"

# case 7: grandfather — 既存の repo 内 .ai-context は触らず、store 登録もしない
G="$TMP/leg"
mkdir -p "$G/.ai-context/decisions"
git -C "$G" init -q
_ai_context_scaffold "$G" >/dev/null
[ "$(jq '.projects | length' "$MAP")" = "2" ] && ok "grandfather: no store registration" || bad "grandfather: registered to store"
[ ! -e "$TMP/store/leg" ] && ok "grandfather: no store dir" || bad "grandfather: store dir created"

# case 8: BANTO_AI_CONTEXT_CENTRAL_ONLY は no-op（読み捨て・挙動不変）
R3="$TMP/co/repo3"
mkdir -p "$R3"
git -C "$R3" init -q
BANTO_AI_CONTEXT_CENTRAL_ONLY=1 _ai_context_scaffold "$R3" >/dev/null
[ -d "$TMP/store/repo3/decisions" ] && ok "CENTRAL_ONLY: no-op (still scaffolds store-side)" || bad "CENTRAL_ONLY: still gates scaffold"

[ "$fail" -eq 0 ] && echo "ALL OK"
exit "$fail"
