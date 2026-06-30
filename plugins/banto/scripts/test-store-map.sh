#!/bin/sh
# test-store-map.sh — tests for store-layout.json + store-map-lint.sh + store-map-gen.sh.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
MANIFEST="$PLUGIN_ROOT/templates/store-layout.json"
LINT="$SCRIPT_DIR/store-map-lint.sh"
GEN="$SCRIPT_DIR/store-map-gen.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 0; }
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT

# ---- manifest sanity ----
jq -e '.buckets | length >= 20' "$MANIFEST" >/dev/null 2>&1 && ok "manifest: valid JSON, >=20 buckets" || no "manifest invalid / too few buckets"
jq -e '[.buckets[].path] | length == (unique | length)' "$MANIFEST" >/dev/null 2>&1 && ok "manifest: bucket paths unique" || no "duplicate bucket paths"

# ---- build a CLEAN fixture base (all non-lazy dir buckets present + proper gitignore) ----
ROOT="$FIX/store"; BASE="$ROOT/proj"
mkdir -p "$ROOT"
cat > "$ROOT/.gitignore" <<'GI'
sessions/
sessions-cache/
tmp/
drafts/
*-combined.txt
DASHBOARD.md
WORKSPACE.md
GI
# create every non-lazy dir bucket from the manifest
jq -r '.buckets[] | select(.lazy==false and .kind=="dir") | .path' "$MANIFEST" | while IFS= read -r p; do mkdir -p "$BASE/$p"; done
# create every non-lazy file bucket
touch "$BASE/DASHBOARD.md"

# ---- lint on clean fixture ----
out=$(sh "$LINT" --base "$BASE" 2>&1); echo "$out" | grep -q "^store-map-lint: clean" && ok "lint: clean fixture -> clean" || no "clean fixture should be clean: $out"
sh "$LINT" --base "$BASE" --strict >/dev/null 2>&1 && ok "lint: clean fixture --strict -> exit 0" || no "clean fixture --strict should exit 0"

# ---- lint detects an orphan (real dir not in manifest) ----
mkdir -p "$BASE/bogus_orphan_dir"
sh "$LINT" --base "$BASE" --strict >/dev/null 2>&1 && no "orphan should make --strict exit nonzero" || ok "lint: orphan dir -> --strict exit nonzero"
sh "$LINT" --base "$BASE" 2>&1 | grep -q "bogus_orphan_dir" && ok "lint: orphan named in report" || no "orphan should be named"
rmdir "$BASE/bogus_orphan_dir"

# ---- lint detects gitignore drift (ephemeral bucket not ignored) ----
ROOT2="$FIX/store2"; BASE2="$ROOT2/proj"
mkdir -p "$BASE2/decisions" "$BASE2/docs/research" "$BASE2/docs/knowledges/drafts" "$BASE2/learnings" "$BASE2/sessions" "$BASE2/workspaces" "$BASE2/tasks" "$BASE2/meta"
touch "$BASE2/DASHBOARD.md"
: > "$ROOT2/.gitignore"   # empty gitignore — sessions-cache/tmp/sessions/drafts all uncovered
sh "$LINT" --base "$BASE2" 2>&1 | grep -q "\[B gitignore\]" && ok "lint: gitignore drift detected" || no "empty gitignore should flag ephemeral buckets"

# ---- gen produces a map with the orphan surfaced ----
mkdir -p "$BASE/surprise_dir"
sh "$GEN" --base "$BASE" >/dev/null 2>&1
MAP="$BASE/meta/store-map.md"
[ -f "$MAP" ] && ok "gen: writes meta/store-map.md" || no "gen should write the map"
grep -q "Store Map" "$MAP" 2>/dev/null && ok "gen: map has heading" || no "map missing heading"
grep -q "surprise_dir" "$MAP" 2>/dev/null && ok "gen: orphan surfaced in map" || no "orphan should be in the map's orphan section"
grep -q '`decisions`' "$MAP" 2>/dev/null && ok "gen: known bucket row present" || no "decisions row should be present"

# ---- gen is idempotent (no change -> same file) ----
rmdir "$BASE/surprise_dir" 2>/dev/null
sh "$GEN" --base "$BASE" >/dev/null 2>&1
cp "$MAP" "$FIX/map1"
sh "$GEN" --base "$BASE" >/dev/null 2>&1
cmp -s "$FIX/map1" "$MAP" && ok "gen: idempotent (stable output)" || no "gen output should be stable on re-run"

echo "store-map tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
