#!/bin/sh
# Idle Checkpoint Watcher（未登録ヘルパー — idle-checkpoint.sh から detach 起動される）
# 引数: SESSION_ID TRANSCRIPT_PATH CWD CLAUDE_BIN
# transcript の mtime を監視し、しきい値（分）以上更新が止まったら
# `claude -p --resume <sid> --fork-session` で /save-checkpoint を 1 回だけ発火して終了。
# fork なので元セッションの transcript には一切書き込まれない。
#
# 設計メモ:
# - pid ファイルは所有権トークン。起動時に $$ を書き、中身が自分でなくなったら
#   （SessionEnd の解除・後継ウォッチャーの起動・tmp 掃除での消失）即退場する。
# - マシンのスリープ対策: 「覚醒中に観測できた無操作時間」を別途積算し、
#   mtime 差としきい値超えの両方を満たしたときだけ発火する。これが無いと
#   ラップトップを閉じて離席 → 翌朝開いた瞬間（＝ユーザー復帰の瞬間）に発火する。
#
# 環境変数（アーム時の環境を継承）:
#   BANTO_IDLE_CHECKPOINT_MIN=N        無操作しきい値（分、既定 5 = プロンプトキャッシュ
#                                      TTL に一致。transcript の mtime ≈ 最後の API 活動
#                                      なので「最後の API コールから 5 分 = 失効直後」に発火）
#   BANTO_IDLE_CHECKPOINT_MIN_PCT=N    発火に必要な最小コンテキスト使用率（既定 10、
#                                      token-monitor statusline 導入時のみ有効）
#   BANTO_IDLE_CHECKPOINT_MIN_BYTES=N  % が取れないときの代替: transcript の最小バイト数
#                                      （既定 262144 = 256KB。小さいセッションは
#                                       キャッシュ切れコストも小さく checkpoint 不要）
#   BANTO_IDLE_CHECKPOINT_MODEL=NAME   fork のモデルを明示上書き。未指定なら
#                                      model-policy.json の roles.summarize（正）を読む。
#                                      "inherit" でユーザー既定を継承
#   BANTO_IDLE_CHECKPOINT_POLL=N       最小監視間隔（秒、既定 60。テスト用）

SESSION_ID=$1
TRANSCRIPT=$2
CWD=$3
CLAUDE_BIN=$4
[ -z "$SESSION_ID" ] || [ -z "$TRANSCRIPT" ] || [ -z "$CWD" ] || [ -z "$CLAUDE_BIN" ] && exit 0

THRESHOLD_MIN=${BANTO_IDLE_CHECKPOINT_MIN:-5}
case "$THRESHOLD_MIN" in ''|*[!0-9]*) THRESHOLD_MIN=5 ;; esac
POLL=${BANTO_IDLE_CHECKPOINT_POLL:-60}
case "$POLL" in ''|*[!0-9]*) POLL=60 ;; esac
THRESHOLD_SEC=$(( THRESHOLD_MIN * 60 ))

PID_FILE="${TMPDIR:-/tmp}/banto-idle-checkpoint-${SESSION_ID}.pid"
echo "$$" > "$PID_FILE" 2>/dev/null || exit 0

# 所有権トークン: pid ファイルが消えた/他者になったら自分は正規ウォッチャーではない
own() { [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; }
cleanup() { own && rm -f "$PID_FILE"; }
trap cleanup EXIT
# TERM/INT（SessionEnd からの解除）で即終了する。sleep はバックグラウンド + wait に
# しないと foreground の sleep が終わるまでシグナル処理が遅延する
trap 'cleanup; trap - EXIT; exit 0' INT TERM

mtime_of() {
    # GNU (Linux/WSL) が先: BSD/macOS では -c が即エラーで stdout を汚さない。
    # 逆順にすると GNU の `stat -f`（filesystem 表示）が fs 情報を stdout に吐いて壊れる
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

AWAKE=0
SLEPT_FOR=0
LAST=$(date +%s)
while :; do
    [ -f "$TRANSCRIPT" ] || exit 0
    own || { trap - EXIT; exit 0; }
    MTIME=$(mtime_of "$TRANSCRIPT")
    case "$MTIME" in ''|*[!0-9]*) exit 0 ;; esac
    NOW=$(date +%s)

    # 覚醒中の経過だけを積算（前回の起床から想定以上に時間が飛んでいたらスリープと判定してリセット）
    GAP=$(( NOW - LAST ))
    LAST=$NOW
    if [ "$GAP" -gt $(( SLEPT_FOR + 120 )) ]; then
        AWAKE=0
    else
        AWAKE=$(( AWAKE + GAP ))
    fi

    IDLE=$(( NOW - MTIME ))
    [ "$IDLE" -lt 0 ] && IDLE=0
    if [ "$IDLE" -ge "$THRESHOLD_SEC" ] && [ "$AWAKE" -ge "$THRESHOLD_SEC" ]; then
        break
    fi

    # 次の判定時刻まで適応スリープ（毎分起床の無駄を避ける。最短 POLL 秒）
    REMAIN=$(( THRESHOLD_SEC - IDLE ))
    [ "$REMAIN" -lt "$POLL" ] && REMAIN=$POLL
    SLEPT_FOR=$REMAIN
    sleep "$REMAIN" & wait $!
done

# 発火直前にも所有権を確認（並走ウォッチャーの二重発火防止）
own || { trap - EXIT; exit 0; }

# コンテキスト量ガード: 小さいセッションはキャッシュ切れコストも小さいので発火しない。
# token-monitor の % ファイルがあればそれを、無ければ transcript サイズで代用判定
MIN_PCT=${BANTO_IDLE_CHECKPOINT_MIN_PCT:-10}
case "$MIN_PCT" in ''|*[!0-9]*) MIN_PCT=10 ;; esac
TOKEN_FILE="${TMPDIR:-/tmp}/banto-token-pct-${SESSION_ID}"
if [ -f "$TOKEN_FILE" ]; then
    RAW=$(cat "$TOKEN_FILE" 2>/dev/null)
    PCT=$(printf '%.0f' "$RAW" 2>/dev/null || printf '%s' "$RAW" | cut -d. -f1)
    case "$PCT" in
        ''|*[!0-9]*) ;;
        *) if [ "$PCT" -lt "$MIN_PCT" ]; then
               echo "[$(date '+%Y-%m-%d %H:%M:%S')] skip: context ${PCT}% < ${MIN_PCT}%"
               exit 0
           fi ;;
    esac
else
    MIN_BYTES=${BANTO_IDLE_CHECKPOINT_MIN_BYTES:-262144}
    case "$MIN_BYTES" in ''|*[!0-9]*) MIN_BYTES=262144 ;; esac
    SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')
    case "$SIZE" in
        ''|*[!0-9]*) ;;
        *) if [ "$SIZE" -lt "$MIN_BYTES" ]; then
               echo "[$(date '+%Y-%m-%d %H:%M:%S')] skip: transcript ${SIZE}B < ${MIN_BYTES}B"
               exit 0
           fi ;;
    esac
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] idle ${THRESHOLD_MIN}min reached — firing /save-checkpoint (fork of ${SESSION_ID})"

PROMPT='/save-checkpoint 自動発火（無操作検知によるバックグラウンド実行）。ユーザーは不在のため Step 4 の確認は行わず、チェックポイントファイルの作成と clear/compact の推奨判定の出力までで終了すること。/compact・/clear は絶対に実行しない。'

cd "$CWD" 2>/dev/null || exit 0

# モデル解決（ハードコード回避・単一の真実源）:
#   1. BANTO_IDLE_CHECKPOINT_MODEL   明示上書き
#   2. model-policy.json の roles.summarize   正（要約向けの安価な tier）
#   3. sonnet                        policy 欠落 / jq 無し時の最終フォールバック
# この機能の動機はコスト削減なので要約向けの安価な tier を使う。"inherit" はユーザー既定を継承。
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
# BANTO_HEADLESS=1: fork 側で対話前提の hook（checkpoint 消費 / fleet 登録 /
#                   decision 催促 / learnings ドラフト）を無効化する
# --allowedTools: 無人実行なので Bash は skill の診断に必要な read-only コマンドに限定
#                 （裸の Bash はプロンプトインジェクション時の任意実行経路になる）
BANTO_IDLE_CHECKPOINT=0 BANTO_HEADLESS=1 "$CLAUDE_BIN" -p "$PROMPT" \
    --resume "$SESSION_ID" --fork-session "$@" \
    --allowedTools "Read" "Glob" "Grep" "Write" \
        "Bash(find:*)" "Bash(ls:*)" "Bash(date:*)" "Bash(wc:*)"
RC=$?
echo "[$(date '+%Y-%m-%d %H:%M:%S')] done (exit ${RC})"
exit 0
