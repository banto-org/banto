#!/bin/sh
# ai-context-store-sync.sh — PreCompact / SessionEnd で ai-context 中央 store を非同期 sync する hook。
#
# 目的: checkpoint（compact / clear）の区切りで、store の未 commit / 未 push を自動で同期する。
#       「人間が push を覚えておく」摩擦を消す（自走ハーネス: 例外は checkpoint のみ）。
#
# 設計（compact をブロックしないこと）:
#   git push はネットワーク I/O で hook timeout（10s）を超え得る。compact はコンテキスト保全の
#   生命線なので、sync の遅延/失敗が compact を巻き込んではならない。よって scripts/ai-context-sync.sh を
#   **バックグラウンド（&）で起動し即 return** する。
#   結果ログは ~/.cache/banto/store-sync.log に追記する。
#   （旧実装は store root の .sync.log に書いていたが、store で tracked になると
#    「ログ追記 → 次の sync が自分のログ変更を commit+push → またログ追記」の自己 dirty
#    ループで knowledge 変更ゼロでも churn commit が remote に積もる。store 外に出して根治。
#    2026-06-05 監査 TEST 25/26 で実証）
#
# 対象 store の決め方:
#   cwd から ai-context ベースを解決（_ai-context-paths.sh）。central 運用時のみ動く（legacy は no-op）。
#   marker `.ai-context-store` を持つ store のみ sync スクリプト側で push される（二重の誤爆防止）。
#
# POSIX互換: macOS / Linux / WSL
set -u

INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && exit 0

HOOK_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/hooks"}
[ -z "$HOOK_DIR" ] && HOOK_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
SCRIPTS_DIR=$(cd "$HOOK_DIR/../scripts" 2>/dev/null && pwd)
SYNC="$SCRIPTS_DIR/ai-context-sync.sh"
PATHS="$SCRIPTS_DIR/_ai-context-paths.sh"
[ -f "$SYNC" ] || exit 0

# ai-context ベースを解決。central 運用（base != cwd/.ai-context）の時だけ sync する。
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS" ]; then
    . "$PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD" 2>/dev/null || echo "$CWD/.ai-context")
fi
[ "$AI_BASE" = "$CWD/.ai-context" ] && exit 0   # legacy（in-repo）は no-op
[ -d "$AI_BASE" ] || exit 0

# 非同期で sync（compact をブロックしない）。ログは store 外（自己 dirty 防止）。
LOGDIR="$HOME/.cache/banto"
mkdir -p "$LOGDIR" 2>/dev/null
LOG="$LOGDIR/store-sync.log"
( sh "$SYNC" "$AI_BASE" >> "$LOG" 2>&1; printf '  (synced at %s)\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG" ) &

echo "[AI Context] Syncing the central store asynchronously (commit+push). Results are logged to ${LOG}. clear/compact continues without waiting."
exit 0
