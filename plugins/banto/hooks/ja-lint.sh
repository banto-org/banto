#!/bin/sh
# ja-lint.sh — PostToolUse(Write|Edit) 警告フック
# .md への日本語書き込みが writing-ja.md の規約から外れていないかを検査する（warn only）。
# ロジックは ja-lint.py（Unicode 範囲判定のため python3。egress-guard.sh と同じ委譲構成）。
#
# 早期 no-op: python3 不在（盲目的にはスキップしない — CONTRACT.md の fail-open 方針）
set -u

command -v python3 >/dev/null 2>&1 || exit 0

DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks"
exec python3 "$DIR/ja-lint.py"
