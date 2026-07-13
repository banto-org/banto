#!/bin/sh
# checkpoint-autofire.sh（未登録ヘルパー — 直接は呼ばれず、無操作検知/コンテキスト逼迫の
# 2 つのトリガーから detach 起動される）
#
# idle-checkpoint-watch.sh（無操作検知）と checkpoint-recommend.sh（コンテキスト 90% 到達）の
# 両方から呼ばれる、自動 /save-checkpoint 発火の共通処理。セッション単位の排他ロックを
# ここ 1 箇所に集約することで、二重発火防止（トリガー間の排他 + 同一セッション内の再発火抑制）
# を両呼び出し元にコピーせず担保する。
#
# 引数: SESSION_ID TRANSCRIPT CWD CLAUDE_BIN [REASON]
#   REASON はログ用のラベル（idle / context 等）。省略時 idle。
#
# 環境変数:
#   BANTO_IDLE_CHECKPOINT_MODEL   fork のモデルを明示上書き（idle 経路と共有）。
#                                 未指定なら model-policy.json の roles.summarize、
#                                 それも無ければ sonnet。"inherit" でユーザー既定を継承。
#
# fail-open: 引数欠落 / ロック取得失敗（既に発火済み） → 静かに exit 0。
# POSIX互換: macOS / Linux / WSL

SESSION_ID=$1
TRANSCRIPT=$2
CWD=$3
CLAUDE_BIN=$4
REASON=${5:-idle}
[ -z "$SESSION_ID" ] || [ -z "$TRANSCRIPT" ] || [ -z "$CWD" ] || [ -z "$CLAUDE_BIN" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0

# セッション単位の排他ロック（mkdir はアトミック）。idle 経路と context 経路のどちらが先に
# 到達しても、同一セッション内では 1 回しか実際の fork を起動しない。
LOCK="${TMPDIR:-/tmp}/banto-checkpoint-autofire-${SESSION_ID}.lock"
mkdir "$LOCK" 2>/dev/null || exit 0

echo "[$(date '+%Y-%m-%d %H:%M:%S')] auto-firing /save-checkpoint (reason=${REASON}, fork of ${SESSION_ID})"

PROMPT='/save-checkpoint 自動発火（無操作検知またはコンテキスト残量逼迫によるバックグラウンド実行）。ユーザーは不在のため Step 4 の確認は行わず、チェックポイントファイルの作成と clear/compact の推奨判定の出力までで終了すること。/compact・/clear は絶対に実行しない。'

cd "$CWD" 2>/dev/null || exit 0

# モデル解決（ハードコード回避・単一の真実源）:
#   1. BANTO_IDLE_CHECKPOINT_MODEL   明示上書き
#   2. model-policy.json の roles.summarize   正（要約向けの安価な tier）
#   3. sonnet                        policy 欠落 / jq 無し時の最終フォールバック
MODEL=$BANTO_IDLE_CHECKPOINT_MODEL
if [ -z "$MODEL" ]; then
    POLICY="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}/templates/model-policy.json"
    if command -v jq >/dev/null 2>&1 && [ -f "$POLICY" ]; then
        MODEL=$(jq -r '.roles.summarize // empty' "$POLICY" 2>/dev/null)
    fi
    [ -z "$MODEL" ] && MODEL=sonnet
fi
if [ "$MODEL" = "inherit" ]; then
    set --
else
    set -- --model "$MODEL"
fi

# BANTO_IDLE_CHECKPOINT=0: fork 側の Stop hook が再アームして連鎖発火するのを防ぐ
# BANTO_HEADLESS=1: fork 側で対話前提の hook を無効化する
# --allowedTools: 無人実行なので Bash は skill の診断に必要な read-only コマンドに限定
BANTO_IDLE_CHECKPOINT=0 BANTO_HEADLESS=1 "$CLAUDE_BIN" -p "$PROMPT" \
    --resume "$SESSION_ID" --fork-session "$@" \
    --allowedTools "Read" "Glob" "Grep" "Write" \
        "Bash(find:*)" "Bash(ls:*)" "Bash(date:*)" "Bash(wc:*)"
RC=$?
echo "[$(date '+%Y-%m-%d %H:%M:%S')] done (exit ${RC})"

# 保存成功をセッション単位の tmp マーカーへ記録する。statusline（token-monitor.sh 等）が
# これを読んで「💾 HH:MM」を表示できる（token % と同じ tmp file 連携の逆向き）。
# マーカー不在・statusline 未対応でも何も起きない（純粋な追加情報）。
[ "$RC" = "0" ] && date '+%H:%M' > "${TMPDIR:-/tmp}/banto-checkpoint-saved-${SESSION_ID}" 2>/dev/null

# --- fork が書いた最新 checkpoint に workspace 宛先マーカーを刻む（idle-checkpoint-watch.sh と
# 同一ロジック。決定論・skill 非依存） ---
PH="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}/scripts/_ai-context-paths.sh"
if [ "$RC" = "0" ] && [ -f "$PH" ]; then
    WS_BASE=$(sh "$PH" --resolve "$CWD" 2>/dev/null)
    WS_KEY=$(sh "$PH" --ws-key "$CWD" 2>/dev/null)
    if [ -n "$WS_BASE" ] && [ -n "$WS_KEY" ] && [ -d "$WS_BASE/sessions" ]; then
        NEWEST=$(ls -t "$WS_BASE/sessions"/checkpoint-*.md 2>/dev/null | head -1)
        if [ -n "$NEWEST" ] && [ -f "$NEWEST" ] && ! grep -q '^<!-- banto-ws: ' "$NEWEST" 2>/dev/null; then
            NMT=$(stat -c %Y "$NEWEST" 2>/dev/null || stat -f %m "$NEWEST" 2>/dev/null)
            case "$NMT" in ''|*[!0-9]*) NMT=0 ;; esac
            NOW=$(date +%s 2>/dev/null)
            if [ -n "$NOW" ] && [ "$NMT" != "0" ] && [ $(( NOW - NMT )) -le 180 ]; then
                TMP_CK="$NEWEST.wsstamp.$$"
                if { printf '<!-- banto-ws: %s -->\n' "$WS_KEY"; cat "$NEWEST"; } > "$TMP_CK" 2>/dev/null; then
                    mv -f "$TMP_CK" "$NEWEST" 2>/dev/null || rm -f "$TMP_CK" 2>/dev/null
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] stamped ws marker '${WS_KEY}' -> $(basename "$NEWEST")"
                else
                    rm -f "$TMP_CK" 2>/dev/null
                fi
            fi
        fi
    fi
fi
exit 0
