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
# exit 3 (unregistered) is the signal the scaffold relies on for A1: no resolver hit →
# do NOT auto-create, emit the bootstrap prompt instead. Keep this contract stable.
sh "$RESOLVER" /work/unknown >/dev/null 2>&1; check_rc "unregistered cwd → exit 3 (A1 bootstrap signal)" 3 "$?"

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
# in-repo .ai-context is ABOLISHED (2026-07-08 abolish-in-repo-ai-context): it no longer wins over
# derive. An in-repo .ai-context is never a resolution target — the scaffold auto-migrates it into
# the store, and the resolver falls through to the central derive.
LEG="$TMP/leg-proj"
mkdir -p "$LEG/.ai-context"
m3=$( . "$PATHS"; _ai_context_mode "$LEG" )
check "in-repo .ai-context → central (grandfather abolished)" "central" "$m3"
b3=$( . "$PATHS"; _ai_context_base_dir "$LEG" )
case "$b3" in */.ai-context) b3got=inrepo ;; *) b3got=store ;; esac
check "in-repo .ai-context ignored → resolves to store, not the in-repo path" "store" "$b3got"

echo "== ai-context-local (non-blocking local store, spec 2026-06-24) =="
# A repo registered ONLY in the local store mapping resolves into ~/ai-context-local/<project>,
# NOT the central derive. Keyed by git toplevel; here we use a non-git dir so the key is the cwd.
LROOT="$TMP/local"
LMAP="$LROOT/.mapping.json"
mkdir -p "$LROOT"
LP="$TMP/localproj"                 # non-git: base_dir keys on the cwd path
mkdir -p "$LP"
cat > "$LMAP" <<JSON
{
  "version": 2,
  "store_root": "$LROOT",
  "projects": {
    "$LP":        { "project": "localproj", "local": false },
    "$TMP/pinned": { "project": "pinned",   "local": true  }
  }
}
JSON
export AI_CONTEXT_LOCAL_ROOT="$LROOT" AI_CONTEXT_LOCAL_MAPPING="$LMAP"

bl=$( . "$PATHS"; _ai_context_base_dir "$LP" )
check "local-registered → local store dir" "$LROOT/localproj" "$bl"
( . "$PATHS"; _ai_context_is_local "$LP" ); check_rc "is_local true for local-registered repo" 0 "$?"
# central registration still wins over the local store (resolution order: central first)
bc=$( . "$PATHS"; _ai_context_base_dir /work/customer-A )
check "central registration wins over local store" "$TMP/store/customer-A" "$bc"
( . "$PATHS"; _ai_context_is_local /work/customer-A ); check_rc "is_local false for central repo" 1 "$?"
# unregistered (neither central nor local) → central derive (store-first default), not local
bu=$( . "$PATHS"; _ai_context_base_dir /work/unregistered-x )
check "unregistered → central derive (not local)" "$TMP/store/unregistered-x" "$bu"

echo "== local:true pin (mapping marker) =="
( . "$PATHS"; _ai_context_is_local_pinned "$TMP/pinned" );   check_rc "pinned repo (local:true) → pinned" 0 "$?"
( . "$PATHS"; _ai_context_is_local_pinned "$LP" );           check_rc "local:false repo → not pinned" 1 "$?"
( . "$PATHS"; _ai_context_is_local_pinned "/work/proj-b" );  check_rc "central repo → not pinned" 1 "$?"

echo "== grants (_ai_context_grant, time-boxed object form) =="
GTMP="$TMP/grants"
mkdir -p "$GTMP/store/grantrepo/meta"
GMAP="$GTMP/.mapping.json"
cat > "$GMAP" <<JSON
{"version":2,"store_root":"$GTMP/store","projects":{"$GTMP/repo":{"project":"grantrepo"}}}
JSON
GFILE="$GTMP/store/grantrepo/meta/grants.json"
TODAY=$(date +%Y-%m-%d)
FUTURE=$(date -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d)
PAST=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "-7 days" +%Y-%m-%d)

# subshell (not `sh -c`) so $0 stays the test script's own path — same trick the mapping-hit
# tests above rely on for resolve-store-path.sh to be found relative to $0's dirname.
_grant_with() {  # $1=grants.json content $2=key
    printf '%s' "$1" > "$GFILE"
    ( AI_CONTEXT_MAPPING="$GMAP"; export AI_CONTEXT_MAPPING; . "$PATHS"; _ai_context_grant "$2" "$GTMP/repo" )
}

g=$(_grant_with "{\"grants\":{\"prod_ops\":{\"value\":\"allow\",\"until\":\"$FUTURE\"}}}" prod_ops)
check "future until → allow still in effect" "allow" "$g"

g=$(_grant_with "{\"grants\":{\"prod_ops\":{\"value\":\"allow\",\"until\":\"$PAST\"}}}" prod_ops)
check "past until → decays to confirm" "confirm" "$g"

g=$(_grant_with '{"grants":{"prod_ops":{"value":"allow","until":"not-a-date"}}}' prod_ops)
check "malformed until → fail-open to confirm" "confirm" "$g"

if [ "$fail" = "0" ]; then echo "ALL GREEN"; exit 0; else echo "FAILED"; exit 1; fi
