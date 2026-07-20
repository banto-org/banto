#!/bin/sh
# test-migration-status.sh — unit test for ai-context-migration-status.sh (doctor cross-project view).
# Hermetic: synthetic central + local mappings under a temp root. No network, no real store writes.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HELPER="$SCRIPT_DIR/ai-context-migration-status.sh"

fails=0
ok()  { echo "  ok   $1"; }
bad() { echo "  FAIL $1"; fails=$((fails+1)); }

command -v jq >/dev/null 2>&1 || { echo "test-migration-status: jq required — skip"; exit 0; }

TDIR=$(mktemp -d)
trap 'rm -rf "$TDIR"' EXIT
export AI_CONTEXT_STORE_ROOT="$TDIR/central"
export AI_CONTEXT_LOCAL_ROOT="$TDIR/local"
mkdir -p "$AI_CONTEXT_STORE_ROOT" "$AI_CONTEXT_LOCAL_ROOT"

# central has projA (already promoted). local has projA (dup) + projB (temp) + projC (pinned local:true).
cat > "$AI_CONTEXT_STORE_ROOT/.mapping.json" <<'JSON'
{ "store_root": "X", "projects": { "/repos/projA": { "project": "projA" } } }
JSON
cat > "$AI_CONTEXT_LOCAL_ROOT/.mapping.json" <<'JSON'
{ "version": 2, "store_root": "X", "projects": {
  "/repos/projA": { "project": "projA", "local": false },
  "/repos/projB": { "project": "projB", "local": false },
  "/repos/projC": { "project": "projC", "local": true } } }
JSON
mkdir -p "$AI_CONTEXT_LOCAL_ROOT/projB/decisions"
: > "$AI_CONTEXT_LOCAL_ROOT/projB/decisions/d1.md"

echo "== migration-status =="
OUT=$(sh "$HELPER" /tmp/some-unregistered-cwd 2>&1)

echo "$OUT" | grep -q "projB" && ok "promotable projB (local-only, not central) is listed" || bad "projB missing"
echo "$OUT" | grep -q "decisions:1" && ok "content count shown for projB" || bad "content count missing"
echo "$OUT" | grep -q "projA" && bad "projA (also in central) should be excluded" || ok "projA (already central) excluded"
echo "$OUT" | grep -q "projC" && ok "pinned projC (local:true) is listed" || bad "pinned projC missing"

# no local mapping → graceful "none" message
rm -f "$AI_CONTEXT_LOCAL_ROOT/.mapping.json"
OUT2=$(sh "$HELPER" /tmp/x 2>&1)
echo "$OUT2" | grep -q "ローカルプロジェクトなし" && ok "no local mapping → graceful message" || bad "no-local-mapping not graceful"

if [ "$fails" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "FAILED ($fails)"; exit 1; fi
