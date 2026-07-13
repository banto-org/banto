#!/bin/sh
# test-ai-context-workspace-autoregister.sh — ai-context-workspace-check.sh の自動登録（S4）検証
#
# 検証:
#   1. スコープ一致が機械判定できる（ファイル名が WORKSPACE.md の topic 文字列を含む）
#      → 「## 関連ドキュメント」へ自動追記し、実行結果のみ通知する
#   2. 冪等: 登録済みファイルは 2 回目に再度追記されない（重複行なし・出力も無し）
#   3. スコープ一致が機械判定できない → 従来どおり add/replace/skip の確認を提示する
#   4. multi モード（WORKSPACE-refs.md あり）は自動登録の対象外のまま（従来の確認を提示）
#
# 隔離: 合成 HOME + 合成 store root（central store）。実 store には一切触れない。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$DIR/hooks/ai-context-workspace-check.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_STORE_ROOT BANTO_IGNORE_FILE 2>/dev/null || true

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ws-autoregister.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"
STORE="$FAKE_HOME/ai-context-store"

REPO="$TMP/proj/myrepo"
mkdir -p "$REPO"
git -C "$REPO" init -q
REPO_TOP=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)
AI_BASE="$STORE/myrepo"
mkdir -p "$AI_BASE/decisions" "$AI_BASE/docs" "$STORE"
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

run_hook() { # tool_name file_path
    printf '%s' "{\"tool_name\":\"$1\",\"tool_input\":{\"file_path\":\"$2\"},\"cwd\":\"$REPO\"}" \
        | env HOME="$FAKE_HOME" AI_CONTEXT_STORE_ROOT="$STORE" AI_CONTEXT_MAPPING="$STORE/.mapping.json" \
        sh "$HOOK" 2>/dev/null
}

# === 1. スコープ一致 → 自動登録 ===
printf '# Workspace: [test] widgetize\n' > "$AI_BASE/WORKSPACE.md"
F1="$AI_BASE/decisions/widgetize-update.md"
printf '# widgetize update\n\ncontent\n' > "$F1"
OUT=$(run_hook Write "$F1")
case "$OUT" in *"auto-registered"*) ok "1: reports auto-registered" ;; *) bad "1: missing auto-registered notice ($OUT)" ;; esac
grep -q '^## 関連ドキュメント' "$AI_BASE/WORKSPACE.md" && ok "1: related-docs heading present" || bad "1: heading missing"
grep -qF 'decisions/widgetize-update.md' "$AI_BASE/WORKSPACE.md" && ok "1: entry appended to WORKSPACE.md" || bad "1: entry missing from WORKSPACE.md"

# === 2. 冪等: 2 回目は無登録・無出力 ===
OUT2=$(run_hook Write "$F1")
[ -z "$OUT2" ] && ok "2: second run for the same file is silent" || bad "2: second run re-emitted output ($OUT2)"
N=$(grep -cF 'decisions/widgetize-update.md' "$AI_BASE/WORKSPACE.md")
[ "$N" -eq 1 ] && ok "2: no duplicate entry written" || bad "2: expected 1 entry, found $N"

# === 3. スコープ一致が機械判定できない → 従来どおりの確認プロンプト ===
F3="$AI_BASE/decisions/unrelated-report.md"
printf '# unrelated report\n\ncontent\n' > "$F3"
OUT3=$(run_hook Write "$F3")
case "$OUT3" in
    *"is not registered"*) ok "3: no scope match falls back to the manual prompt" ;;
    *) bad "3: unexpected output for a non-matching file ($OUT3)" ;;
esac
grep -qF 'decisions/unrelated-report.md' "$AI_BASE/WORKSPACE.md" \
    && bad "3: non-matching file was wrongly auto-registered" \
    || ok "3: non-matching file left unregistered"

# === 4. multi モードは対象外のまま ===
printf '# refs\n' > "$AI_BASE/WORKSPACE-refs.md"
F4="$AI_BASE/decisions/widgetize-multi.md"
printf '# widgetize multi\n\ncontent\n' > "$F4"
OUT4=$(run_hook Write "$F4")
case "$OUT4" in
    *"multi mode"*) ok "4: multi mode still shows the manual multi-mode prompt" ;;
    *) bad "4: multi mode unexpectedly auto-registered or changed output ($OUT4)" ;;
esac
grep -qF 'decisions/widgetize-multi.md' "$AI_BASE/WORKSPACE.md" \
    && bad "4: multi mode wrongly auto-registered into WORKSPACE.md" \
    || ok "4: multi mode did not auto-register"
rm -f "$AI_BASE/WORKSPACE-refs.md"

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
