#!/bin/sh
# odd-parallel-track.sh — tracks the live parallel-subagent count and warns when it
# exceeds the active skill's odd.yaml metrics.parallel_agent_max.
#
# SubagentStart: counter +1. If it exceeds the active skill's parallel_agent_max
#                (smallest if several are active), warn on stderr + pending-channel fail.
#                Does NOT block (the agents are already running).
# SubagentStop:  counter -1 (floored at 0). On return to 0, clear the fail section (burst ended).
#
# fail-open: jq absent / session_id absent → silent exit 0.

set -u

command -v jq >/dev/null 2>&1 || exit 0
PAYLOAD=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(printf "%s" "$PAYLOAD" | jq -r '.session_id // empty')
[ -z "$SESSION_ID" ] && exit 0
EVENT=$(printf "%s" "$PAYLOAD" | jq -r '.hook_event_name // empty')
CWD=$(printf "%s" "$PAYLOAD" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="$PWD"

STATE_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
COUNTER="$STATE_DIR/agents-${SESSION_ID}"
ACTIVE="$STATE_DIR/active-${SESSION_ID}.json"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SKILLS_DIR="$PLUGIN_ROOT/skills"
PENDING="$PLUGIN_ROOT/hooks/pending-channel.sh"

cur=$(cat "$COUNTER" 2>/dev/null)
case "$cur" in ''|*[!0-9]*) cur=0 ;; esac

case "$EVENT" in
    SubagentStart)
        cur=$((cur + 1))
        printf '%s' "$cur" > "$COUNTER" 2>/dev/null
        # active skill の parallel_agent_max（複数 active なら最小値）
        MAX=""
        if [ -f "$ACTIVE" ]; then
            for name in $(jq -r '.active_skills[].name' "$ACTIVE" 2>/dev/null); do
                sk=${name##*:}
                odd="$SKILLS_DIR/$sk/odd.yaml"
                [ -f "$odd" ] || continue
                m=$(grep -E '^[[:space:]]*parallel_agent_max:' "$odd" 2>/dev/null | head -1 \
                    | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/')
                case "$m" in ''|*[!0-9]*) continue ;; esac
                if [ -z "$MAX" ] || [ "$m" -lt "$MAX" ]; then MAX="$m"; fi
            done
        fi
        if [ -n "$MAX" ] && [ "$cur" -gt "$MAX" ]; then
            printf "[ODD] Parallel subagent count %s exceeds parallel_agent_max=%s.\n" "$cur" "$MAX" >&2
            if [ -f "$PENDING" ]; then
                printf '## 🚦 Parallel limit exceeded (%s)\n- Currently %s parallel / limit %s (odd.yaml metrics of the active skill).\n- Not blocking since agents are already running, but watch cost/rate limits (narrow the fan-out next time if needed).\n' \
                    "$(date +%Y-%m-%d 2>/dev/null)" "$cur" "$MAX" \
                    | sh "$PENDING" fail "$CWD" 2>/dev/null
            fi
        fi
        ;;
    SubagentStop)
        cur=$((cur - 1))
        [ "$cur" -lt 0 ] && cur=0
        printf '%s' "$cur" > "$COUNTER" 2>/dev/null
        # burst 終了（全 agent 完了）→ fail section をクリア
        if [ "$cur" -eq 0 ] && [ -f "$PENDING" ]; then
            printf '' | sh "$PENDING" fail "$CWD" 2>/dev/null
        fi
        ;;
    *)
        exit 0
        ;;
esac

exit 0
