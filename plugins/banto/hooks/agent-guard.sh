#!/bin/sh
# agent-guard.sh — PreToolUse フック (matcher: Task|Agent = サブエージェント起動ツール。2.1.63 で Task→Agent 改名、両対応)
# サブエージェント起動前にClaude Codeのマルチエージェントパターンを適用
#
# exit 0 → 許可
# exit 2 → Claudeに再考を促す

INPUT=$(cat)
TOOL_INPUT=$(printf '%s' "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null)

[ -z "$TOOL_INPUT" ] && exit 0

# エージェントのプロンプトを取得
PROMPT=$(printf '%s' "$TOOL_INPUT" | jq -r '.prompt // empty' 2>/dev/null)

[ -z "$PROMPT" ] && exit 0

PROMPT_LEN=${#PROMPT}

# パターン: プロンプトが短すぎる（100文字未満）→ コンテキスト不足の可能性
if [ "$PROMPT_LEN" -lt 100 ]; then
  echo "[Harness Agent] The agent prompt is too short (${PROMPT_LEN} chars). Claude Code pattern: workers do not implicitly inherit the parent's context. Include the goal, target files, success criteria, and coding conventions." >&2
  exit 2
fi

exit 0
