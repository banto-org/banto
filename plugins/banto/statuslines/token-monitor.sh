#!/bin/sh
# Token Monitor Statusline
# stdin から context_window.used_percentage を読み取って tmp file に書き出す。
# checkpoint-recommend.sh が UserPromptSubmit でこの tmp file を読み、しきい値を判定する。
# 通常の statusline 表示も継続（コンテキスト % をシンプルに 1 行表示）。
# POSIX互換: macOS / Linux / WSL

INPUT=$(cat)

# jq が無ければサイレント終了（statusline は空文字を返しても良い）
command -v jq >/dev/null 2>&1 || { echo ""; exit 0; }

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
WORKSPACE=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // empty' 2>/dev/null)

# tmp file に % を書き出し（hook が後で読む）
if [ -n "$SESSION_ID" ] && [ -n "$PCT" ]; then
    TOKEN_FILE="${TMPDIR:-/tmp}/banto-token-pct-${SESSION_ID}"
    echo "$PCT" > "$TOKEN_FILE" 2>/dev/null
fi

# 表示: model | dir basename | context %
PCT_DISPLAY=""
if [ -n "$PCT" ]; then
    PCT_INT=$(printf '%.0f' "$PCT" 2>/dev/null || echo "$PCT" | cut -d. -f1)
    if [ -n "$PCT_INT" ]; then
        if [ "$PCT_INT" -ge 80 ] 2>/dev/null; then
            PCT_DISPLAY=" | 🔴 ${PCT_INT}%"
        elif [ "$PCT_INT" -ge 60 ] 2>/dev/null; then
            PCT_DISPLAY=" | 🟠 ${PCT_INT}%"
        elif [ "$PCT_INT" -ge 40 ] 2>/dev/null; then
            PCT_DISPLAY=" | 🟡 ${PCT_INT}%"
        else
            PCT_DISPLAY=" | ${PCT_INT}%"
        fi
    fi
fi

DIR_DISPLAY=""
[ -n "$WORKSPACE" ] && DIR_DISPLAY=" | $(basename "$WORKSPACE")"

MODEL_DISPLAY=""
[ -n "$MODEL" ] && MODEL_DISPLAY="$MODEL"

# 📋 未完了タスク数（- [ ] 未着手 ＋ - [~] 進行中 をカウント、- [x] 完了は除外＝完了を隠す）。
# banto の永続タスク（per-workspace tasks.md、legacy は tasks/active.md）を単一ソースとして読む。
# store base は cwd の git root basename から高速解決（重い base 解決スクリプトは hot path で使わない）。
TASK_DISPLAY=""
LOCAL_DISPLAY=""
if [ -n "$WORKSPACE" ]; then
    TOP=$(cd "$WORKSPACE" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$WORKSPACE")
    PROJ=$(basename "$TOP")
    STORE_BASE="$HOME/ai-context-store/$PROJ"
    TASKS_FILE=$(ls -t "$STORE_BASE"/workspaces/*/*/tasks.md 2>/dev/null | head -1)
    [ -f "$TASKS_FILE" ] || TASKS_FILE="$STORE_BASE/tasks/active.md"
    if [ -f "$TASKS_FILE" ]; then
        OPEN_TASKS=$(grep -cE '^- \[[ ~]\]' "$TASKS_FILE" 2>/dev/null)
        if [ -n "$OPEN_TASKS" ] && [ "$OPEN_TASKS" -gt 0 ] 2>/dev/null; then
            TASK_DISPLAY=" | 📋 ${OPEN_TASKS}"
        fi
    fi
    # 📍local: cwd の repo が local mapping に在り central mapping に無ければ「中央 store 未昇格（GitHub 未連携）」を常時表示。
    # 未登録 repo は一時ローカル store（~/ai-context-local）へ自動作成されるため、1 回きり通知を見逃しても気づけるようにする。
    LMAP="${AI_CONTEXT_LOCAL_ROOT:-$HOME/ai-context-local}/.mapping.json"
    CMAP="${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}/.mapping.json"
    if [ -f "$LMAP" ] && jq -e --arg k "$TOP" '.projects[$k]' "$LMAP" >/dev/null 2>&1 \
       && ! { [ -f "$CMAP" ] && jq -e --arg k "$TOP" '.projects[$k]' "$CMAP" >/dev/null 2>&1; }; then
        LOCAL_DISPLAY=" | 📍local"
    fi
fi

# 💾 チェックポイント保存済み表示。checkpoint-autofire.sh が保存成功時に
# ${TMPDIR}/banto-checkpoint-saved-${SESSION_ID} へ HH:MM を書き、ここで読む
# （token % と同じ tmp file 連携の逆向き）。セッション単位なので他セッションと混ざらない。
CKPT_DISPLAY=""
if [ -n "$SESSION_ID" ]; then
    CKPT_FILE="${TMPDIR:-/tmp}/banto-checkpoint-saved-${SESSION_ID}"
    if [ -f "$CKPT_FILE" ]; then
        CKPT_AT=$(head -c 16 "$CKPT_FILE" 2>/dev/null | tr -cd '0-9:')
        [ -n "$CKPT_AT" ] && CKPT_DISPLAY=" | 💾 ${CKPT_AT}"
    fi
fi

printf "%s%s%s%s%s%s\n" "$MODEL_DISPLAY" "$DIR_DISPLAY" "$TASK_DISPLAY" "$LOCAL_DISPLAY" "$CKPT_DISPLAY" "$PCT_DISPLAY"
