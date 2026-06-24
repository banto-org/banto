#!/bin/sh
# test-scaffold-root-guard.sh — store ブートストラップ（A1）の検証
# decision 2026-06-24-101500: 未登録 repo では **黙って store を作らず** 対話ブートストラップを
# 1 回だけ促す。登録済みは skeleton を冪等確保。ローカル退避は BANTO_BOOTSTRAP_LOCAL=1 のみ。
# （旧テストは store-first の「自動生成」前提だったが A1 で「無確認生成をやめる」に反転した。）
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

# 実環境を汚さないよう隔離: HOME（bootstrap marker = ~/.claude/banto-bootstrap-asked）/
# store root / denylist をすべて TMP 配下へ。
HOME="$TMP/home"; mkdir -p "$HOME/.claude"
BANTO_IGNORE_FILE="$TMP/empty-ignore"; touch "$BANTO_IGNORE_FILE"
AI_CONTEXT_STORE_ROOT="$TMP/store"
export HOME BANTO_IGNORE_FILE AI_CONTEXT_STORE_ROOT
MAP="$TMP/store/.mapping.json"

# case 1: 未登録 git repo root → repo 側にも store 側にも一切作らず、bootstrap を 1 回案内
R="$TMP/repo"
mkdir -p "$R"; git -C "$R" init -q
OUT1=$(_ai_context_scaffold "$R")
[ ! -e "$R/.ai-context" ]            && ok "unregistered: no local .ai-context"     || bad "unregistered: local .ai-context created"
[ ! -e "$R/.gitignore" ]             && ok "unregistered: no local .gitignore"      || bad "unregistered: local .gitignore created"
[ ! -d "$TMP/store/repo/decisions" ] && ok "unregistered: no store skeleton"        || bad "unregistered: store skeleton created (should defer)"
[ ! -f "$TMP/store/.ai-context-store" ] && ok "unregistered: no store marker"       || bad "unregistered: store marker created (should defer)"
[ ! -f "$MAP" ]                      && ok "unregistered: no mapping registered"     || bad "unregistered: mapping created (should defer)"
printf '%s' "$OUT1" | grep -q 'ブートストラップ' && ok "unregistered: bootstrap prompt emitted" || bad "unregistered: bootstrap prompt missing"

# case 2: repo のサブディレクトリ → toplevel でないので何もしない
S="$R/sub/dir"; mkdir -p "$S"
_ai_context_scaffold "$S" >/dev/null
[ ! -e "$S/.ai-context" ] && ok "subdir: no local .ai-context" || bad "subdir: .ai-context created"
[ ! -f "$MAP" ]           && ok "subdir: no store registration" || bad "subdir: store registration leaked"

# case 3: 非 git dir → skip（どちら側にも生成されない）
N="$TMP/plain"; mkdir -p "$N"
_ai_context_scaffold "$N" >/dev/null
[ ! -e "$N/.ai-context" ]      && ok "non-git: no local .ai-context" || bad "non-git: .ai-context created"
[ ! -e "$TMP/store/plain" ]    && ok "non-git: no store dir"         || bad "non-git: store dir created"

# case 4: should_skip はサブディレクトリを素通り（hook 注入系は止めない＝責務分離）
if _ai_context_should_skip "$S"; then
    bad "should_skip: subdir unexpectedly skipped (workspace injection would die)"
else
    ok "should_skip: subdir still passes (hook keeps running, only scaffold is gated)"
fi

# case 5: nag は 1 回だけ — 2 回目は marker が立っており無言
OUT5=$(_ai_context_scaffold "$R")
[ -z "$OUT5" ] && ok "once-only: second run silent (asked-marker gates the nag)" || bad "once-only: second run re-prompted"

# case 6: ローカル退避（BANTO_BOOTSTRAP_LOCAL=1）→ store 側に登録 + skeleton（明示オプトイン）
RL="$TMP/loc/repo"; mkdir -p "$RL"; git -C "$RL" init -q
OUT6=$(BANTO_BOOTSTRAP_LOCAL=1 _ai_context_scaffold "$RL")
[ -d "$TMP/store/repo/decisions" ]      && ok "local-optin: store skeleton created"   || bad "local-optin: store skeleton missing"
[ -f "$TMP/store/.ai-context-store" ]   && ok "local-optin: store marker created"      || bad "local-optin: store marker missing"
[ "$(jq '.projects | length' "$MAP" 2>/dev/null)" = "1" ] && ok "local-optin: mapping registered" || bad "local-optin: mapping not registered"
printf '%s' "$OUT6" | grep -q 'LOCAL' && ok "local-optin: notice emitted" || bad "local-optin: notice missing"

# case 7: 登録済み → resolver hit で skeleton を冪等確保（再登録せず無言）
OUT7=$(_ai_context_scaffold "$RL")
[ -z "$OUT7" ] && [ "$(jq '.projects | length' "$MAP")" = "1" ] \
    && ok "registered: idempotent skeleton, no duplicate registration, silent" \
    || bad "registered: re-registered or emitted output"

# case 8: dirname 衝突（ローカル退避）→ 決定論 suffix で別 project dir
RL2="$TMP/loc2/repo"; mkdir -p "$RL2"; git -C "$RL2" init -q
# subshell: POSIX keeps `VAR=val func` assignments in the parent when func is a shell
# function — isolate so BANTO_BOOTSTRAP_LOCAL does not leak into later cases.
( BANTO_BOOTSTRAP_LOCAL=1 _ai_context_scaffold "$RL2" ) >/dev/null
[ -d "$TMP/store/repo-2/decisions" ] && ok "collision: second 'repo' derives repo-2" || bad "collision: suffix not applied"
B1=$(sh "$DIR/scripts/_ai-context-paths.sh" --resolve "$RL")
B2=$(sh "$DIR/scripts/_ai-context-paths.sh" --resolve "$RL2")
[ "$B1" != "$B2" ] && ok "collision: two repos resolve to distinct dirs" || bad "collision: same dir ($B1)"

# case 9: grandfather — 既存の repo 内 .ai-context は触らず store 登録もしない
G="$TMP/leg"; mkdir -p "$G/.ai-context/decisions"; git -C "$G" init -q
_ai_context_scaffold "$G" >/dev/null
[ "$(jq '.projects | length' "$MAP")" = "2" ] && ok "grandfather: no store registration" || bad "grandfather: registered to store"
[ ! -e "$TMP/store/leg" ] && ok "grandfather: no store dir" || bad "grandfather: store dir created"

# case 10: BANTO_AI_CONTEXT_CENTRAL_ONLY は no-op（読み捨て）— 未登録なら従来どおり defer
R3="$TMP/co/repo3"; mkdir -p "$R3"; git -C "$R3" init -q
BANTO_AI_CONTEXT_CENTRAL_ONLY=1 _ai_context_scaffold "$R3" >/dev/null
[ ! -e "$TMP/store/repo3" ] && ok "CENTRAL_ONLY: no-op (unregistered still defers)" || bad "CENTRAL_ONLY: created store dir"
[ "$(jq '.projects | length' "$MAP")" = "2" ] && ok "CENTRAL_ONLY: no registration" || bad "CENTRAL_ONLY: registered"

[ "$fail" -eq 0 ] && echo "ALL OK"
exit "$fail"
