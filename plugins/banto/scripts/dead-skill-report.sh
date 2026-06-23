#!/bin/sh
# dead-skill-report.sh — extracts dormancy candidates (0 invocations in the window) from telemetry.
#
# Consumes telemetry-summary.sh --json. Anti-NG principle: "measure dormancy by invocation + artifact, then fold".
#   spec: docs/specs/2026-06-10_harness-next-level (P2)
#
# Output (stdout): markdown when dormancy candidates exist, nothing otherwise. Picked up by pending-channel.sh dead.
# Insufficient-data guard: while telemetry is shallow (few total invocations), do not declare dormancy
#   (avoids falsely flagging every skill as dormant right after installation).
# Usage: dead-skill-report.sh [cwd]
# fail-open: jq missing / telemetry missing → no output, exit 0.

set -u

command -v jq >/dev/null 2>&1 || exit 0
CWD="${1:-$PWD}"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SUMMARY="$PLUGIN_ROOT/scripts/telemetry-summary.sh"
[ -f "$SUMMARY" ] || exit 0

JSON=$(sh "$SUMMARY" --json --days 30 "$CWD" 2>/dev/null)
[ -z "$JSON" ] && exit 0

# Total invocations (proxy for accumulation depth). Below the threshold = "insufficient data", no dormancy verdict.
TOTAL=$(printf "%s" "$JSON" | jq '[.skills[].invocations] | add // 0' 2>/dev/null)
[ -z "$TOTAL" ] && exit 0
# Rule of thumb: fewer than 10 invocations of activity in the window is not enough evidence
[ "$TOTAL" -lt 10 ] && exit 0

DEAD=$(printf "%s" "$JSON" | jq -r '.dead_candidates[]?' 2>/dev/null)
[ -z "$DEAD" ] && exit 0

TODAY=$(date +%Y-%m-%d 2>/dev/null || echo "")
echo "## 🪦 Dormancy candidates (0 invocations in 30 days / ${TODAY})"
echo "$DEAD" | while IFS= read -r s; do
    [ -z "$s" ] && continue
    echo "- ${s}"
done
echo "- Judgment: check whether artifacts are also 0 → fold if there is no insurance value (insurance-value rule from harness-audit / decision 001). total invocations=${TOTAL}."
exit 0
