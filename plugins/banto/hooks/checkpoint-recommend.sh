#!/bin/sh
# Checkpoint Recommend Hook (UserPromptSubmit)
# token-monitor.sh statusline が書き出した tmp file から context % を読み、
# 70%/80%/90% のしきい値で /save-checkpoint 推奨メッセージを stdout に注入する。
# 同セッション内で同じしきい値の再通知を防ぐため、last-warned-pct も別ファイルに記録。
# POSIX互換: macOS / Linux / WSL

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0

TOKEN_FILE="${TMPDIR:-/tmp}/banto-token-pct-${SESSION_ID}"
WARNED_FILE="${TMPDIR:-/tmp}/banto-token-warned-${SESSION_ID}"

[ ! -f "$TOKEN_FILE" ] && exit 0

PCT=$(cat "$TOKEN_FILE" 2>/dev/null)
[ -z "$PCT" ] && exit 0

PCT_INT=$(printf '%.0f' "$PCT" 2>/dev/null || echo "$PCT" | cut -d. -f1)
[ -z "$PCT_INT" ] && exit 0
case "$PCT_INT" in *[!0-9]*) exit 0 ;; esac

# しきい値判定: 90 > 80 > 70 の順で最高ティアを返す
TIER=0
if [ "$PCT_INT" -ge 90 ]; then
    TIER=90
elif [ "$PCT_INT" -ge 80 ]; then
    TIER=80
elif [ "$PCT_INT" -ge 70 ]; then
    TIER=70
fi

[ "$TIER" = "0" ] && exit 0

# 直近の警告済みティアを確認（同ティアは再通知しない、ただし上位ティアには昇格通知）
LAST_TIER=0
[ -f "$WARNED_FILE" ] && LAST_TIER=$(cat "$WARNED_FILE" 2>/dev/null || echo 0)
case "$LAST_TIER" in *[!0-9]*) LAST_TIER=0 ;; esac

if [ "$TIER" -le "$LAST_TIER" ]; then
    exit 0
fi

# 警告済みティアを更新
echo "$TIER" > "$WARNED_FILE" 2>/dev/null

# しきい値別メッセージ
case "$TIER" in
    70)
        cat <<'CHECKPOINT_70'
[Checkpoint suggested — context 70%] Consider saving the current state with /save-checkpoint soon; it makes compact / clear safe even in long sessions (optional).
CHECKPOINT_70
        ;;
    80)
        cat <<'CHECKPOINT_80'
[Checkpoint strongly recommended — context 80%] Save the current work state with /save-checkpoint (stored under the ai-context base sessions/). Taking it right before compact loses detail to compression, so taking it now is strongly recommended.
After saving, a diagnosis will indicate whether clear or compact is safer.
CHECKPOINT_80
        ;;
    90)
        cat <<'CHECKPOINT_90'
[Checkpoint URGENT — context 90%] auto-compact is about to fire. **Run /save-checkpoint right now**. After compact, the checkpoint is re-injected by the SessionStart hook, so you can continue without losing context.
CHECKPOINT_90
        ;;
esac

exit 0
