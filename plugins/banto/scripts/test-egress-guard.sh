#!/bin/sh
# test-egress-guard.sh — egress-guard（NDA 保護の中核）の hermetic テスト
# 対象: literal / regex ヒットの block、複数行 content、Edit(new_string) 走査、
#   内部パス免除（BANTO_EGRESS_SAFE_PATHS）、escape（BANTO_ALLOW_NAMES）、registry 不在 no-op。
# BANTO_NAME_REGISTRY 環境変数で一時 registry を指す（実 registry に依存しない）。
# 経緯: 2026-06-12 監査 H-12（fail-open 設計のためリグレッションで無言素通しになるのに 0 テストだった）
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$DIR/../hooks/egress-guard.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found (guard is a documented no-op)"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/egress-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# 一時 registry（実在の内部名は使わない — テスト専用の架空名）
REG="$TMP/registry"
cat > "$REG" <<'EOF'
# test registry
Testperson Taro
re:TESTCODE-[0-9]+
EOF

CLIENT="$TMP/client-repo"
mkdir -p "$CLIENT"

run_write() {  # $1=file_path $2=content $3=extra-env → exit code
    payload=$(jq -c -n --arg fp "$1" --arg c "$2" \
        '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
    printf '%s' "$payload" | env BANTO_NAME_REGISTRY="$REG" ${3:-} sh "$HOOK" >/dev/null 2>&1
}
run_edit() {  # $1=file_path $2=new_string → exit code
    payload=$(jq -c -n --arg fp "$1" --arg ns "$2" \
        '{tool_name:"Edit", tool_input:{file_path:$fp, new_string:$ns}}')
    printf '%s' "$payload" | env BANTO_NAME_REGISTRY="$REG" sh "$HOOK" >/dev/null 2>&1
}

# === block 正例 ===
run_write "$CLIENT/report.md" "担当: Testperson Taro が対応します"; [ $? -eq 2 ] \
    && ok "literal name in client write blocked" || bad "literal name not blocked"
run_write "$CLIENT/spec.md" "case id: TESTCODE-42 を参照"; [ $? -eq 2 ] \
    && ok "regex (re:) hit blocked" || bad "regex hit not blocked"
run_write "$CLIENT/multi.md" "line1 clean
line2 clean
line3 Testperson Taro appears here"; [ $? -eq 2 ] \
    && ok "multiline content scanned (hit on line 3)" || bad "multiline content not scanned"
run_edit "$CLIENT/edit.md" "updated by Testperson Taro"; [ $? -eq 2 ] \
    && ok "Edit new_string scanned" || bad "Edit new_string not scanned"

# === 通過負例 ===
run_write "$CLIENT/clean.md" "完全にクリーンな内容です"; [ $? -eq 0 ] \
    && ok "clean content passes" || bad "clean content blocked (false positive)"
run_write "$CLIENT/near.md" "TESTCODE-x は数字でないので不一致"; [ $? -eq 0 ] \
    && ok "regex near-miss passes" || bad "regex near-miss blocked"

# === 内部パス免除（BANTO_EGRESS_SAFE_PATHS） ===
SAFE="$TMP/internal-notes"
mkdir -p "$SAFE"
run_write "$SAFE/memo.md" "Testperson Taro の連絡先メモ" "BANTO_EGRESS_SAFE_PATHS=$SAFE"; [ $? -eq 0 ] \
    && ok "BANTO_EGRESS_SAFE_PATHS exemption works" || bad "safe-path exemption broken"

# === escape ===
run_write "$CLIENT/allowed.md" "Testperson Taro（本人承諾済み掲載）" "BANTO_ALLOW_NAMES=1"; [ $? -eq 0 ] \
    && ok "BANTO_ALLOW_NAMES=1 escape works" || bad "escape broken"

# === registry 不在 / 空 → no-op ===
payload=$(jq -c -n --arg fp "$CLIENT/x.md" '{tool_name:"Write", tool_input:{file_path:$fp, content:"Testperson Taro"}}')
printf '%s' "$payload" | env BANTO_NAME_REGISTRY="$TMP/no-such-registry" sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "missing registry = no-op (fail-open as designed)" || bad "missing registry blocked"
: > "$TMP/empty-reg"
printf '%s' "$payload" | env BANTO_NAME_REGISTRY="$TMP/empty-reg" sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "empty registry = no-op" || bad "empty registry blocked"

echo
[ "$fail" = "0" ] && { echo "ALL OK (test-egress-guard)"; exit 0; } || { echo "FAILURES (test-egress-guard)"; exit 1; }
