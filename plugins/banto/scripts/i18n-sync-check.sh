#!/bin/sh
# i18n-sync-check.sh — deterministic drift gate for the JA-canonical / EN-generated tree.
#
# The translation step (i18n-gen.sh) is non-deterministic (LLM), but the *sync check*
# is fully deterministic: it verifies that i18n/en was generated from the CURRENT
# i18n/ja, by comparing sha256 hashes recorded in i18n/.sync-manifest.json.
#
# Fails (exit 1) when:
#   - a canonical (ja) file changed since EN was last generated      (STALE)
#   - a canonical file has no manifest entry / no EN counterpart     (new / MISSING)
#   - an EN file was hand-edited (its hash != recorded)              (TAMPERED)
#   - a manifest entry / EN file has no JA source                    (ORPHAN)
#
# No-op (exit 0) when i18n/ja does not exist yet (pre-migration trees stay green).
#
# Wired into CI (.github/workflows/ci.yml) and scripts/pre-push-check.sh.
# Note: relies on word-splitting over find output; plugin-internal paths contain no spaces.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
I18N="$PLUGIN_ROOT/i18n"
JA="$I18N/ja"
EN="$I18N/en"
MANIFEST="$I18N/.sync-manifest.json"

if [ ! -d "$JA" ]; then
    echo "i18n-sync: not initialized (no i18n/ja) — skip"
    exit 0
fi
if [ ! -f "$MANIFEST" ]; then
    echo "i18n-sync FAIL: manifest missing ($MANIFEST). Run: sh plugins/banto/scripts/i18n-gen.sh"
    exit 1
fi

_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

problems=""
add() { problems="${problems}  - $1
"; }

# 1) every canonical (ja) file must be generated and in sync
for f in $(find "$JA" -type f | LC_ALL=C sort); do
    rel=${f#"$JA"/}
    mja=$(jq -r --arg k "$rel" '.files[$k].ja_sha256 // empty' "$MANIFEST")
    men=$(jq -r --arg k "$rel" '.files[$k].en_sha256 // empty' "$MANIFEST")
    if [ -z "$mja" ]; then add "STALE (new canonical, not generated): $rel"; continue; fi
    if [ "$(_hash "$f")" != "$mja" ]; then add "STALE (ja changed since last gen): $rel"; fi
    if [ ! -f "$EN/$rel" ]; then add "MISSING en: $rel"; continue; fi
    if [ "$(_hash "$EN/$rel")" != "$men" ]; then add "TAMPERED (en hand-edited): $rel"; fi
done

# 2) manifest entries whose ja source was removed
for rel in $(jq -r '.files | keys[]' "$MANIFEST"); do
    if [ ! -f "$JA/$rel" ]; then add "ORPHAN (manifest entry, ja removed): $rel"; fi
done

# 3) generated EN files with no ja counterpart
if [ -d "$EN" ]; then
    for f in $(find "$EN" -type f); do
        rel=${f#"$EN"/}
        if [ ! -f "$JA/$rel" ]; then add "ORPHAN (en file, no ja): $rel"; fi
    done
fi

if [ -n "$problems" ]; then
    printf 'i18n-sync FAIL: EN out of sync with JA canonical:\n%s' "$problems"
    echo "→ Fix: sh plugins/banto/scripts/i18n-gen.sh   (regenerates EN from JA canonical)"
    exit 1
fi
echo "i18n-sync OK ($(jq -r '.files | length' "$MANIFEST") files in sync)"
