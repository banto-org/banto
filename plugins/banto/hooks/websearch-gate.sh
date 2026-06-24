#!/bin/sh
# websearch-gate.sh — PreToolUse(WebSearch): store-first を促すソフトな注意喚起（ブロックしない）
#
# 方針（evidence-first rule）: 情報を取りに行くとき、まずローカル store を `search` skill で
#   調べ、確信ヒットが無いときだけ web へエスカレーションする。この順序は散文（evidence-first.md）
#   と skill 配線で固定するが、人間/エージェントが直接 WebSearch を叩く経路は残るため、
#   その経路に**ソフトな**注意喚起を一段だけ足す。webfetch-deny.sh の deny とは異なり、
#   これは決してブロックしない（warn-only / 常に exit 0）。
#
# シグナル: 直近に `search` skill が起動された形跡（telemetry-log.sh が記録する skill イベント）が
#   あれば store-first 済みとみなして黙る。読めない / 形跡が無い → ソフトな tip を一度出す。
#   telemetry が読めない場合も fail-open でソフト tip のみ（順序を主張するだけで止めない）。
#
# 出力契約 (PreToolUse JSON): permissionDecision = "allow" + additionalContext + exit 0
#   （allow にしておくことで他フックの判断を上書きしてブロックすることはない）。
# 無効化したい場合: 環境変数 BANTO_ALLOW_WEBSEARCH=1 で透過（注意喚起を黙らせる）。

# サイレンサー: 明示的に許可されていれば何も言わずに素通し。
[ "${BANTO_ALLOW_WEBSEARCH:-0}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null)

# jq があれば tool_name を確認（matcher で既に絞られるが二重チェック）。無ければ素通しで tip。
if command -v jq >/dev/null 2>&1; then
    TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    [ -n "$TOOL" ] && [ "$TOOL" != "WebSearch" ] && exit 0
fi

# --- 直近の search-skill 起動を telemetry から確認（fail-open）---
# telemetry-log.sh と同じ base 解決を使い、当月の usage-*.jsonl に
# event:"skill" かつ name が "search" で終わるエントリがあれば store-first 済みとみなす。
RECENT_SEARCH=0
if command -v jq >/dev/null 2>&1; then
    CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
    [ -z "$CWD" ] && CWD="$PWD"
    PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
    PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
    if [ -f "$PATHS" ]; then
        BASE=$(sh "$PATHS" --resolve "$CWD" 2>/dev/null)
        if [ -n "$BASE" ]; then
            MONTH=$(date -u +"%Y-%m" 2>/dev/null || date +%Y-%m)
            LOG="$BASE/telemetry/usage-${MONTH}.jsonl"
            if [ -f "$LOG" ]; then
                # name が "search"（qualified 名 banto:search も含む）で終わる skill イベントの有無。
                if jq -e -s 'any(.[]; .event == "skill" and (.name | test("search$")))' "$LOG" >/dev/null 2>&1; then
                    RECENT_SEARCH=1
                fi
            fi
        fi
    fi
fi

# store-first 済みの形跡があれば黙って素通し。
[ "$RECENT_SEARCH" = "1" ] && exit 0

# 形跡が無い / 確認できない → ソフトな注意喚起を一度だけ添える（ブロックはしない）。
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Soft reminder (evidence-first rule): search the local store FIRST before going to the web. Run the `search` skill (/search <query>) — it expands the query into tiers and ranks {base}/decisions/ + {base}/docs/; escalate to WebSearch / the `research` skill only when search returns no confident hit. This is a reminder, not a block — WebSearch proceeds. Silence with BANTO_ALLOW_WEBSEARCH=1."}}
EOF
exit 0
