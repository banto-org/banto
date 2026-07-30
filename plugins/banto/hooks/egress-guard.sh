#!/bin/sh
# egress-guard.sh — PreToolUse(Write|Edit|NotebookEdit) guard。
# 内部メンバー名 / 他案件名 / PII が客先成果物（egress パス）へ流出するのを検出してブロックする。
# secret 保護（safety 系）の兄弟。ロジックは egress-guard.py（堅牢な複数行 content 走査のため python3）。
#
# 設計: decisions/2026-05-30_001_ai-context-pii-name-isolation_tatsuru-okada-business.md
#
# レジストリ: ~/.claude/banto-name-registry（user-scope, 1 行 1 名前/`re:`正規表現, # コメント可）
#   ※ レジストリ自体は repo / store に置かない（名前一覧の漏洩防止）。
# escape: BANTO_ALLOW_NAMES=1
#
# 早期 no-op（導入前/環境差でユーザーを壊さない）:
#   - escape 指定時 / レジストリ未設置 or 実質空 / python3 不在
set -u

# escape ハッチ
[ "${BANTO_ALLOW_NAMES:-0}" = "1" ] && exit 0

REGISTRY="${BANTO_NAME_REGISTRY:-$HOME/.claude/banto-name-registry}"
[ -f "$REGISTRY" ] || exit 0
# コメント/空行以外が 1 行も無ければ no-op
grep -qvE '^[[:space:]]*(#.*)?$' "$REGISTRY" 2>/dev/null || exit 0

# python3 が無ければ no-op（盲目的ブロックはしない）
command -v python3 >/dev/null 2>&1 || exit 0

DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks"
exec python3 "$DIR/egress-guard.py" "$REGISTRY"
