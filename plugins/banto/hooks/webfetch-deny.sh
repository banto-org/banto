#!/bin/sh
# webfetch-deny.sh — PreToolUse(WebFetch): WebFetch をブロックする
#
# 方針（evidence-first rule）: WebFetch は取得ページを小型モデルが要約して返すため、
#   本体モデルが原文を検証できない（脱落・歪みが混入する）。URL の精読は webread
#   （trafilatura による全文抽出）に一本化する。散文の禁止宣言だけでは drift するため、
#   askuser-deny.sh と同型の deterministic な deny で enforcement 化する（2026-06-12 監査 H-19）。
#
# 出力契約 (PreToolUse JSON): permissionDecision = "deny" + exit 0
# 無効化したい場合: 環境変数 BANTO_ALLOW_WEBFETCH=1 で透過（一時的なエスケープ）。

[ "${BANTO_ALLOW_WEBFETCH:-0}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null)

# jq があれば tool_name を確認（matcher で既に絞られるが二重チェック）。無ければ素通しで deny。
if command -v jq >/dev/null 2>&1; then
    TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    [ -n "$TOOL" ] && [ "$TOOL" != "WebFetch" ] && exit 0
fi

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"WebFetch is disabled (evidence-first rule: it returns a small-model summary, so the body cannot be verified). Read URLs with webread instead: sh \"$CLAUDE_PLUGIN_ROOT/scripts/webread.sh\" <URL> (full text via trafilatura). For URL discovery use WebSearch; for multi-page investigations delegate to the research-agent. Temporary escape: BANTO_ALLOW_WEBFETCH=1."}}
EOF
exit 0
