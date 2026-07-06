#!/bin/sh
# AI Context Stop Hook — Self-Improvement Detector
# セッション内で「ルール化すべき指示」を検出し、`.ai-context/learnings/` にドラフト保存する。
# Layer 3 (Harness Engineering) の Stop hook 自己改善ループ。Windsurf Memories 相当。
# exit 0 で常に終了（ブロックしない）。次セッションの SessionStart で通知される。

INPUT=$(cat)

# banto 起動のヘッドレス fork（idle-checkpoint 等）では learnings ドラフトを作らない
[ "${BANTO_HEADLESS:-0}" = "1" ] && exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

[ -z "$CWD" ] || [ -z "$TRANSCRIPT" ] && exit 0

# ai-context ベースdir を解決（central/legacy 透過・既定 legacy で挙動不変）
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi
[ ! -d "$AI_BASE" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# セッション単位の発火抑制（1 セッションにつき最大 1 ドラフト）
if command -v md5sum >/dev/null 2>&1; then
    HASH=$(echo -n "$TRANSCRIPT" | md5sum | cut -d' ' -f1)
elif command -v md5 >/dev/null 2>&1; then
    HASH=$(echo -n "$TRANSCRIPT" | md5 | cut -d' ' -f1)
else
    HASH=$(echo -n "$TRANSCRIPT" | cksum | cut -d' ' -f1)
fi
LOCK_FILE="${TMPDIR:-/tmp}/ai-context-self-improve-${HASH}.fired"
[ -f "$LOCK_FILE" ] && exit 0

# 直近のユーザーメッセージのみ抽出（最新 20 件まで）
USER_TEXT=$(tail -3000 "$TRANSCRIPT" 2>/dev/null | jq -r '
    select(.type == "user" and .message.role == "user") |
    .message.content |
    if type == "string" then .
    elif type == "array" then map(select(.type == "text") | .text) | join(" ")
    else empty end
' 2>/dev/null | tail -20)

[ -z "$USER_TEXT" ] && exit 0

# ルール化候補キーワード（行動・指示の永続化を示す表現）
# decisions/ の対象（採用・確定）とは区別: こちらは「行動原則」レベル
LEARN_KEYWORDS='(次から|今後は|今後常に|毎回|常に|いつも|やってはいけない|してはいけない|やらないで|しないで|禁止して|ルール化|ルールにして|rule にして|決まりとして|決まりに|覚えておいて|memorize|remember this|don.t do|never do|always do|from now on|going forward|going-forward|going-forward,)'

MATCHED=$(echo "$USER_TEXT" | grep -iE "$LEARN_KEYWORDS" | head -5)
[ -z "$MATCHED" ] && exit 0

# ドラフト保存先（learnings/<author>/ — 個人状態を scope 化して複数人で衝突回避）
# author 不明時は unknown にフォールバック。書込みは新 per-user パスのみ。
if command -v _ai_context_author >/dev/null 2>&1; then
    AUTHOR=$(_ai_context_author "$CWD" 2>/dev/null)
elif [ -n "${AI_PATHS:-}" ]; then
    AUTHOR=$(sh "$AI_PATHS" --author "$CWD" 2>/dev/null)
fi
[ -z "${AUTHOR:-}" ] && AUTHOR="unknown"
LEARNINGS_DIR="$AI_BASE/learnings/${AUTHOR}"
mkdir -p "$LEARNINGS_DIR" 2>/dev/null

TODAY=$(date +%Y-%m-%d)
TIME=$(date +%H%M%S)
DRAFT="$LEARNINGS_DIR/${TODAY}_${TIME}_draft.md"

# 既存の同日ドラフトを上書きしない（タイムスタンプで一意化済み）
cat > "$DRAFT" <<EOF
# Learning Draft — ${TODAY} ${TIME}

**status**: DRAFT (unreviewed)
**source**: auto-detected by the Stop-hook self-improvement loop

## Detected pattern

Detected keywords in this session that look like an instruction that should become a rule.

## Detected statements (excerpt)

\`\`\`
$(echo "$MATCHED" | head -5)
\`\`\`

## Next steps

Review this draft and decide whether to persist it:

1. **Add to rules/** → integrate into CLAUDE.md / rules/ as a behavioral principle
2. **Promote to decisions/** → save under decisions/ if it is a design decision
3. **Turn into a skill** → add to skills/ as a procedure
4. **Reject** → it was a one-off instruction / already covered by existing rules → delete this file

After deciding, delete this file or rewrite it to \`status: ACCEPTED / REJECTED\`.
EOF

touch "$LOCK_FILE"
exit 0
