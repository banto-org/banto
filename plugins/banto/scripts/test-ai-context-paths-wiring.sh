#!/bin/sh
# test-ai-context-paths-wiring.sh — regression test for wiring hooks through _ai-context-paths.sh.
#
# Invariants verified (store-first resolution order, spec 2026-06-11_store-first-architecture):
#   1. grandfather (existing in-repo .ai-context) → DEC_DIR stays <cwd>/.ai-context/decisions
#   2. central (mapping registered)               → DEC_DIR redirects to <store>/<project>/decisions
#   3. unregistered + no legacy + empty store     → derive target has no decisions (negative control)
#   4. unregistered + no legacy + store has <dirname>/decisions → derive resolves into the store
#
# keystone = ai-context-decisions-numbering.sh. Since v5.21.4 the hook emits a timestamp-based
# "[Decisions Naming]" recommendation iff the resolved <base>/decisions exists, so wiring is
# observable as output presence: the central/derive cwd has NO local .ai-context, hence any
# output there proves the store redirect resolved (and case 3 proves the converse).
# Depends on jq. exit 0 when green.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$DIR/../hooks/ai-context-decisions-numbering.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: hook missing ($HOOK)"; exit 1; }

# Unset CLAUDE_PLUGIN_ROOT if set externally, since it would block the fallback path (test determinism).
unset CLAUDE_PLUGIN_ROOT

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- grandfather cwd: local .ai-context/decisions exists ---
LEG="$TMP/legacy-proj"
mkdir -p "$LEG/.ai-context/decisions"

# --- central store: <store>/projX/decisions exists; cwd has NO local .ai-context ---
STORE="$TMP/store"
mkdir -p "$STORE/projX/decisions"
CEN="$TMP/central-proj"
mkdir -p "$CEN"
cat > "$TMP/.mapping.json" <<JSON
{ "version": 2, "store_root": "$STORE", "projects": { "$CEN": { "project": "projX" } } }
JSON

# --- derive: second store root; <store2>/derive-proj/decisions exists only for case 4 ---
STORE2="$TMP/store2"
mkdir -p "$STORE2"
DRV="$TMP/derive-proj"
mkdir -p "$DRV"

# Helper: invoke the hook once and report whether the naming recommendation was injected
naming_emitted() { # cwd mappingfile storeroot
    OUT=$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"file_path":"%s/decisions/new.md"}}' "$1" "$1" \
        | AI_CONTEXT_MAPPING="$2" AI_CONTEXT_STORE_ROOT="$3" sh "$HOOK")
    case "$OUT" in
        *"[Decisions Naming]"*) echo "yes" ;;
        *) echo "no" ;;
    esac
}

fail=0
check() { if [ "$2" = "$3" ]; then printf '  ok  %s\n' "$1"; else printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fail=1; fi; }

echo "== hook wiring regression test (store-first) =="
# grandfather: nonexistent mapping + empty store → in-repo .ai-context wins over derive
check "grandfather: resolves local .ai-context (kept working)" "yes" "$(naming_emitted "$LEG" "$TMP/none.json" "$STORE2")"
# central: mapping registered → resolves store/projX/decisions despite no local .ai-context
check "central: redirects to store/projX (mapping honored)" "yes" "$(naming_emitted "$CEN" "$TMP/.mapping.json" "$STORE")"
# negative control: unregistered + no legacy + derive target lacks decisions/ → silent
check "derive miss: no decisions in store (negative control)" "no" "$(naming_emitted "$DRV" "$TMP/none.json" "$STORE2")"
# derive: unregistered + no legacy + store has <dirname>/decisions → store-first resolution proven
mkdir -p "$STORE2/derive-proj/decisions"
check "derive: unregistered repo resolves into the store" "yes" "$(naming_emitted "$DRV" "$TMP/none.json" "$STORE2")"

if [ "$fail" = "0" ]; then echo "ALL GREEN"; exit 0; else echo "FAILED"; exit 1; fi
