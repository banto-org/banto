#!/bin/sh
# resolve-store-path.sh — resolves cwd + relative path into the real path inside the central store (single-store version)
#
# Design: decisions/2026-05-30_002 (fixed to one org store). Simplified from the old multi-store (personal+org) version.
#
# Usage:
#   resolve-store-path.sh <cwd> [relative-path]   # returns the real path inside the store
#   resolve-store-path.sh --store-dir <cwd>        # returns the project dir inside the store
#
# Exit codes:
#   0  resolved (absolute path on stdout)
#   2  argument error / mapping.json missing / jq missing
#   3  cwd not registered in the mapping (callers fall back to legacy mode)
#
# Location of mapping.json (priority order):
#   1. $AI_CONTEXT_MAPPING (for tests / overrides)
#   2. $AI_CONTEXT_STORE_ROOT/.mapping.json
#   3. ~/ai-context-store/.mapping.json
#
# Resolution order (fallback chain):
#   1. Path match (exact / prefix / worktree_siblings)
#   2. git worktree → re-match using the main worktree's path (worktrees need no registration)
#   3. origin remote URL → matched against projects[].remotes (clones need no registration)
#      Write remotes in normalized form: lowercase without protocol/credential/.git (e.g. github.com/org/repo)
#      Example: "remotes": ["github.com/banto-org/banto"]
#
# POSIX compatible: macOS / Linux / WSL

MODE=path
CWD=""
REL=""

case "${1:-}" in
    --store-dir) MODE=store; CWD="${2:-}" ;;
    "")
        echo "usage: resolve-store-path.sh <cwd> [relative-path] | --store-dir <cwd>" >&2
        exit 2 ;;
    *) CWD="$1"; REL="${2:-}" ;;
esac

if [ -z "$CWD" ]; then
    echo "resolve-store-path: cwd is not specified" >&2
    exit 2
fi

# Strip trailing slash (keep a lone "/")
case "$CWD" in
    */) [ "$CWD" != "/" ] && CWD="${CWD%/}" ;;
esac

if ! command -v jq >/dev/null 2>&1; then
    echo "resolve-store-path: jq is required" >&2
    exit 2
fi

MAPPING="${AI_CONTEXT_MAPPING:-${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}/.mapping.json}"
if [ ! -f "$MAPPING" ]; then
    echo "resolve-store-path: mapping.json not found ($MAPPING)" >&2
    exit 2
fi

# Reverse-look-up cwd and assemble the store/project dir (single store).
# Match: exact / path prefix / worktree_siblings (exact or prefix). Longest key wins on multiple matches.
SENTINEL="__UNREGISTERED__"

# Resolve the given path via the mapping and echo the ~-expanded store dir. Return 1 if unregistered.
_lookup_store() {
    _ls_path="$1"
    _ls_result=$(jq -r --arg cwd "$_ls_path" --arg none "$SENTINEL" '
        (.store_root // "~/ai-context-store") as $root
        | ( .projects
            | to_entries
            | map(
                .key as $k
                | .value as $v
                | select(
                    $k == $cwd
                    or ($cwd | startswith($k + "/"))
                    or (($v.worktree_siblings // [])
                        | any(. as $s | $cwd == $s or ($cwd | startswith($s + "/"))))
                  )
              )
            | sort_by(.key | length)
            | last
          ) as $m
        | if $m == null then $none
          else $root + "/" + ($m.value.project // ($m.key | split("/") | last))
          end
    ' "$MAPPING" 2>/dev/null)
    if [ "$_ls_result" = "$SENTINEL" ] || [ -z "$_ls_result" ]; then
        return 1
    fi
    # ~ expansion of store_root
    case "$_ls_result" in
        "~/"*) _ls_result="$HOME/${_ls_result#\~/}" ;;
        "~")   _ls_result="$HOME" ;;
    esac
    echo "$_ls_result"
}

# Match the (normalized) origin remote URL against projects[].remotes in the mapping and echo the store dir.
# Normalized form: protocol/credential stripped, scp ":" → "/", ".git" stripped, lowercased (e.g. github.com/org/repo).
# With remotes in the mapping, any clone connects to central automatically regardless of its
# path (even clones into other directories) — zero per-clone registration. Return 1 if unregistered.
_lookup_store_by_remote() {
    _lsr_rem="$1"
    [ -z "$_lsr_rem" ] && return 1
    _lsr_result=$(jq -r --arg rem "$_lsr_rem" --arg none "$SENTINEL" '
        (.store_root // "~/ai-context-store") as $root
        | ( .projects | to_entries
            | map(select(((.value.remotes // []) | map(ascii_downcase) | index($rem)) != null))
            | first
          ) as $m
        | if $m == null then $none
          else $root + "/" + ($m.value.project // ($m.key | split("/") | last))
          end
    ' "$MAPPING" 2>/dev/null)
    if [ "$_lsr_result" = "$SENTINEL" ] || [ -z "$_lsr_result" ]; then
        return 1
    fi
    case "$_lsr_result" in
        "~/"*) _lsr_result="$HOME/${_lsr_result#\~/}" ;;
        "~")   _lsr_result="$HOME" ;;
    esac
    echo "$_lsr_result"
}

STORE_DIR=$(_lookup_store "$CWD")

# Even when cwd is unregistered, a git worktree inherits the main worktree's registration.
# Avoids per-worktree mapping registration and the annoyance of scaffold creating a
# spurious .ai-context/ (the main worktree is the first entry in porcelain output).
if [ -z "$STORE_DIR" ] && command -v git >/dev/null 2>&1; then
    MAIN_WT=$(git -C "$CWD" worktree list --porcelain 2>/dev/null \
        | awk '/^worktree /{sub(/^worktree /, ""); print; exit}')
    if [ -n "$MAIN_WT" ] && [ "$MAIN_WT" != "$CWD" ]; then
        STORE_DIR=$(_lookup_store "$MAIN_WT")
    fi
fi

# Still unresolved → match by origin remote URL (clone-path-independent connection).
if [ -z "$STORE_DIR" ] && command -v git >/dev/null 2>&1; then
    _REMOTE=$(git -C "$CWD" remote get-url origin 2>/dev/null)
    if [ -n "$_REMOTE" ]; then
        _NREMOTE=$(printf '%s' "$_REMOTE" \
            | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^@/]+@##; s#:#/#; s#\.git$##; s#/+$##' \
            | tr '[:upper:]' '[:lower:]')
        [ -n "$_NREMOTE" ] && STORE_DIR=$(_lookup_store_by_remote "$_NREMOTE")
    fi
fi

if [ -z "$STORE_DIR" ]; then
    echo "resolve-store-path: cwd is not registered in the mapping ($CWD)" >&2
    exit 3
fi

if [ "$MODE" = "store" ] || [ -z "$REL" ]; then
    echo "$STORE_DIR"
else
    REL="${REL#/}"
    echo "$STORE_DIR/$REL"
fi
