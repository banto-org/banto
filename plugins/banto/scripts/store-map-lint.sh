#!/bin/sh
# store-map-lint.sh — deterministic link-rot linter for the ai-context store layout.
#
# Single source of truth: templates/store-layout.json (the machine-readable twin of
# skills/ai-context/references/directory-structure.md). This script validates, in four checks:
#   A. skill / odd.yaml / references path declarations  ⊆  manifest buckets   (catches drift like spec/odd.yaml's {base}/specs/)
#   B. manifest  ↔  filesystem reality                                        (declared-but-missing, real-but-undeclared/orphan)
#   C. directory-structure.md mapping table  ⊆  manifest                      (the human doc can't drift from the machine manifest)
#   D. related: / decision cross-links in decisions + workspace.md            (dangling references)
#
# Exit: warn-only (0) by default; --strict exits 1 on any finding. --quiet prints nothing when clean.
# Fail-open: jq absent / manifest absent → exit 0.
#
# Usage: store-map-lint.sh [--base <dir>] [--strict] [--quiet]
set -u

STRICT=0; QUIET=0; BASE_OVERRIDE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --strict) STRICT=1 ;;
        --quiet)  QUIET=1 ;;
        --base)   shift; BASE_OVERRIDE="${1:-}" ;;
        *) ;;
    esac
    shift
done

command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
MANIFEST="$PLUGIN_ROOT/templates/store-layout.json"
SKILLS_DIR="$PLUGIN_ROOT/skills"
DIRSTRUCT="$SKILLS_DIR/ai-context/references/directory-structure.md"
[ -f "$MANIFEST" ] || exit 0

# --- resolve base ---
if [ -n "$BASE_OVERRIDE" ]; then
    BASE="$BASE_OVERRIDE"
else
    BASE=$(sh "$PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD" 2>/dev/null)
fi

TMP=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/store-map-lint.$$"); mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/report"
# out() only appends to the report file — findings are counted from the file at the end, so writes
# made inside `... | while` subshells are not lost (a plain counter variable would be).
out() { printf '%s\n' "$1" >> "$TMP/report"; }

# known top-level bucket segments (first path component of every manifest bucket)
jq -r '.buckets[].path' "$MANIFEST" | awk -F/ '{print $1}' | sort -u > "$TMP/known_tops"
known() {
    # arg = first path segment of a referenced token; 0 if it is a known bucket / combined.txt / refs alias
    case "$1" in
        *-combined.txt) return 0 ;;
        WORKSPACE-refs.md) return 0 ;;
    esac
    grep -qxF "$1" "$TMP/known_tops"
}

# ---------- Check A: skill / odd / references declarations ⊆ manifest ----------
# Extract path tokens that follow a base marker: {base}/ {BASE}/ <base>/ .ai-context/
# Take the first segment and verify it is a known bucket.
legacy_prefix=0
find "$SKILLS_DIR" -type f \( -name '*.md' -o -name 'odd.yaml' \) 2>/dev/null | while IFS= read -r f; do
    grep -nE '(\{[bB]ase\}|<base>|\.ai-context)/[A-Za-z0-9_.-]+' "$f" 2>/dev/null | while IFS= read -r line; do
        ln=${line%%:*}
        # pull each "<marker>/<seg>" occurrence on the line
        printf '%s\n' "$line" | grep -oE '(\{[bB]ase\}|<base>|\.ai-context)/[A-Za-z0-9_.-]+' | while IFS= read -r tok; do
            seg=$(printf '%s' "$tok" | sed -E 's#^(\{[bB]ase\}|<base>|\.ai-context)/##')
            case "$tok" in .ai-context/*) echo legacy >> "$TMP/legacy" ;; esac
            # skip the "{base}/..." prose placeholder (literal ellipsis) — not a real bucket reference
            case "$seg" in ''|.|..|...) continue ;; esac
            known "$seg" || echo "A|${f#$PLUGIN_ROOT/}:$ln|undeclared bucket '$seg' (token: $tok)" >> "$TMP/raw"
        done
    done
done
[ -f "$TMP/legacy" ] && legacy_prefix=$(grep -c . "$TMP/legacy" 2>/dev/null || echo 0)
if [ -f "$TMP/raw" ]; then
    sort -u "$TMP/raw" | while IFS='|' read -r tag loc msg; do out "  [A decl→manifest] $loc — $msg"; done
fi

# ---------- Check C: directory-structure.md mapping table ⊆ manifest ----------
if [ -f "$DIRSTRUCT" ]; then
    # mapping table rows look like: | `decisions/` | ... |  — pull the first backticked folder token
    grep -E '^\| *`[^`]+`' "$DIRSTRUCT" 2>/dev/null | sed -E 's/^\| *`([^`]+)`.*/\1/' | while IFS= read -r cell; do
        # a cell may hold "tasks/active.md・tasks/old/" etc — take leading segment up to first / or space or ・
        seg=$(printf '%s' "$cell" | sed -E 's#[ /・].*##')
        [ -n "$seg" ] || continue
        known "$seg" || out "  [C doc→manifest] directory-structure.md table lists '$cell' (top '$seg') not in manifest"
    done
fi

# ---------- Check B: manifest ↔ reality ----------
if [ -n "$BASE" ] && [ -d "$BASE" ]; then
    # B1: non-lazy buckets must exist
    jq -r '.buckets[] | select(.lazy == false) | .path' "$MANIFEST" | while IFS= read -r p; do
        [ -e "$BASE/$p" ] || out "  [B manifest→fs] declared non-lazy bucket missing on disk: $p"
    done
    # B2: real top-level dirs/files must map to a known bucket (orphans)
    for entry in "$BASE"/*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        case "$name" in .*) continue ;; esac   # skip dotfiles
        known "$name" || out "  [B fs→manifest] real entry not in manifest (orphan): $name"
    done
    # B3: gitignore drift — buckets marked gitignore:true must be covered by the store .gitignore
    STORE_ROOT=$(cd -- "$BASE/.." && pwd 2>/dev/null)
    GI="$STORE_ROOT/.gitignore"
    if [ -f "$GI" ]; then
        jq -r '.buckets[] | select(.gitignore == true and .kind == "dir") | .path' "$MANIFEST" | while IFS= read -r p; do
            # covered if ANY path segment matches a standalone dir pattern in .gitignore
            # (e.g. "drafts/" covers docs/knowledges/drafts; "sessions/" covers sessions/pending).
            covered=no
            oldifs=$IFS; IFS=/
            for s in $p; do IFS=$oldifs; grep -qE "^${s}/?$" "$GI" && { covered=yes; break; }; done
            IFS=$oldifs
            [ "$covered" = yes ] || out "  [B gitignore] bucket '$p' is scope=ephemeral but no segment is in store .gitignore (would be committed)"
        done
    fi
fi

# ---------- Check D: dangling related: / decision cross-links ----------
if [ -n "$BASE" ] && [ -d "$BASE/decisions" ]; then
    # references of the form decisions/<name> or docs/<...> inside decisions/*.md front-matter `related:` blocks + workspace.md
    {
        find "$BASE/decisions" -name '*.md' 2>/dev/null
        find "$BASE/workspaces" -name 'workspace.md' 2>/dev/null
    } | while IFS= read -r f; do
        grep -oE '(decisions|docs)/[A-Za-z0-9_./\[\] -]+\.md' "$f" 2>/dev/null | sort -u | while IFS= read -r ref; do
            # allow wildcard/glob-y references ending in _*.md or containing *
            case "$ref" in *'*'*) continue ;; esac
            [ -e "$BASE/$ref" ] || echo "D|${f#$BASE/}|dangling link: $ref" >> "$TMP/draw"
        done
    done
    if [ -f "$TMP/draw" ]; then
        # cap noise: report up to 15 dangling links
        sort -u "$TMP/draw" | head -15 | while IFS='|' read -r tag loc msg; do out "  [D xref] $loc — $msg"; done
        dcount=$(sort -u "$TMP/draw" | wc -l | tr -d ' ')
        [ "$dcount" -gt 15 ] && out "  [D xref] … and $((dcount - 15)) more dangling links (run with full output)"
    fi
fi

# ---------- report ----------
findings=$(wc -l < "$TMP/report" 2>/dev/null | tr -d ' '); [ -n "$findings" ] || findings=0
if [ "$findings" -eq 0 ]; then
    [ "$QUIET" -eq 1 ] || echo "store-map-lint: clean — declarations, reality, and directory-structure.md all agree."
    [ "$legacy_prefix" -gt 0 ] && [ "$QUIET" -eq 0 ] && echo "  (note: $legacy_prefix legacy '.ai-context/' path mentions remain — store-first prefers {base}/.)"
    exit 0
fi

echo "=== ⚠ store-map-lint: $findings layout drift finding(s) ==="
sort "$TMP/report"
[ "$legacy_prefix" -gt 0 ] && echo "  (also: $legacy_prefix legacy '.ai-context/' path mentions — store-first prefers {base}/.)"
echo "  Source of truth: plugins/banto/templates/store-layout.json + skills/ai-context/references/directory-structure.md"
[ "$STRICT" -eq 1 ] && exit 1
exit 0
