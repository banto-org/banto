#!/bin/sh
# telemetry-log.sh — skill 起動 / 成果物生成を機械可読ログ（JSONL）に記録する。
#
# 目的: harness-audit 軸2（呼出実態）と死蔵判定（dead-skill-report.sh）の入力。
#   反NG「死蔵は invocation + artifact で測り畳む」を実体化する計測層。
#   spec: docs/specs/2026-06-10_harness-next-level（P1）
#
# 2 mode（$1）:
#   skill    — PreToolUse(Skill): tool_input.skill（qualified 名）を 1 行記録
#   artifact — PostToolUse(Write|Edit): docs/decisions/specs 配下の生成を記録
#
# 記録先: <base>/telemetry/usage-YYYY-MM.jsonl（月次ローテ）
# 記録するのは skill名 / kind / prefix / basename / author / session_id / ts のみ。
#   **コマンド本文・ファイル内容・PII・絶対パスは記録しない**（safety.md / pii-protection.md）。
#
# fail-open: jq 不在 / payload 不正 / base 解決失敗 → silent exit 0（導入前を壊さない）。

set -u

command -v jq >/dev/null 2>&1 || exit 0

MODE="${1:-}"
[ -z "$MODE" ] && exit 0

PAYLOAD=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(printf "%s" "$PAYLOAD" | jq -r '.session_id // empty')
[ -z "$SESSION_ID" ] && exit 0
CWD=$(printf "%s" "$PAYLOAD" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="$PWD"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
[ -f "$PATHS" ] || exit 0

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)

# --- mode 別にイベント JSON を組み立てる（base 解決はイベント確定後に行う） ---
case "$MODE" in
    skill)
        TOOL=$(printf "%s" "$PAYLOAD" | jq -r '.tool_name // empty')
        [ "$TOOL" = "Skill" ] || exit 0
        SKILL=$(printf "%s" "$PAYLOAD" | jq -r '.tool_input.skill // .tool_input.name // empty')
        [ -z "$SKILL" ] && exit 0
        AUTHOR=$(sh "$PATHS" --author "$CWD" 2>/dev/null)
        EVENT_JSON=$(jq -c -n --arg ts "$TS" --arg sid "$SESSION_ID" \
            --arg name "$SKILL" --arg author "$AUTHOR" \
            '{ts:$ts, session_id:$sid, event:"skill", name:$name, author:$author}')
        ;;
    artifact)
        FILE=$(printf "%s" "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty')
        [ -z "$FILE" ] && exit 0
        # 安価な path フィルタ: ai-context 成果物のみ対象（base 解決の前に弾く）
        case "$FILE" in
            */decisions/*) KIND="decision" ;;
            */specs/*)     KIND="spec" ;;
            */docs/*)      KIND="doc" ;;
            *)             exit 0 ;;
        esac
        # base 配下のみ成果物として記録（plugin ソースツリー等の templates/specs/ 誤計上を防ぐ）。
        # base 不明時は記録しない（計測データの汚染より欠測を選ぶ）
        BASE=$(sh "$PATHS" --resolve "$CWD" 2>/dev/null)
        [ -z "$BASE" ] && exit 0
        case "$FILE" in
            "$BASE"/*) ;;
            *) exit 0 ;;
        esac
        BASENAME=$(basename "$FILE")
        # prefix は basename 先頭の [Xxx]（status / memo 等の成果物識別）
        PREFIX=$(printf "%s" "$BASENAME" | sed -n 's/^\(\[[^]]*\]\).*/\1/p')
        AUTHOR=$(sh "$PATHS" --author "$CWD" 2>/dev/null)
        # skill 帰属（2026-06-12 監査 M-3）: 書き込み時点の active skill を odd-active-tracker の
        # state から付与する。「invocation 0 かつ artifact 0」死蔵判定を prefix 近似でなく
        # skill 単位で評価可能にする。state 不在 / skill 非経由の書き込みは空文字（unattributed）。
        ACTIVE_SKILL=$(jq -r '.active_skills[-1].name // empty' \
            "${ODD_STATE_DIR:-$HOME/.cache/banto}/active-${SESSION_ID}.json" 2>/dev/null)
        EVENT_JSON=$(jq -c -n --arg ts "$TS" --arg sid "$SESSION_ID" \
            --arg kind "$KIND" --arg prefix "$PREFIX" --arg file "$BASENAME" --arg author "$AUTHOR" \
            --arg skill "$ACTIVE_SKILL" \
            '{ts:$ts, session_id:$sid, event:"artifact", kind:$kind, prefix:$prefix, file:$file, author:$author, skill:$skill}')
        ;;
    *)
        exit 0
        ;;
esac

[ -z "${EVENT_JSON:-}" ] && exit 0

BASE=$(sh "$PATHS" --resolve "$CWD" 2>/dev/null)
[ -z "$BASE" ] && exit 0
TEL_DIR="$BASE/telemetry"
mkdir -p "$TEL_DIR" 2>/dev/null || exit 0
MONTH=$(date -u +"%Y-%m" 2>/dev/null || date +%Y-%m)
printf '%s\n' "$EVENT_JSON" >> "$TEL_DIR/usage-${MONTH}.jsonl" 2>/dev/null

exit 0
