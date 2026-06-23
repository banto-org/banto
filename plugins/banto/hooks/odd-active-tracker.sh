#!/bin/sh
# odd-active-tracker.sh — tracks which skill is currently active
#
# Called from two hook events:
#   - UserPromptExpansion: user typed /skill-name directly → identified from command_name
#   - PreToolUse(matcher: "Skill"): Claude auto-invoked the Skill tool → identified from tool_input.skill
#
# Output: $ODD_STATE_DIR (default: ~/.cache/banto) / active-<session_id>.json
# Consumed by odd-parallel-track.sh (to read the active skill's parallel_agent_max).
# Cleaned up by odd-state-cleanup.sh at SessionEnd.
#
# jq required; absent → silent exit 0 (fail-open).

set -u

command -v jq >/dev/null 2>&1 || exit 0

PAYLOAD=$(cat 2>/dev/null || echo '{}')

# 必須フィールド抽出（無ければ exit）
SESSION_ID=$(printf "%s" "$PAYLOAD" | jq -r '.session_id // empty')
EVENT=$(printf "%s" "$PAYLOAD" | jq -r '.hook_event_name // empty')
[ -z "$SESSION_ID" ] || [ -z "$EVENT" ] && exit 0

# skill 名抽出（event ごとに異なる経路）
SKILL=""
SOURCE=""
case "$EVENT" in
    UserPromptExpansion)
        SKILL=$(printf "%s" "$PAYLOAD" | jq -r '.command_name // empty')
        SOURCE="user_prompt"
        ;;
    PreToolUse)
        TOOL=$(printf "%s" "$PAYLOAD" | jq -r '.tool_name // empty')
        [ "$TOOL" != "Skill" ] && exit 0
        # `.tool_input.skill` holds the qualified name (`plugin:skill`)
        SKILL=$(printf "%s" "$PAYLOAD" | jq -r '.tool_input.skill // empty')
        SOURCE="skill_tool"
        ;;
    *)
        exit 0
        ;;
esac

[ -z "$SKILL" ] && exit 0

STATE_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"
mkdir -p "$STATE_DIR" 2>/dev/null
STATE_FILE="$STATE_DIR/active-${SESSION_ID}.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)

# state file が無ければ初期化
if [ ! -f "$STATE_FILE" ]; then
    printf '{"session_id":"%s","active_skills":[],"last_updated":""}\n' "$SESSION_ID" > "$STATE_FILE"
fi

# active_skills に append（同名は dedup、last_updated を更新）
TMP_FILE="$STATE_FILE.tmp.$$"
jq --arg skill "$SKILL" --arg ts "$TIMESTAMP" --arg src "$SOURCE" '
    .active_skills |= (
        map(select(.name != $skill))
        + [{name: $skill, activated_at: $ts, via: $src}]
    )
    | .last_updated = $ts
' "$STATE_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$STATE_FILE"

exit 0
