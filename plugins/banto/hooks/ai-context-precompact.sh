#!/bin/sh
# AI Context PreCompact Hook
# コンパクション前に設計判断とチェックポイントを注入
# 今日の決定=全文、古い決定=ファイル名のみ、チェックポイント=全文
# POSIX互換: macOS / Linux / WSL

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
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

DECISIONS="$AI_BASE/decisions"
SESSIONS="$AI_BASE/sessions"
TODAY=$(date +%Y-%m-%d)

echo "[AI Context - PreCompact: context injection before compaction]"
echo ""

# store 運用時はベースを明示注入（grandfather = repo 内 legacy base では出さない。
# subdir 起動の grandfather でも誤って central 文言を出さないよう base の形で判定する）
# i18n: consumed-by skills/ai-context/references/central-store-guide.md, skills/status/SKILL.md,
#       skills/ai-context/references/doctor.md, skills/ai-context/references/status.md
#       （「ai-context ベース:」marker をドキュメントが逐語参照。T2.4/T4 で同時変更すること）
case "$AI_BASE" in
    */.ai-context) ;;
    *)
        echo "[AI Context - 中央 store 運用] ai-context ベース: $AI_BASE（decisions/docs/tasks 等はここ配下を Read/Write）"
        echo ""
        ;;
esac

# --- チェックポイントがあれば全文注入 → 注入後に削除（再注入防止） ---
if [ -d "$SESSIONS" ]; then
    CHECKPOINT_FILES=$(ls -t "$SESSIONS"/checkpoint-*.md 2>/dev/null)
    if [ -n "$CHECKPOINT_FILES" ]; then
        echo "=== Checkpoint (user-confirmed) ==="
        # 行単位で読む + 消費後は consumed/ へ退避（session-start と同修正・14 日保持）
        CONSUMED="$SESSIONS/consumed"
        mkdir -p "$CONSUMED" 2>/dev/null
        printf '%s\n' "$CHECKPOINT_FILES" | while IFS= read -r f; do
            [ -f "$f" ] || continue
            cat "$f"
            echo ""
            mv -f "$f" "$CONSUMED/" 2>/dev/null || rm -f "$f"
        done
        echo "[Note: checkpoints were moved to sessions/consumed/ after injection (kept for 14 days)]"
        echo ""
        find "$CONSUMED" -name 'checkpoint-*.md' -mtime +14 -delete 2>/dev/null
    fi
fi

# --- 今日の設計判断: 全文注入（合計 20KB 上限。session-start と同修正） ---
if [ -d "$DECISIONS" ]; then
    TODAY_FILES=$(ls "$DECISIONS"/${TODAY}*.md 2>/dev/null)
    if [ -n "$TODAY_FILES" ]; then
        echo "=== Today's design decisions (full text, 20KB total cap) ==="
        _dec_budget=20000
        _dec_used=0
        while IFS= read -r f; do
            [ -f "$f" ] || continue
            _sz=$(wc -c < "$f" | tr -d ' ')
            if [ $((_dec_used + _sz)) -le "$_dec_budget" ]; then
                echo "--- $(basename "$f") ---"
                cat "$f"
                echo ""
                _dec_used=$((_dec_used + _sz))
            else
                echo "--- $(basename "$f") (over injection cap — Read for full text) ---"
            fi
        done <<TODAY_DECISIONS_EOF
$TODAY_FILES
TODAY_DECISIONS_EOF
    fi

    # --- 古い設計判断: ファイル名のみ ---
    OLD_FILES=$(ls -t "$DECISIONS"/*.md 2>/dev/null | grep -v "/${TODAY}")
    if [ -n "$OLD_FILES" ]; then
        echo "=== Past design decisions (filenames only — Read them if needed) ==="
        for f in $OLD_FILES; do
            echo "  - $(basename "$f")"
        done
        echo ""
    fi
fi

# --- ワークスペース情報を注入（compact 後も WS を保持するため SessionStart と同等の注入を行う） ---
# 実効ポインタ: git-dir（per-checkout・並走独立）優先 → store の WORKSPACE.md フォールバック
WS_FILE="$AI_BASE/WORKSPACE.md"
command -v _ai_context_ws_pointer >/dev/null 2>&1 && WS_FILE=$(_ai_context_ws_pointer "$AI_BASE" "$CWD")
WS_RULE="$CWD/.claude/rules/workspace.md"
if [ -f "$WS_FILE" ]; then
    echo "=== Current workspace (always consult it; update it when needed) ==="
    cat "$WS_FILE"
    echo ""
    # 新 layout ならポインタの実体（workspace.md）も注入
    if command -v _ai_context_ws_dir >/dev/null 2>&1; then
        _WSD=$(_ai_context_ws_dir "$AI_BASE" "$CWD") || _WSD=""
        if [ -n "$_WSD" ] && [ -f "$_WSD/workspace.md" ]; then
            echo "--- workspace entity (${_WSD#$AI_BASE/}/workspace.md) ---"
            cat "$_WSD/workspace.md"
            echo ""
        fi
    fi
    echo "[Workspace rules]"
    echo "  1. If subsequent user messages fall outside the scope of the workspace above, suggest /ws switch or /ws new"
    echo "  2. When you create a new file under decisions/ or docs/, add it to the 「## 関連ドキュメント」 (related documents) section of WORKSPACE.md"  # i18n: consumed-by hooks/ai-context-auto.sh awk, skills/ws/SKILL.md (WORKSPACE.md format)
    echo "  3. Consult related files of other workspaces listed as dependencies when needed"
    echo ""
    # 利用可能なWS一覧（新 layout: workspaces/<author>/<topic>/ 優先、legacy: workspaces/*.md）
    WS_DIR="$AI_BASE/workspaces"
    _AUTHOR=""
    command -v _ai_context_author >/dev/null 2>&1 && _AUTHOR=$(_ai_context_author "$CWD")
    if [ -n "$_AUTHOR" ] && [ -d "$WS_DIR/$_AUTHOR" ]; then
        echo "=== Other workspaces (switch via /ws switch) ==="
        for d in "$WS_DIR/$_AUTHOR"/*/; do
            [ -d "$d" ] || continue
            WSNAME=$(basename "$d")
            [ "$WSNAME" = "old" ] && continue
            echo "  - $WSNAME"
        done
        echo ""
    elif [ -d "$WS_DIR" ] && [ -n "$(ls "$WS_DIR"/*.md 2>/dev/null)" ]; then
        echo "=== Other workspaces (switch via /ws switch) ==="
        for f in "$WS_DIR"/*.md; do
            WSNAME=$(basename "$f" .md)
            echo "  - $WSNAME"
        done
        echo ""
    fi
elif [ -d "$AI_BASE" ]; then
    # WORKSPACE.md は無いが .ai-context/ はある → 未設定の検知メッセージのみ
    MISSING=""
    [ ! -f "$WS_FILE" ] && MISSING="${MISSING} WORKSPACE.md"
    [ ! -f "$WS_RULE" ] && MISSING="${MISSING} .claude/rules/workspace.md"
    if [ -n "$MISSING" ]; then
        cat << WS_MISSING_MSG
[Workspace] No workspace is set up for this project.
  Missing:${MISSING}
  To carry context into the next session, create a workspace with /ws new before running clear/compact.
WS_MISSING_MSG
    fi
fi

echo "[When a new design decision is made during the conversation, save it to $AI_BASE/decisions/ immediately]"
exit 0
