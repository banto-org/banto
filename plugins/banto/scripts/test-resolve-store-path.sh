#!/bin/sh
# test-resolve-store-path.sh — self-test for the resolver (single-store version) + path helper.
# Depends on jq. exit 0 when green, exit 1 on any failure.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
RESOLVER="$DIR/resolve-store-path.sh"
PATHS="$DIR/_ai-context-paths.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MAP="$TMP/.mapping.json"
cat > "$MAP" <<JSON
{
  "version": 2,
  "store_root": "$TMP/store",
  "projects": {
    "/work/customer-A": { "project": "customer-A", "worktree_siblings": ["/work/customer-A-wt1"] },
    "/work/proj-b":      { "project": "proj-b" }
  }
}
JSON
export AI_CONTEXT_MAPPING="$MAP"

fail=0
check() { # desc expected actual
    if [ "$2" = "$3" ]; then printf '  ok  %s\n' "$1"; else printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fail=1; fi
}
check_rc() { # desc expected_rc actual_rc
    if [ "$2" = "$3" ]; then printf '  ok  %s (rc=%s)\n' "$1" "$3"; else printf '  FAIL %s (rc expected %s, got %s)\n' "$1" "$2" "$3"; fail=1; fi
}

echo "== resolver =="
check "exact match → store/project" "$TMP/store/customer-A" "$(sh "$RESOLVER" /work/customer-A)"
check "subdir(prefix) → store/project" "$TMP/store/customer-A" "$(sh "$RESOLVER" /work/customer-A/src/x)"
check "worktree sibling → same project" "$TMP/store/customer-A" "$(sh "$RESOLVER" /work/customer-A-wt1)"
check "relative path appended" "$TMP/store/customer-A/decisions/x.md" "$(sh "$RESOLVER" /work/customer-A decisions/x.md)"
check "different project" "$TMP/store/proj-b" "$(sh "$RESOLVER" --store-dir /work/proj-b)"
sh "$RESOLVER" /work/unknown >/dev/null 2>&1; check_rc "unregistered cwd → exit 3" 3 "$?"

echo "== path-helper (store-first resolution) =="
# central (registered)
m=$( . "$PATHS"; _ai_context_mode /work/customer-A )
check "registered → central" "central" "$m"
b=$( . "$PATHS"; _ai_context_base_dir /work/customer-A )
check "central base = store/project" "$TMP/store/customer-A" "$b"
# derive (unregistered + no in-repo .ai-context → store-first default, spec 2026-06-11)
m2=$( . "$PATHS"; _ai_context_mode /work/unknown )
check "unregistered → central (derive)" "central" "$m2"
b2=$( . "$PATHS"; _ai_context_base_dir /work/unknown )
check "derive base = store/<dirname>" "$TMP/store/unknown" "$b2"
# grandfather (existing in-repo .ai-context wins over derive)
LEG="$TMP/leg-proj"
mkdir -p "$LEG/.ai-context"
m3=$( . "$PATHS"; _ai_context_mode "$LEG" )
check "grandfather → legacy" "legacy" "$m3"
b3=$( . "$PATHS"; _ai_context_base_dir "$LEG" )
check "grandfather base = cwd/.ai-context" "$LEG/.ai-context" "$b3"

if [ "$fail" = "0" ]; then echo "ALL GREEN"; exit 0; else echo "FAILED"; exit 1; fi
