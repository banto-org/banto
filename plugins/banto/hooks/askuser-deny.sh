#!/bin/sh
# askuser-deny.sh — PreToolUse(AskUserQuestion): AskUserQuestion をブロックする
#
# 方針（house policy）: 選択肢の提示は AskUserQuestion を使わず、通常テキストで行う。
#   AskUserQuestion はモーダルで人間の意思決定を強制し、「自走ハーネス」思想に反する。
#   settings.permissions.deny でも止められるが 設定ファイルの上書きで消える事故があったため、
#   plugin hook 側でも deterministic に deny して二重化する（settings 非依存）。
#
# 出力契約 (PreToolUse JSON): permissionDecision = "deny" + exit 0
# 公式仕様: hookSpecificOutput.permissionDecision = "allow" | "deny" | "ask"
#
# 無効化したい場合: 環境変数 BANTO_ALLOW_ASKUSER=1 で透過（一時的なエスケープ）。

[ "${BANTO_ALLOW_ASKUSER:-0}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null)

# jq があれば tool_name を確認（matcher で既に絞られるが二重チェック）。無ければ素通しで deny。
if command -v jq >/dev/null 2>&1; then
    TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    [ -n "$TOOL" ] && [ "$TOOL" != "AskUserQuestion" ] && exit 0
fi

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AskUserQuestion is disabled in this environment (house policy). Present options as plain text and wait for the user's reply. If temporarily needed, it can be re-enabled via the BANTO_ALLOW_ASKUSER=1 environment variable."}}
EOF
exit 0
