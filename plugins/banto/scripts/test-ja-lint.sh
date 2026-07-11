#!/bin/sh
# test-ja-lint.sh — ja-lint.sh の合成 payload テスト（warn only, no block）
# 対象: 文末規則違反 / 半角スペース欠落 / 経緯メタ情報パターンの検出、
#   コードフェンス・引用行の除外、.md 以外・i18n/en・日本語閾値未満の no-op、Edit(new_string) 経路。
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$DIR/../hooks/ja-lint.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found (guard is a documented no-op)"; exit 0; }

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

run_write() {  # $1=file_path $2=content → stdout=stdout（fed back to Claude per CONTRACT.md）
    payload=$(jq -c -n --arg fp "$1" --arg c "$2" '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
    printf '%s' "$payload" | sh "$HOOK"
}
run_edit() {  # $1=file_path $2=new_string
    payload=$(jq -c -n --arg fp "$1" --arg ns "$2" '{tool_name:"Edit", tool_input:{file_path:$fp, new_string:$ns}}')
    printf '%s' "$payload" | sh "$HOOK"
}

VIOLATIONS='# タイトル

これは説明です。
Claudeを使ってRAGを構築する。
（新規）この機能を追加しました。

> これは引用です。無視されるはず。

```
これはコードフェンス内です。
```
'

# === block 系なし: 常に exit 0 ===
run_write "/x/report.md" "$VIOLATIONS" >/dev/null; [ $? -eq 0 ] \
    && ok "always exit 0 (warn only)" || bad "unexpected non-zero exit"

# === 検出正例 ===
_out=$(run_write "/x/report.md" "$VIOLATIONS")
printf '%s' "$_out" | grep -q "sentence ends with" \
    && ok "detects です。/ます。/だ。/である。 sentence endings" || bad "missed sentence-end violation"
printf '%s' "$_out" | grep -q "missing half-width space" \
    && ok "detects missing half-width space at JA/ASCII boundary" || bad "missed spacing violation"
printf '%s' "$_out" | grep -q "process-history annotation" \
    && ok "detects process-history meta annotation" || bad "missed meta-annotation violation"

# === 除外系: コードフェンス内・引用行は誤検知しない ===
printf '%s' "$_out" | grep -q "コードフェンス内" \
    && bad "false positive inside a code fence" || ok "code fence content is excluded"
printf '%s' "$_out" | grep -q "これは引用です" \
    && bad "false positive on a quoted line" || ok "quoted line is excluded"

# === no-op 系 ===
run_write "/x/report.txt" "$VIOLATIONS" | grep -q . \
    && bad "non-.md file produced output" || ok "non-.md file is a no-op"
run_write "/x/i18n/en/skills/foo/SKILL.md" "$VIOLATIONS" | grep -q . \
    && bad "i18n/en path produced output" || ok "i18n/en path is excluded"
run_write "/x/short.md" "これはです。" | grep -q . \
    && bad "below-JA-threshold file produced output" || ok "below JA-char threshold is a no-op"

# === Edit(new_string) 経路 ===
run_edit "/x/report.md" "$VIOLATIONS" | grep -q "sentence ends with" \
    && ok "Edit(new_string) is scanned the same as Write(content)" || bad "Edit path not scanned"

# === fail-open ===
printf 'not-json' | sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "fail-open: garbage payload exits 0" || bad "fail-open: garbage payload non-zero"

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; else echo "FAILURES PRESENT"; exit 1; fi
