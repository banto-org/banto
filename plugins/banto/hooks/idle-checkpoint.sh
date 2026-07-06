#!/bin/sh
# Idle Checkpoint Hook (Stop = arm / SessionEnd = disarm)
# 応答完了ごとにウォッチャー（idle-checkpoint-watch.sh）をアームし、transcript が
# BANTO_IDLE_CHECKPOINT_MIN 分（既定 5 = キャッシュ TTL）更新されなければ `claude -p --resume
# --fork-session` のヘッドレス実行で /save-checkpoint を自動発火させる。
# 動機: 放置でプロンプトキャッシュ（TTL 5分/1h）が切れた後にセッションを続けると、
# 巨大コンテキストをコールド価格で読み直す。放置検知の時点で checkpoint を切って
# おけば、復帰時は /clear + SessionStart 再注入で安く再開できる。
#
# SessionEnd では既存ウォッチャーを kill する（正常終了したセッションに対して
# しきい値経過後の無駄なヘッドレス実行を走らせない）。
#
# pid ファイルは「所有権トークン」: ウォッチャー自身が起動時に $$ を書き、
# 中身が自分でなくなったら退場する。ここでは生存 + 素性（コマンド名）を確認する。
#
# 環境変数:
#   BANTO_IDLE_CHECKPOINT=0        機能を無効化（SessionEnd の解除だけは常に走る）
#   BANTO_IDLE_CHECKPOINT_MIN=N    無操作しきい値（分、既定 5）
# POSIX 互換: macOS / Linux / WSL。fail-open（依存欠如は常に exit 0）。

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0
case "$SESSION_ID" in *[!A-Za-z0-9_-]*) exit 0 ;; esac

EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
PID_FILE="${TMPDIR:-/tmp}/banto-idle-checkpoint-${SESSION_ID}.pid"

# pid の素性確認: 生きていて、かつ本当にウォッチャーか（PID 再利用の誤殺防止）。
# ps が使えない環境では素性確認を諦めて生存のみで判定する（fail-open）
is_watcher() {
    kill -0 "$1" 2>/dev/null || return 1
    CMD=$(ps -p "$1" -o command= 2>/dev/null || ps -p "$1" -o args= 2>/dev/null)
    [ -z "$CMD" ] && return 0
    case "$CMD" in *idle-checkpoint-watch*) return 0 ;; *) return 1 ;; esac
}

kill_watcher() {
    [ -f "$PID_FILE" ] || return 0
    OLD=$(cat "$PID_FILE" 2>/dev/null)
    case "$OLD" in
        ''|*[!0-9]*) ;;
        *) is_watcher "$OLD" && kill "$OLD" 2>/dev/null ;;
    esac
    rm -f "$PID_FILE"
}

# SessionEnd → ウォッチャー解除のみ。無効化フラグより先に処理する
# （BANTO_IDLE_CHECKPOINT=0 にした後でも、アーム済みの旧ウォッチャーを確実に解除するため）
if [ "$EVENT" = "SessionEnd" ]; then
    kill_watcher
    exit 0
fi

[ "${BANTO_IDLE_CHECKPOINT:-1}" = "0" ] && exit 0

# ---- Stop: アーム ----
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] || [ -z "$CWD" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0

CLAUDE_BIN=$(command -v claude 2>/dev/null)
[ -z "$CLAUDE_BIN" ] && exit 0

HOOKS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/hooks"}
[ -z "$HOOKS_DIR" ] && HOOKS_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
WATCH="$HOOKS_DIR/idle-checkpoint-watch.sh"
[ -f "$WATCH" ] || exit 0

# 生きている正規のウォッチャーが既にいれば何もしない（mtime 監視なので再アーム不要）
if [ -f "$PID_FILE" ]; then
    OLD=$(cat "$PID_FILE" 2>/dev/null)
    case "$OLD" in
        ''|*[!0-9]*) rm -f "$PID_FILE" ;;
        *) if is_watcher "$OLD"; then exit 0; else rm -f "$PID_FILE"; fi ;;
    esac
fi

LOG_DIR="$HOME/.cache/banto"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/idle-checkpoint-${SESSION_ID}.log"
# 古いログの掃除（セッション ID ごとに増えるため 7 日で回収）
find "$LOG_DIR" -name 'idle-checkpoint-*.log' -mtime +7 -delete 2>/dev/null

# hook プロセスの終了に巻き込まれないよう detach する。pid ファイルはウォッチャー
# 自身が起動時に書く（所有権トークン方式）。setsid コマンドは macOS に無いので
# perl POSIX::setsid → 無ければ nohup + サブシェル孤児化で代用。
if command -v perl >/dev/null 2>&1; then
    perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' -- \
        sh "$WATCH" "$SESSION_ID" "$TRANSCRIPT" "$CWD" "$CLAUDE_BIN" \
        </dev/null >>"$LOG" 2>&1 &
else
    ( nohup sh "$WATCH" "$SESSION_ID" "$TRANSCRIPT" "$CWD" "$CLAUDE_BIN" \
        </dev/null >>"$LOG" 2>&1 & )
fi

exit 0
