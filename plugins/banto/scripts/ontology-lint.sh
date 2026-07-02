#!/bin/sh
# ontology-lint.sh — verify the ontology ABox ({base}/meta/ontology.json) against the TBox and reality.
#
# The single verifier the plan converges on (store-map-lint + plugin-audit-consistency generalize into
# this). v1 deterministic checks:
#   L1  TBox conformance   — every entity.type / relation.type used in the ABox exists in the TBox
#                            vocabulary (templates/ontology-schema.json). Catches typos / unknown kinds.
#   L2  endpoint resolution — every relation.from / relation.to resolves to a real entity id (dangling
#                            detection; the generalization of plugin-audit Axis 15). Synthetic `event:`
#                            targets of `gates` are exempt.
#   L4  hook wiring         — every command registered in hooks/hooks.json points to an existing file.
#
# Fail-open: jq absent / base unresolved / ABox absent → exit 0 (nothing to check; run ontology-gen
# first). `--strict` exits 1 on any FAIL. Deferred to the concept layer: IC1 (rule enforcement
# coverage) and IC3 (SKILL<->odd agreement) — they need the prose-derived `enforces` relations.
set -u

command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}
TBOX="$PLUGIN_ROOT/templates/ontology-schema.json"
HOOKS="$PLUGIN_ROOT/hooks/hooks.json"

BASE=""
STRICT=0
FULL=0
while [ $# -gt 0 ]; do
    case "$1" in
        --base)   BASE="${2:-}"; shift 2 ;;
        --strict) STRICT=1; shift ;;
        --full)   FULL=1; shift ;;
        *) shift ;;
    esac
done
[ -n "$BASE" ] || BASE=$(sh "$PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD" 2>/dev/null)
[ -n "$BASE" ] && [ -d "$BASE" ] || exit 0

ABOX="$BASE/meta/ontology.json"
[ -f "$TBOX" ] || exit 0
if [ ! -f "$ABOX" ]; then
    echo "ontology-lint: no ABox at $ABOX — run ontology-gen.sh first (skip)"
    exit 0
fi

fails=0
warns=0

# --- L1: TBox conformance --------------------------------------------------
VALID_ENT=$(jq -r '[.modules[].entities[]?.type]|unique[]' "$TBOX")
VALID_REL=$(jq -r '([.modules[].relations[]?.type]+[.modules[].relation_categories[]?[]?.type])|unique[]' "$TBOX")

for t in $(jq -r '[.entities[].type]|unique[]' "$ABOX"); do
    printf '%s\n' "$VALID_ENT" | grep -qxF "$t" || { printf 'FAIL L1: entity type not in TBox: %s\n' "$t"; fails=$((fails+1)); }
done
for t in $(jq -r '[.relations[].type]|unique[]' "$ABOX"); do
    printf '%s\n' "$VALID_REL" | grep -qxF "$t" || { printf 'FAIL L1: relation type not in TBox: %s\n' "$t"; fails=$((fails+1)); }
done

# --- L2: endpoint resolution (dangling detection) --------------------------
IDS=$(jq -r '.entities[].id' "$ABOX" | sort -u)
# endpoints that must resolve: everything except synthetic event: targets
DANGLING=$(jq -r '.relations[] | .from, .to' "$ABOX" \
    | grep -vE '^event:' | sort -u \
    | while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        printf '%s\n' "$IDS" | grep -qxF "$ref" || printf '%s\n' "$ref"
      done)
if [ -n "$DANGLING" ]; then
    printf '%s\n' "$DANGLING" | while IFS= read -r d; do
        [ -n "$d" ] && printf 'FAIL L2: relation endpoint does not resolve to an entity: %s\n' "$d"
    done
    n=$(printf '%s\n' "$DANGLING" | grep -c .)
    fails=$((fails + n))
fi

# --- L4: hook wiring (hooks.json commands point to existing files) ---------
if [ -f "$HOOKS" ]; then
    jq -r '.hooks | to_entries[] | .value[] | .hooks[]?.command' "$HOOKS" 2>/dev/null \
    | while IFS= read -r cmd; do
        # resolve ${CLAUDE_PLUGIN_ROOT} to the local plugin root, then take the first token (path)
        path=$(printf '%s' "$cmd" | sed "s#\${CLAUDE_PLUGIN_ROOT}#$PLUGIN_ROOT#g" | awk '{print $1}')
        case "$path" in
            /*) [ -f "$path" ] || printf 'FAIL L4: hooks.json command file missing: %s\n' "$cmd" ;;
        esac
    done > "${TMPDIR:-/tmp}/onto-l4.$$" 2>/dev/null
    if [ -s "${TMPDIR:-/tmp}/onto-l4.$$" ]; then
        cat "${TMPDIR:-/tmp}/onto-l4.$$"
        n=$(grep -c '^FAIL' "${TMPDIR:-/tmp}/onto-l4.$$")
        fails=$((fails + n))
    fi
    rm -f "${TMPDIR:-/tmp}/onto-l4.$$"
fi

# --- --full: aggregate the sibling verifiers (single entry point; scripts remain for back-compat) --
# The plan converges store-map-lint (manifest<->reality four-way) and plugin-audit-consistency
# (cross-skill path-spelling drift) into one verifier. Step 1 = aggregation: ontology-lint --full
# runs them and folds their verdict in, so "one command verifies all structural integrity". A later
# step can absorb their logic outright.
if [ "$FULL" -eq 1 ]; then
    if [ -f "$SCRIPT_DIR/store-map-lint.sh" ]; then
        smout=$(sh "$SCRIPT_DIR/store-map-lint.sh" --base "$BASE" --strict 2>&1); smrc=$?
        if [ "$smrc" -ne 0 ]; then printf 'FAIL --full: store-map-lint\n%s\n' "$smout"; fails=$((fails+1)); else echo "  --full: store-map-lint clean"; fi
    fi
    if [ -f "$SCRIPT_DIR/plugin-audit-consistency.sh" ]; then
        pcout=$(sh "$SCRIPT_DIR/plugin-audit-consistency.sh" "$PLUGIN_ROOT" --strict 2>&1); pcrc=$?
        if [ "$pcrc" -ne 0 ]; then printf 'FAIL --full: plugin-audit-consistency\n%s\n' "$pcout"; fails=$((fails+1)); else echo "  --full: plugin-audit-consistency clean"; fi
    fi
fi

# --- verdict ---------------------------------------------------------------
ne=$(jq '.entities|length' "$ABOX")
nr=$(jq '.relations|length' "$ABOX")
if [ "$fails" -eq 0 ]; then
    printf 'ontology-lint OK: %s entities / %s relations conform to TBox (%s warnings)\n' "$ne" "$nr" "$warns"
    exit 0
fi
printf 'ontology-lint FAIL: %s violation(s) (%s entities / %s relations)\n' "$fails" "$ne" "$nr"
[ "$STRICT" -eq 1 ] && exit 1
exit 0
