#!/bin/sh
# test-ontology.sh — tests for ontology-schema.json (TBox) + ontology-gen.sh + ontology-lint.sh.
# Dogfoods banto's own harness as the fixture (deterministic) and injects faults to prove the lint bites.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
TBOX="$PLUGIN_ROOT/templates/ontology-schema.json"
GEN="$SCRIPT_DIR/ontology-gen.sh"
LINT="$SCRIPT_DIR/ontology-lint.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 0; }
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT

# ---- TBox sanity ----
jq -e '.modules | has("core") and has("code-layer") and has("harness-layer")' "$TBOX" >/dev/null 2>&1 \
    && ok "TBox: 3 modules (core / code-layer / harness-layer)" || no "TBox: modules missing"
jq -e '[.modules["harness-layer"].entities[].type] | length == 16' "$TBOX" >/dev/null 2>&1 \
    && ok "TBox: 16 harness-layer entity types" || no "TBox: harness entity count != 16"
jq -e '.integrity_constraints | length == 5' "$TBOX" >/dev/null 2>&1 \
    && ok "TBox: 5 integrity constraints (IC1-5)" || no "TBox: IC count != 5"

# ---- gen: dogfood banto ----
BASE="$FIX/base"; mkdir -p "$BASE"
sh "$GEN" --base "$BASE"
J="$BASE/meta/ontology.json"
M="$BASE/meta/ontology.md"
jq empty "$J" >/dev/null 2>&1 && ok "gen: emits valid JSON ABox" || no "gen: invalid/absent ABox"
[ "$(jq '[.entities[]|select(.type=="skill")]|length' "$J" 2>/dev/null)" = "18" ] \
    && ok "gen: 18 skill entities" || no "gen: skill count != 18"
[ "$(jq '[.entities[]|select(.type=="agent")]|length' "$J" 2>/dev/null)" = "6" ] \
    && ok "gen: 6 agent entities" || no "gen: agent count != 6"
[ "$(jq '[.entities[]|select(.type=="rule")]|length' "$J" 2>/dev/null)" = "9" ] \
    && ok "gen: 9 rule entities" || no "gen: rule count != 9"
[ "$(jq '[.relations[]|select(.type=="gates")]|length' "$J" 2>/dev/null)" -gt 0 ] \
    && ok "gen: gates relations present (hook->event)" || no "gen: no gates relations"
grep -q '/Users/\|/home/' "$J" "$M" 2>/dev/null && no "gen: absolute path leaked" || ok "gen: no absolute paths (mask discipline)"
grep -q '## Example queries' "$M" 2>/dev/null && ok "gen: md is a query guide (schema + example jq)" || no "gen: md query-guide missing"

# ---- gen: idempotent ----
cp "$J" "$FIX/first.json"
sh "$GEN" --base "$BASE"
cmp -s "$J" "$FIX/first.json" && ok "gen: idempotent (unchanged on re-run)" || no "gen: rewrote unchanged content"

# ---- lint: clean dogfood ABox passes --strict ----
sh "$LINT" --base "$BASE" --strict >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "lint: clean dogfood ABox passes (--strict exit 0)" || no "lint: dogfood ABox not clean (rc=$rc)"

# ---- lint: catches an unknown entity type (L1) ----
B1="$FIX/bad1"; mkdir -p "$B1/meta"
jq '.entities += [{"id":"x:bogus","type":"NOT_A_REAL_TYPE"}]' "$J" > "$B1/meta/ontology.json"
sh "$LINT" --base "$B1" --strict >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "lint: catches unknown entity type (L1)" || no "lint: missed L1 bad type"

# ---- lint: catches a dangling relation endpoint (L2) ----
B2="$FIX/bad2"; mkdir -p "$B2/meta"
jq '.relations += [{"from":"skill:ghost","type":"invokes","to":"skill:phantom"}]' "$J" > "$B2/meta/ontology.json"
sh "$LINT" --base "$B2" --strict >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "lint: catches dangling endpoint (L2)" || no "lint: missed L2 dangling"

# ---- lint: fail-open without --strict (reports but exit 0) ----
sh "$LINT" --base "$B1" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "lint: fail-open without --strict (exit 0)" || no "lint: non-strict should exit 0"

# ---- core layer: dogfood emits repo + directories ----
[ "$(jq '[.entities[]|select(.type=="repo")]|length' "$J" 2>/dev/null)" -ge 1 ] \
    && ok "core: repo entity emitted" || no "core: no repo entity"
[ "$(jq '[.entities[]|select(.type=="directory")]|length' "$J" 2>/dev/null)" -ge 1 ] \
    && ok "core: directory entities emitted" || no "core: no directory entities"

# ---- portability: a non-banto repo (empty harness) still gets a non-empty core ABox ----
FR="$FIX/fakerepo"; mkdir -p "$FR/src"
printf '{"dependencies":{"lodash":"^4"}}' > "$FR/package.json"
EMPTY="$FIX/emptyplugin"; mkdir -p "$EMPTY/scripts"
cp "$SCRIPT_DIR/_ai-context-paths.sh" "$EMPTY/scripts/" 2>/dev/null || true
PB="$FIX/portbase"; mkdir -p "$PB"
BANTO_PLUGIN_ROOT="$EMPTY" sh "$GEN" --base "$PB" --repo "$FR" >/dev/null 2>&1
PJ="$PB/meta/ontology.json"
[ "$(jq '[.entities[]|select(.type=="repo")]|length' "$PJ" 2>/dev/null)" -ge 1 ] \
    && ok "portability: non-banto repo emits a core ABox" || no "portability: empty ABox for non-banto repo"
[ "$(jq '[.entities[]|select(.type=="external-dep" and .ecosystem=="npm")]|length' "$PJ" 2>/dev/null)" -ge 1 ] \
    && ok "portability: npm deps extracted (language-agnostic core)" || no "portability: no npm deps"

# ---- concept layer (--scope full): stub extractor -> cached prose relations ----
STUB="$FIX/stub.sh"
cat > "$STUB" <<'STUBEOF'
#!/bin/sh
[ -n "${SC:-}" ] && echo x >> "$SC"
printf '%s\n' '[{"type":"conforms-to","to":"rule:safety"}]'
STUBEOF
CB="$FIX/conceptbase"; mkdir -p "$CB"
CALLS="$FIX/calls"; : > "$CALLS"
SC="$CALLS" BANTO_ONTOLOGY_EXTRACT_CMD="sh $STUB" sh "$GEN" --base "$CB" --scope full >/dev/null 2>&1
CJ="$CB/meta/ontology.json"
[ "$(jq -r '.scope' "$CJ" 2>/dev/null)" = "full" ] && ok "concept: scope=full" || no "concept: scope not full"
[ "$(jq '[.relations[]|select(.type=="conforms-to")]|length' "$CJ" 2>/dev/null)" -ge 1 ] \
    && ok "concept: prose relations enriched (conforms-to)" || no "concept: no enriched relations"
[ -d "$CB/meta/ontology-cache" ] && ok "concept: content-hash cache created" || no "concept: no cache dir"
c1=$(grep -c x "$CALLS" 2>/dev/null); : > "$CALLS"
SC="$CALLS" BANTO_ONTOLOGY_EXTRACT_CMD="sh $STUB" sh "$GEN" --base "$CB" --scope full >/dev/null 2>&1
c2=$(grep -c x "$CALLS" 2>/dev/null)
{ [ "$c1" -gt 0 ] && [ "$c2" -eq 0 ]; } && ok "concept: cache hit on re-run (0 extractor calls)" || no "concept: cache ineffective (c1=$c1 c2=$c2)"
sh "$LINT" --base "$CB" --strict >/dev/null 2>&1 && ok "concept: enriched ABox stays lint-clean" || no "concept: enriched ABox fails lint"

# ---- --full: ontology-lint aggregates store-map-lint + plugin-audit-consistency ----
# assert both siblings were invoked (aggregation happened), robust to the fixture base's cleanliness.
fout=$(sh "$LINT" --base "$BASE" --full 2>&1)
{ printf '%s' "$fout" | grep -q 'store-map-lint' && printf '%s' "$fout" | grep -q 'plugin-audit-consistency'; } \
    && ok "lint --full: aggregates both sibling verifiers (single entry point)" || no "lint --full: did not aggregate siblings"

# ---- concept hardening: garbage relations from the extractor are dropped ----
STUBG="$FIX/stubgarbage.sh"
cat > "$STUBG" <<'STUBEOF'
#!/bin/sh
printf '%s\n' '[{"type":"BOGUS_TYPE","to":"rule:safety"},{"type":"conforms-to","to":"not-a-valid-ref"},{"type":"conforms-to","to":"rule:safety"}]'
STUBEOF
HB="$FIX/hardenbase"; mkdir -p "$HB"
BANTO_ONTOLOGY_EXTRACT_CMD="sh $STUBG" sh "$GEN" --base "$HB" --scope full >/dev/null 2>&1
HJ="$HB/meta/ontology.json"
[ "$(jq '[.relations[]|select(.type=="BOGUS_TYPE")]|length' "$HJ" 2>/dev/null)" = "0" ] \
    && ok "concept harden: unknown relation type dropped" || no "concept harden: bad type leaked"
[ "$(jq '[.relations[]|select(.to=="not-a-valid-ref")]|length' "$HJ" 2>/dev/null)" = "0" ] \
    && ok "concept harden: malformed 'to' dropped" || no "concept harden: bad 'to' leaked"
[ "$(jq '[.relations[]|select(.type=="conforms-to" and .to=="rule:safety")]|length' "$HJ" 2>/dev/null)" -ge 1 ] \
    && ok "concept harden: valid relation kept" || no "concept harden: valid relation lost"

# ---- doc-layer: store documents indexed as a navigation ledger ----
DB="$FIX/docbase"; mkdir -p "$DB/decisions" "$DB/docs/research"
printf -- '---\ntitle: Test decision\nauthor: x\nstatus: accepted\n---\n# Test decision\n' > "$DB/decisions/2026-01-01-000000_test_x.md"
printf -- '# Research note\n' > "$DB/docs/research/2026-01-01_note.md"
printf -- '# Guide body\n' > "$DB/docs/[Design] example.md"
sh "$GEN" --base "$DB" >/dev/null 2>&1
DJ="$DB/meta/ontology.json"
[ "$(jq '[.entities[]|select(.type=="document")]|length' "$DJ" 2>/dev/null)" -ge 3 ] \
    && ok "doc-layer: store documents indexed as a ledger" || no "doc-layer: documents not indexed"
[ "$(jq -r '[.entities[]|select(.doc_type=="decision")][0].status' "$DJ" 2>/dev/null)" = "accepted" ] \
    && ok "doc-layer: decision metadata (status/title) extracted" || no "doc-layer: decision metadata missing"
[ "$(jq -r '[.entities[]|select(.doc_type=="Design")]|length' "$DJ" 2>/dev/null)" -ge 1 ] \
    && ok "doc-layer: doc_type from [Type] prefix" || no "doc-layer: prefix doc_type missing"

echo ""
echo "test-ontology: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
