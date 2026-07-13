#!/bin/sh
# test-drift-commit-guard.sh — drift-commit-guard.sh の合成 payload テスト（warn only, no block）
# 対象: plugins/banto/ staged 変更 + plugin.json 未同梱 → warn / 同梱時は無警告 /
#   非 banto リポジトリでは no-op / 非 commit コマンドでは no-op。
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$DIR/../hooks/drift-commit-guard.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/drift-guard-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

run_hook() {  # $1=command $2=cwd → stdout=stderr, exit code は $? に残る
    printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":%s}' \
        "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" \
        | sh "$HOOK" 2>&1 >/dev/null
}

# --- fixture: banto リポジトリ相当 ---
BANTO_REPO="$TMP/banto-repo"
mkdir -p "$BANTO_REPO/plugins/banto/.claude-plugin" "$BANTO_REPO/plugins/banto/hooks"
git init -q -b main "$BANTO_REPO"
printf '{"name":"banto","version":"1.0.0"}' > "$BANTO_REPO/plugins/banto/.claude-plugin/plugin.json"
printf 'x' > "$BANTO_REPO/plugins/banto/hooks/foo.sh"
( cd "$BANTO_REPO" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init )

# --- fixture: banto ではない一般リポジトリ ---
PLAIN_REPO="$TMP/plain-repo"
git init -q -b main "$PLAIN_REPO"
printf 'x' > "$PLAIN_REPO/foo.txt"
( cd "$PLAIN_REPO" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init )

# === version bump 忘れ: hooks/ 変更のみ staged, plugin.json は無変更 ===
( cd "$BANTO_REPO" && printf 'y' >> plugins/banto/hooks/foo.sh && git add plugins/banto/hooks/foo.sh )
_out=$(run_hook 'git commit -m x' "$BANTO_REPO"); _rc=$?
[ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -q "possible missed version bump" \
    && ok "warns when plugins/banto/ staged without plugin.json bump" || bad "missing warning for version-bump drift"

# === plugin.json も同梱 → 無警告 ===
( cd "$BANTO_REPO" && printf '{"name":"banto","version":"1.0.1"}' > plugins/banto/.claude-plugin/plugin.json && git add plugins/banto/.claude-plugin/plugin.json )
_out=$(run_hook 'git commit -m x' "$BANTO_REPO"); _rc=$?
[ "$_rc" -eq 0 ] && ! printf '%s' "$_out" | grep -q "possible missed version bump" \
    && ok "no warning when plugin.json bump is included" || bad "false warning despite plugin.json bump"
( cd "$BANTO_REPO" && git commit -q -m "bump" )

# === 非 banto リポジトリでは no-op ===
( cd "$PLAIN_REPO" && printf 'y' >> foo.txt && git add foo.txt )
_out=$(run_hook 'git commit -m x' "$PLAIN_REPO"); _rc=$?
[ "$_rc" -eq 0 ] && [ -z "$_out" ] \
    && ok "no-op outside a banto repository" || bad "unexpected output/exit for non-banto repo"

# === 非 commit コマンドでは no-op ===
_out=$(run_hook 'git status' "$BANTO_REPO"); _rc=$?
[ "$_rc" -eq 0 ] && [ -z "$_out" ] \
    && ok "non-commit command is a no-op" || bad "non-commit command produced output"

# === fail-open ===
printf 'not-json' | sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "fail-open: garbage payload exits 0" || bad "fail-open: garbage payload non-zero"

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; else echo "FAILURES PRESENT"; exit 1; fi
