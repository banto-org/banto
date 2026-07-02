#!/bin/sh
# i18n-gen.sh — generate the EN tree (i18n/en) from the JA canonical tree (i18n/ja)
#               and (re)write the deterministic sync manifest (i18n/.sync-manifest.json).
#
# Determinism split: this script DETERMINISTICALLY decides which files are stale and
# records hashes; the TRANSLATION itself is delegated to an LLM (non-deterministic).
#
# Modes:
#   (default)   auto    — for each canonical file whose ja-hash != manifest (or whose EN
#                         is missing), call the translator to produce i18n/en/<rel>, then
#                         record hashes. Translator = $BANTO_I18N_TRANSLATE_CMD (default:
#                         `claude -p`). Receives the full prompt (rules + JA body) as $1.
#   --record    record  — do NOT translate; (re)compute the manifest from the i18n/ja and
#                         i18n/en files already on disk. Use when EN was authored by a
#                         trusted in-session translation or a reviewed Agent batch.
#
# Always prunes EN files / manifest entries whose JA source no longer exists.
# Note: relies on word-splitting over find output; plugin-internal paths contain no spaces.
set -eu

MODE=auto
case "${1:-}" in
    --record) MODE=record ;;
    "" ) ;;
    * ) echo "usage: i18n-gen.sh [--record]"; exit 2 ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
I18N="$PLUGIN_ROOT/i18n"
JA="$I18N/ja"
EN="$I18N/en"
MANIFEST="$I18N/.sync-manifest.json"
TRANSLATE_CMD=${BANTO_I18N_TRANSLATE_CMD:-claude -p}

if [ ! -d "$JA" ]; then echo "i18n-gen: no canonical tree ($JA) — nothing to do"; exit 0; fi
[ -f "$MANIFEST" ] || echo '{"files":{}}' > "$MANIFEST"

_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}
_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Structure-preserving translation contract handed to the LLM translator.
RULES='Translate the following Banto plugin file from Japanese to natural English.
STRICT RULES — do NOT translate / must stay byte-identical:
- frontmatter KEY names (name:, description:, allowed-tools:, user-invocable:, argument-hint:, compatibility:, etc.) and ALL YAML keys
- fixed structural markdown headings used as markers (e.g. ## Content, ## Topics discussed)
- code fences and everything inside them
- file paths, command names, and variables ({base}, ${CLAUDE_PLUGIN_ROOT}, $ARGUMENTS, $1, etc.)
DO translate:
- natural-language prose and comments
- trigger phrases — but REWRITE them as the natural English phrases a user would actually type (equivalent localization, NOT a literal word-for-word translation), and drop the Japanese trigger list
Preserve markdown structure, indentation, and line order. Keep every description field under 1024 characters.
Output ONLY the translated file content — no preamble, no code fence around the whole thing.

--- FILE BEGINS ---
'

tmp=$(mktemp)
printf '%s' "$(cat "$MANIFEST")" > "$tmp"
generated=0; recorded=0; pruned=0

for f in $(find "$JA" -type f | LC_ALL=C sort); do
    rel=${f#"$JA"/}
    enf="$EN/$rel"
    ja_hash=$(_hash "$f")
    prev_ja=$(jq -r --arg k "$rel" '.files[$k].ja_sha256 // empty' "$tmp")
    prev_ts=$(jq -r --arg k "$rel" '.files[$k].generated_at // empty' "$tmp")

    if [ "$MODE" = auto ]; then
        if [ "$ja_hash" != "$prev_ja" ] || [ ! -f "$enf" ]; then
            mkdir -p "$(dirname "$enf")"
            # shellcheck disable=SC2086
            $TRANSLATE_CMD "$RULES$(cat "$f")" > "$enf"
            generated=$((generated+1))
            prev_ts=""   # force fresh timestamp
        fi
    fi

    if [ ! -f "$enf" ]; then
        echo "i18n-gen: ERROR — no EN for $rel (run without --record, or author i18n/en/$rel first)" >&2
        rm -f "$tmp"; exit 1
    fi
    en_hash=$(_hash "$enf")
    ts=${prev_ts:-$(_now)}
    jq --arg k "$rel" --arg ja "$ja_hash" --arg en "$en_hash" --arg ts "$ts" \
        '.files[$k] = {ja_sha256:$ja, en_sha256:$en, generated_at:$ts}' "$tmp" > "$tmp.2"
    mv "$tmp.2" "$tmp"
    recorded=$((recorded+1))
done

# prune manifest entries + EN files whose JA source is gone
for rel in $(jq -r '.files | keys[]' "$tmp"); do
    if [ ! -f "$JA/$rel" ]; then
        jq --arg k "$rel" 'del(.files[$k])' "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
        rm -f "$EN/$rel"
        pruned=$((pruned+1))
    fi
done
if [ -d "$EN" ]; then
    for f in $(find "$EN" -type f); do
        rel=${f#"$EN"/}
        if [ ! -f "$JA/$rel" ]; then rm -f "$f"; fi
    done
    find "$EN" -type d -empty -delete 2>/dev/null || true
fi

SOURCE_COMMIT=$(git -C "$PLUGIN_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
jq -S --arg ts "$(_now)" --arg sc "$SOURCE_COMMIT" '. + {generated_at:$ts, source_commit:$sc}' "$tmp" > "$MANIFEST"
rm -f "$tmp"
echo "i18n-gen ($MODE): translated=$generated recorded=$recorded pruned=$pruned → $MANIFEST"
