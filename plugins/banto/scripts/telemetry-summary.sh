#!/bin/sh
# telemetry-summary.sh — aggregates telemetry JSONL and shows per-skill usage.
#
# Input: <base>/telemetry/usage-*.jsonl (appended by telemetry-log.sh)
# Output: skill → {invocations, artifacts, last_used} table + dormancy candidates (0 invocations in the window)
#   Consumed by harness-audit axis 2 / dead-skill-report.sh (P2).
#   spec: docs/specs/2026-06-10_harness-next-level (P1)
#
# Usage:
#   telemetry-summary.sh [--days N] [--json] [cwd]
#     --days N : aggregation window (default 30)
#     --json   : machine-readable JSON output (used by dead-skill-report)
#
# fail-open: jq missing / telemetry missing → empty summary (exit 0).

set -u

command -v jq >/dev/null 2>&1 || { echo "(telemetry-summary: skipped, jq not found)"; exit 0; }

DAYS=30
AS_JSON=0
CWD=""
while [ $# -gt 0 ]; do
    case "$1" in
        --days) DAYS="$2"; shift 2 ;;
        --json) AS_JSON=1; shift ;;
        *) CWD="$1"; shift ;;
    esac
done
[ -z "$CWD" ] && CWD="$PWD"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
SKILLS_DIR="$PLUGIN_ROOT/skills"
[ -f "$PATHS" ] || exit 0

BASE=$(sh "$PATHS" --resolve "$CWD" 2>/dev/null)
[ -z "$BASE" ] && exit 0
TEL_DIR="$BASE/telemetry"

# Lower-bound ts of the aggregation window (ISO8601; string comparison suffices)
CUTOFF=$(date -u -v-"${DAYS}"d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -d "${DAYS} days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || echo "0000")

# Full skill list (taken from the dir so never-invoked skills absent from telemetry are listed too)
ALL_SKILLS=""
if [ -d "$SKILLS_DIR" ]; then
    ALL_SKILLS=$(for d in "$SKILLS_DIR"/*/; do [ -d "$d" ] && basename "$d"; done | sort)
fi

# Telemetry aggregation (skill names normalized to the suffix of "plugin:skill")
# Output: {skills: {name: {invocations, artifacts, last_used}}}
TEL_JSON='{}'
if [ -d "$TEL_DIR" ] && ls "$TEL_DIR"/usage-*.jsonl >/dev/null 2>&1; then
    TEL_JSON=$(cat "$TEL_DIR"/usage-*.jsonl 2>/dev/null | jq -s --arg cutoff "$CUTOFF" '
        . as $all
        | ($all | map(.ts) | min // null) as $earliest
        | ($all | map(select(.ts >= $cutoff))) as $win
        | ($win | map(select(.event=="skill")) | group_by(.name | split(":") | last)
            | map({key: (.[0].name | split(":") | last),
                   value: {invocations: length, last_used: (map(.ts) | max)}})
            | from_entries) as $inv
        | ($win | map(select(.event=="artifact")) | [.[].file] | unique | length) as $artifact_total
        | {invocations: $inv, artifact_total: $artifact_total,
           artifacts_by_prefix: ($win | map(select(.event=="artifact")) | group_by(.prefix)
             | map({key: (if (.[0].prefix // "") == "" then "(none)" else .[0].prefix end), value: length}) | from_entries),
           artifacts_by_skill: ($win | map(select(.event=="artifact")) | group_by(.skill // "")
             | map({key: (if (.[0].skill // "") == "" then "(unattributed)" else (.[0].skill | split(":") | last) end), value: length}) | from_entries),
           total_skill_events: ($win | map(select(.event=="skill")) | length),
           earliest_ts: $earliest}
    ' 2>/dev/null || echo '{}')
fi

# Observation guard (2026-06-12 audit M-4): a 30-day window verdict over 2 days of telemetry is
# structurally biased. Defer dormancy verdicts until the window is covered by the observation
# period (earliest event <= cutoff) or enough volume exists (>=10 skill invocations in window).
TOTAL_SKILL_EVENTS=$(printf "%s" "$TEL_JSON" | jq -r '.total_skill_events // 0')
EARLIEST_TS=$(printf "%s" "$TEL_JSON" | jq -r '.earliest_ts // empty')
INSUFFICIENT=1
if [ -n "$EARLIEST_TS" ]; then
    if [ "$EARLIEST_TS" \< "$CUTOFF" ] || [ "$EARLIEST_TS" = "$CUTOFF" ] || [ "$TOTAL_SKILL_EVENTS" -ge 10 ]; then
        INSUFFICIENT=0
    fi
fi

if [ "$AS_JSON" = "1" ]; then
    # Machine-readable output joining invocations + attributed artifacts onto all skills.
    # dead candidate = invocations 0 AND attributed artifacts 0 (only when data is sufficient).
    printf '%s\n' "$ALL_SKILLS" | jq -R -s --argjson tel "$TEL_JSON" --arg days "$DAYS" \
        --argjson insufficient "$INSUFFICIENT" '
        (split("\n") | map(select(length>0))) as $skills
        | {window_days: ($days|tonumber),
           insufficient_data: ($insufficient == 1),
           observed_from: ($tel.earliest_ts // null),
           skills: ($skills | map({name: .,
                invocations: ($tel.invocations[.].invocations // 0),
                artifacts: ($tel.artifacts_by_skill[.] // 0),
                last_used: ($tel.invocations[.].last_used // null)})),
           dead_candidates: (if $insufficient == 1 then []
             else ($skills | map(select((($tel.invocations[.].invocations // 0) == 0)
                                    and (($tel.artifacts_by_skill[.] // 0) == 0)))) end),
           dead_verdict_note: (if $insufficient == 1
             then "deferred: window not covered by observation period and fewer than 10 skill events"
             else null end),
           artifacts_by_prefix: ($tel.artifacts_by_prefix // {}),
           artifacts_by_skill: ($tel.artifacts_by_skill // {})}'
    exit 0
fi

# Human-readable table
echo "=== telemetry summary (last ${DAYS} days / base: ${BASE}) ==="
if [ -z "$ALL_SKILLS" ]; then
    echo "(skills dir missing)"
    exit 0
fi
printf "%-22s %12s   %s\n" "skill" "invocations" "last_used"
echo "$ALL_SKILLS" | while IFS= read -r s; do
    [ -z "$s" ] && continue
    inv=$(printf "%s" "$TEL_JSON" | jq -r --arg s "$s" '.invocations[$s].invocations // 0')
    last=$(printf "%s" "$TEL_JSON" | jq -r --arg s "$s" '.invocations[$s].last_used // "-"')
    printf "%-22s %12s   %s\n" "$s" "$inv" "$last"
done

echo
echo "--- 🪦 dormancy candidates (0 invocations AND 0 attributed artifacts in ${DAYS} days) ---"
if [ "$INSUFFICIENT" = "1" ]; then
    echo "  (verdict deferred: observation period does not cover the ${DAYS}-day window and skill events < 10 — observed_from: ${EARLIEST_TS:-none})"
else
    DEAD=$(echo "$ALL_SKILLS" | while IFS= read -r s; do
        [ -z "$s" ] && continue
        inv=$(printf "%s" "$TEL_JSON" | jq -r --arg s "$s" '.invocations[$s].invocations // 0')
        art=$(printf "%s" "$TEL_JSON" | jq -r --arg s "$s" '.artifacts_by_skill[$s] // 0')
        [ "$inv" = "0" ] && [ "$art" = "0" ] && echo "  - $s"
    done)
    [ -n "$DEAD" ] && echo "$DEAD" || echo "  (none)"
fi

echo
echo "--- artifact by prefix ---"
printf "%s" "$TEL_JSON" | jq -r '.artifacts_by_prefix // {} | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null
[ "$(printf "%s" "$TEL_JSON" | jq -r '.artifact_total // 0')" = "0" ] && echo "  (no artifacts)"

exit 0
