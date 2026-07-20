#!/bin/sh
# AI Context Auto Hook (UserPromptSubmit)
# 設計判断の自動検出 + .ai-context/ 初回自動作成 + チェックポイント推奨
# POSIX互換: macOS / Linux / WSL

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

command -v jq >/dev/null 2>&1 || exit 0
[ -z "$CWD" ] && exit 0

# ai-context ベースdir を解決（central/legacy 透過・既定 legacy で挙動不変）
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi

# scaffold 関数を source（CLAUDE_PLUGIN_ROOT 優先、フォールバックで $0 から導出）
SCRIPT_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/hooks"}
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
if [ -f "$SCRIPT_DIR/_ai-context-scaffold.sh" ]; then
    . "$SCRIPT_DIR/_ai-context-scaffold.sh"
    # denylist マッチなら hook 全体をサイレントスキップ
    if _ai_context_should_skip "$CWD"; then
        exit 0
    fi
    # store-first: base 未作成なら scaffold（冪等・store 側のみ書く。hot path なので
    # base が既にある通常ケースでは呼ばない。初回登録で解決先が flip するため再解決）
    if [ ! -d "$AI_BASE" ]; then
        _ai_context_scaffold "$CWD"
        command -v _ai_context_base_dir >/dev/null 2>&1 && AI_BASE=$(_ai_context_base_dir "$CWD")
    fi
fi

AI_CTX="$AI_BASE"
[ ! -d "$AI_CTX" ] && exit 0

# --- 現在のワークスペースを1行注入（軽量リマインダー） ---
# 実効ポインタ: git-dir（per-checkout・並走独立）優先 → store の WORKSPACE.md フォールバック
WS_FILE="$AI_CTX/WORKSPACE.md"
command -v _ai_context_ws_pointer >/dev/null 2>&1 && WS_FILE=$(_ai_context_ws_pointer "$AI_CTX" "$CWD")
if [ -f "$WS_FILE" ]; then
    # 1行目の "# Workspace: [scope] topic" から WS 名を抽出
    WS_HEADER=$(grep -m1 '^# Workspace:' "$WS_FILE" 2>/dev/null | sed 's/^# Workspace:[[:space:]]*//')
    # 関連ドキュメント件数。新 layout ではポインタでなく実体（workspace.md）から数える
    _WS_BODY="$WS_FILE"
    if command -v _ai_context_ws_dir >/dev/null 2>&1; then
        _WSD=$(_ai_context_ws_dir "$AI_CTX" "$CWD") || _WSD=""
        [ -n "$_WSD" ] && [ -f "$_WSD/workspace.md" ] && _WS_BODY="$_WSD/workspace.md"
    fi
    WS_DOCS_COUNT=$(awk '/^## 関連ドキュメント/{flag=1;next} /^## /{flag=0} flag && /^- /' "$_WS_BODY" 2>/dev/null | wc -l | tr -d ' ')  # i18n: consumed-by WORKSPACE.md format (skills/ws/SKILL.md, .claude/rules/workspace.md)
    if [ -n "$WS_HEADER" ]; then
        echo "[Workspace] current: ${WS_HEADER} (${WS_DOCS_COUNT} related docs) — suggest /ws switch when the topic drifts; update the 「## 関連ドキュメント」 (related documents) section when creating new files under decisions/docs"
    fi
fi

# --- tasks の全タスク完了を検知したら退避を推奨（新 layout → legacy フォールバック） ---
ACTIVE_TASKS="$AI_CTX/tasks/active.md"
command -v _ai_context_active_tasks >/dev/null 2>&1 && ACTIVE_TASKS=$(_ai_context_active_tasks "$AI_CTX" "$CWD")
if [ -f "$ACTIVE_TASKS" ]; then
    # 注意: grep -c は 0 件でも "0" を出力して exit 1 するため `|| echo 0` を付けると
    # "0\n0" になり比較が壊れる（このバグで全完了検知が一度も発火していなかった）
    UNCHECKED=$(grep -c "^- \[ \]" "$ACTIVE_TASKS" 2>/dev/null)
    UNCHECKED=${UNCHECKED:-0}
    CHECKED=$(grep -c "^- \[x\]" "$ACTIVE_TASKS" 2>/dev/null)
    CHECKED=${CHECKED:-0}
    # [~] = 進行中。done でも open でもないため、残っている間は「全完了」と誤判定しないよう open 扱いにする
    INPROGRESS=$(grep -c "^- \[~\]" "$ACTIVE_TASKS" 2>/dev/null)
    INPROGRESS=${INPROGRESS:-0}
    if [ "$UNCHECKED" = "0" ] && [ "$INPROGRESS" = "0" ] && [ "$CHECKED" -gt 0 ]; then
        PHASE_NAME=$(grep -m1 -E "^#{1,2}\s*Phase" "$ACTIVE_TASKS" 2>/dev/null | sed -E 's/^#+[[:space:]]*Phase[：: ]*//' | sed -E 's/[（(].*//' | tr -s ' ' '-' | sed 's/[^[:alnum:]一-龥ぁ-んァ-ヶー-]//g' | cut -c1-40)
        [ -z "$PHASE_NAME" ] && PHASE_NAME="phase"
        # 退避先: 新 layout は同 WS の tasks-old/、legacy は tasks/old/
        if [ "$ACTIVE_TASKS" = "$AI_CTX/tasks/active.md" ]; then
            ARCHIVE_DIR="$AI_CTX/tasks/old"
        else
            ARCHIVE_DIR="$(dirname "$ACTIVE_TASKS")/tasks-old"
        fi
        cat << TASK_ARCHIVE_MSG
[AI Context - Task Archive] All tasks in the tasks file are done (${CHECKED} done / 0 open).
Archive it with the following steps:
1. Destination: ${ARCHIVE_DIR}/$(date +%Y-%m-%d)_${PHASE_NAME}.md
2. git mv ${ACTIVE_TASKS} to the path above (or Write + rm)
3. Create a new tasks file, or replace it with a template for the next phase
4. Report completion to the user + confirm the next work item
TASK_ARCHIVE_MSG
    fi
fi

# --- タスクファイル位置の情報提示（セッション初回1回のみ） ---
# 警告ではなく情報提示。既存ファイルを優先利用するのが原則。
# AIはこの情報を読んだ上で、必要ならユーザーに「移動するか」確認する。
TASK_CHECK_HASH=$(echo -n "$CWD" | (md5sum 2>/dev/null || md5 2>/dev/null || cksum) | cut -d' ' -f1)
TASK_CHECK_FILE="${TMPDIR:-/tmp}/ai-context-task-check-${TASK_CHECK_HASH}"
if [ ! -f "$TASK_CHECK_FILE" ]; then
    touch "$TASK_CHECK_FILE"
    STANDARD_TASKS="$ACTIVE_TASKS"
    FOUND_TASKS=$(find "$CWD" -maxdepth 3 -type f \
        \( -iname "tasks.md" -o -iname "todo.md" -o -iname "roadmap.md" \) \
        ! -path "*/.ai-context/*" \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        ! -path "*/dist/*" \
        ! -path "*/build/*" 2>/dev/null)

    HAS_STANDARD="false"
    [ -f "$STANDARD_TASKS" ] && HAS_STANDARD="true"

    if [ -n "$FOUND_TASKS" ] || [ "$HAS_STANDARD" = "true" ]; then
        echo "[AI Context - Task File Info] Task files available in this project:"
        if [ "$HAS_STANDARD" = "true" ]; then
            echo "  ✓ ${STANDARD_TASKS#$AI_CTX/} (standard location)"
        fi
        if [ -n "$FOUND_TASKS" ]; then
            echo "$FOUND_TASKS" | sed 's|^|  ✓ |' | sed "s|$CWD/||"
        fi
        echo ""
        if [ -n "$FOUND_TASKS" ] && [ "$HAS_STANDARD" != "true" ]; then
            echo "  Prefer the project's existing task files."
            echo "  Move them only if the user explicitly asks to move them into ${AI_CTX}/tasks/."
        elif [ -n "$FOUND_TASKS" ] && [ "$HAS_STANDARD" = "true" ]; then
            echo "  ⚠ Task files exist in multiple locations. Ask the user which one to use."
        fi
    fi
fi

# --- メッセージカウンター（チェックポイント閾値検知） ---
CHECKPOINT_THRESHOLD=40
CHECKPOINT_REMINDER_INTERVAL=10
# session_id が空の場合、CWD のハッシュをフォールバックに使う
# （$$ だと呼び出しごとに異なるためカウンターが累積しない）
if [ -z "$SESSION_ID" ]; then
    if command -v md5sum >/dev/null 2>&1; then
        SESSION_ID=$(echo -n "$CWD" | md5sum | cut -d' ' -f1)
    elif command -v md5 >/dev/null 2>&1; then
        SESSION_ID=$(echo -n "$CWD" | md5 | cut -d' ' -f1)
    else
        SESSION_ID=$(echo -n "$CWD" | cksum | cut -d' ' -f1)
    fi
fi
COUNTER_FILE="${TMPDIR:-/tmp}/ai-context-counter-${SESSION_ID}"

if [ -f "$COUNTER_FILE" ]; then
    COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
    COUNT=$((COUNT + 1))
else
    COUNT=1
fi
echo "$COUNT" > "$COUNTER_FILE"

CHECKPOINT_DONE_FILE="${TMPDIR:-/tmp}/ai-context-checkpoint-done-${SESSION_ID}"

# チェックポイントファイルが存在すれば「作成済み」フラグを立てる
if ls "$AI_CTX/sessions"/checkpoint-*.md >/dev/null 2>&1; then
    touch "$CHECKPOINT_DONE_FILE"
fi

# --- 常時リマインド（毎回軽く注入） ---
TODAY=$(date +%Y-%m-%d)
DECISIONS_DIR="$AI_CTX/decisions"
if [ -d "$DECISIONS_DIR" ]; then
    TODAY_COUNT=$(find "$DECISIONS_DIR" -name "${TODAY}*.md" 2>/dev/null | wc -l | tr -d ' ')
else
    TODAY_COUNT=0
fi

cat << EOF
[AI Context] Save design decisions and important findings to ${AI_CTX}/decisions/. Saved today: ${TODAY_COUNT}.
EOF

# --- チェックポイント推奨 + 診断情報の自動計算 ---
if [ "$COUNT" -ge "$CHECKPOINT_THRESHOLD" ]; then
    if [ ! -f "$CHECKPOINT_DONE_FILE" ]; then
        DECISIONS_TOTAL=$(find "$AI_CTX/decisions" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        TODAY_DEC=$(find "$AI_CTX/decisions" -name "${TODAY}*.md" 2>/dev/null | wc -l | tr -d ' ')
        SESSION_HAS=$(find "$AI_CTX/sessions" -name "checkpoint-*.md" 2>/dev/null | wc -l | tr -d ' ')
        RESEARCH_TOTAL=$(find "$AI_CTX/docs/research" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

        REQ_EXISTS="✗"; DESIGN_EXISTS="✗"; TASKS_EXISTS="✗"
        [ -f "$CWD/docs/requirements.md" ] && REQ_EXISTS="✓ docs/requirements.md"
        [ -f "$CWD/requirements.md" ] && REQ_EXISTS="✓ requirements.md"
        [ -f "$CWD/docs/design.md" ] && DESIGN_EXISTS="✓ docs/design.md"
        [ -f "$CWD/design.md" ] && DESIGN_EXISTS="✓ design.md"
        [ -f "$CWD/docs/tasks.md" ] && TASKS_EXISTS="✓ docs/tasks.md"
        [ -f "$CWD/tasks.md" ] && TASKS_EXISTS="✓ tasks.md"
        [ -f "$ACTIVE_TASKS" ] && TASKS_EXISTS="✓ ${ACTIVE_TASKS#$AI_CTX/}"

        RECOMMEND="compact"
        if [ "$DECISIONS_TOTAL" -gt 0 ] && [ "$TODAY_DEC" -gt 0 ]; then
            RECOMMEND="clear"
        fi

        cat << CHECKPOINT_MSG
[AI Context - Checkpoint Required] Approaching the context limit (message ${COUNT}).
Create a checkpoint now.

## Auto-diagnosis (facts)
- Decision logs: ${DECISIONS_TOTAL} total (${TODAY_DEC} today)
- Existing checkpoints: ${SESSION_HAS}
- Research docs: ${RESEARCH_TOTAL}
- Specs:
  - requirements: ${REQ_EXISTS}
  - design: ${DESIGN_EXISTS}
  - tasks: ${TASKS_EXISTS}

## Auto-recommendation: ${RECOMMEND}
(derived from ${DECISIONS_TOTAL} decision logs / ${TODAY_DEC} today)

## Instructions for the AI
1. Invoke the ai-context skill
2. Save the diagnosis above in narrative form to ${AI_CTX}/sessions/checkpoint-${TODAY}-{HHMM}.md ({HHMM} is the current 4-digit time)
3. Ask the user: "Does this match your understanding? Tell me if anything is off"
4. Present the recommendation (${RECOMMEND}). Run compact/clear after the user decides

CHECKPOINT_MSG
    elif [ $((COUNT % CHECKPOINT_REMINDER_INTERVAL)) -eq 0 ]; then
        cat << 'REMINDER_MSG'
[AI Context - Checkpoint Reminder] No checkpoint has been created yet. Create one soon.
REMINDER_MSG
    fi
fi

# --- ユーザー入力にキーワードがある場合は強調 ---
DECISION_KEYWORDS='(にしよう|に決定|を採用|ではなく|にする$|方針|トレードオフ|アーキテクチャ|選択肢|決め手|理由は|代わりに|比較|検討|判断|設計|選定|変更|切り替え|やめ|ピボット|instead of|decided|trade-?off|architecture|chose|approach|let.s go with|we.ll use|compare|evaluate|pivot|switch to|drop|replace)'
MEMORY_KEYWORDS='(覚えて|remember|メモして|注意点|ハマった|原因は|解決した|パターン|規約|convention|分かった|判明|important|発見した|気づ|learn|realize|discover|notice|gotcha|workaround)'

if echo "$PROMPT" | grep -qiE "$DECISION_KEYWORDS"; then
    # author 導出は _ai-context-paths.sh の _ai_context_author に集約（gh→git→$USER）。
    # paths.sh 不在の degrade 時のみ $USER に落とす。
    GITHUB_USER=$(_ai_context_author "$CWD" 2>/dev/null)
    [ -z "$GITHUB_USER" ] && GITHUB_USER="${USER:-unknown}"
    cat << EOF
[AI Context Auto-Save] Design decision detected. You must save it:
  Destination: ${AI_CTX}/decisions/$(date +%Y-%m-%d-%H%M%S)_{topic-slug}_${GITHUB_USER}.md
  Replace secrets (sk-*, ghp_*, Bearer *) with [MASKED]
  会話の逐語引用を書かない: 発言は要旨へ丸める（例: owner 指示（要旨）: X を実装する）。口語のまま残さない
EOF
fi

# --- ハマりポイント → ナレッジドラフト自動保存を促す ---
if echo "$PROMPT" | grep -qiE "$MEMORY_KEYWORDS"; then
    mkdir -p "$AI_CTX/docs/knowledges/drafts" 2>/dev/null
    cat << KNOWLEDGE_MSG
[AI Context - Knowledge Draft] Detected a gotcha or an important finding.
Once the problem is solved, save a knowledge draft to:
  Destination: ${AI_CTX}/docs/knowledges/drafts/{topic-slug}.md
  Format:
    # {problem title}
    ## Problem
    {what happened}
    ## Cause
    {why it happened}
    ## Solution
    {how it was solved}
    ## Lesson
    {how to prevent the same problem}
  The user can review drafts via /knowledge and promote them to official knowledge.
KNOWLEDGE_MSG
fi

exit 0
