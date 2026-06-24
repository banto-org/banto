#!/bin/sh
# _ai-context-paths.sh — shared helper resolving the effective ai-context base directory
#
# Meant to be sourced (direct execution also works: prints the base dir for debugging).
# Confines the central / legacy differences here; skills / hooks obtain paths via this helper.
#
# Provided functions:
#   _ai_context_mode <cwd>       → echoes "central" | "legacy" (legacy = grandfathered in-repo base)
#   _ai_context_base_dir <cwd>   → echoes the effective base dir (always exit 0)
#       1. central mapping hit       → <store>/<project> (e.g. ~/ai-context-store/customer-A)
#       2. existing in-repo base     → <toplevel>/.ai-context (grandfather; read/write as before)
#       3. local store mapping hit   → <local_root>/<project> (e.g. ~/ai-context-local/myrepo)
#       4. otherwise                 → derive: <store_root>/<toplevel dirname> (store-first default)
#   _ai_context_local_root       → echoes the local (GitHub-less) store root (env → ~/ai-context-local)
#   _ai_context_local_lookup <top> → echoes the local store project dir if registered (else return 1)
#   _ai_context_is_local <cwd>   → return 0 when cwd resolves into the local store
#   _ai_context_is_local_pinned <top> → return 0 when <top> is pinned local-only (mapping local:true)
#   _ai_context_store_root       → echoes the store root (mapping store_root → env → ~/ai-context-store)
#   _ai_context_derive_dir <cwd> → echoes the derived store project dir (deterministic -2/-3 suffix
#                                  when the dirname collides with another registered project)
#   _ai_context_author [cwd]     → echoes the author identifier (gh login → git user.name → $USER)
#   _ai_context_ws_pointer <base> [cwd]
#       → echoes the effective WS pointer file (for reading: git-dir pointer first → <base>/WORKSPACE.md)
#   _ai_context_ws_pointer_target <base> [cwd]
#       → echoes the WS pointer write target (git-dir when in git, else <base>/WORKSPACE.md)
#   _ai_context_ws_dir <base> [cwd]
#       → echoes the current workspace's real dir (<base>/workspaces/<author>/<topic>) (return 1 if absent)
#   _ai_context_active_tasks <base> [cwd]
#       → echoes the effective tasks file path (new layout if present, else legacy tasks/active.md)
#
# Decision (store-first, spec docs/specs/2026-06-11_store-first-architecture_spec.md):
#   The store is the only write path for NEW projects. In-repo .ai-context/ is never created
#   anymore; existing ones are grandfathered (resolution order 2) with a migration proposal.
#   Registration (mapping write) and skeleton creation happen only at scaffold time
#   (_ai-context-scaffold.sh) — this helper only resolves, never writes.
#
# POSIX compatible: macOS / Linux / WSL

# Location of this helper (and the resolver).
# When sourced, $0 is the caller, so the scripts dir is determined in this order:
#   1. CLAUDE_PLUGIN_ROOT/scripts (production)
#   2. dirname of $AI_PATHS set by the caller (the helper's own path; visible in the same shell when sourced)
#   3. dirname of $0 (fallback when sourced directly)
_AI_CONTEXT_SCRIPT_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
if [ -z "$_AI_CONTEXT_SCRIPT_DIR" ] && [ -n "${AI_PATHS:-}" ]; then
    _AI_CONTEXT_SCRIPT_DIR=$(cd "$(dirname "$AI_PATHS")" 2>/dev/null && pwd)
fi
if [ -z "$_AI_CONTEXT_SCRIPT_DIR" ]; then
    _AI_CONTEXT_SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
fi

# Echoes the local (GitHub-less) store root: $AI_CONTEXT_LOCAL_ROOT → ~/ai-context-local.
# Sibling of the central store. A repo lands here when it is unregistered and has no central
# store yet (non-blocking bootstrap). `/ai-context bootstrap` migrates it into the central store;
# `/ai-context local` pins it here (mapping local:true).
_ai_context_local_root() {
    echo "${AI_CONTEXT_LOCAL_ROOT:-$HOME/ai-context-local}"
}

# Echoes the local store's mapping.json path ($AI_CONTEXT_LOCAL_MAPPING → <local_root>/.mapping.json).
_ai_context_local_mapping() {
    echo "${AI_CONTEXT_LOCAL_MAPPING:-$(_ai_context_local_root)/.mapping.json}"
}

# Looks up <toplevel> in the local store mapping and echoes its project dir (<local_root>/<project>).
# Resolution only — never writes. Return 1 if not registered locally.
_ai_context_local_lookup() {
    _all_top="$1"
    [ -z "$_all_top" ] && return 1
    _all_map=$(_ai_context_local_mapping)
    [ -f "$_all_map" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    _all_root=$(_ai_context_local_root)
    _all_proj=$(jq -r --arg top "$_all_top" '.projects[$top].project // empty' "$_all_map" 2>/dev/null)
    [ -z "$_all_proj" ] && return 1
    echo "$_all_root/$_all_proj"
}

# Echoes the store root. Priority: mapping's store_root field (a team store registered there
# keeps working for derive) → $AI_CONTEXT_STORE_ROOT → ~/ai-context-store.
_ai_context_store_root() {
    _asr_map="${AI_CONTEXT_MAPPING:-${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}/.mapping.json}"
    if [ -f "$_asr_map" ] && command -v jq >/dev/null 2>&1; then
        _asr_root=$(jq -r '.store_root // empty' "$_asr_map" 2>/dev/null)
        case "$_asr_root" in
            "~/"*) _asr_root="$HOME/${_asr_root#\~/}" ;;
            "~")   _asr_root="$HOME" ;;
        esac
        if [ -n "$_asr_root" ]; then
            echo "$_asr_root"
            return 0
        fi
    fi
    echo "${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}"
}

# Echoes the derived store project dir for an unregistered cwd: <store_root>/<toplevel dirname>.
# Deterministic: when the dirname is already claimed by ANOTHER registered project in the
# mapping, append -2/-3/… (the same input always derives the same dir, so reads before
# registration and the scaffold-time registration agree). Resolution only — never writes.
_ai_context_derive_dir() {
    _add_cwd=$1
    _add_top=""
    command -v git >/dev/null 2>&1 \
        && _add_top=$(git -C "$_add_cwd" rev-parse --show-toplevel 2>/dev/null)
    [ -z "$_add_top" ] && _add_top=$(cd "$_add_cwd" 2>/dev/null && pwd -P)
    [ -z "$_add_top" ] && _add_top="$_add_cwd"
    _add_name=$(basename "$_add_top")
    _add_root=$(_ai_context_store_root)
    _add_map="${AI_CONTEXT_MAPPING:-${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}/.mapping.json}"
    _add_cand="$_add_name"
    if [ -f "$_add_map" ] && command -v jq >/dev/null 2>&1; then
        _add_i=1
        while jq -e --arg p "$_add_cand" --arg top "$_add_top" '
                .projects | to_entries
                | any(.key as $k | .value as $v
                      | (($v.project // ($k | split("/") | last)) == $p) and ($k != $top))
            ' "$_add_map" >/dev/null 2>&1; do
            _add_i=$((_add_i + 1))
            _add_cand="$_add_name-$_add_i"
        done
    fi
    echo "$_add_root/$_add_cand"
}

# legacy = grandfathered in-repo base; central = anything resolving into the store.
_ai_context_mode() {
    case "$(_ai_context_base_dir "$1")" in
        */.ai-context) echo legacy ;;
        *)             echo central ;;
    esac
}

_ai_context_base_dir() {
    _aicp_cwd=$1
    # 1. mapping hit (exact / prefix / worktree / remote — resolve-store-path.sh)
    _aicp_resolver="$_AI_CONTEXT_SCRIPT_DIR/resolve-store-path.sh"
    if [ -f "$_aicp_resolver" ]; then
        _aicp_base=$(sh "$_aicp_resolver" --store-dir "$_aicp_cwd" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$_aicp_base" ]; then
            echo "$_aicp_base"
            return 0
        fi
    fi
    # 2. grandfather: an existing in-repo .ai-context keeps working (cwd first, then git toplevel
    #    so sessions started in a subdir of a legacy repo still find the repo's base)
    if [ -d "$_aicp_cwd/.ai-context" ]; then
        echo "$_aicp_cwd/.ai-context"
        return 0
    fi
    _aicp_top=""
    if command -v git >/dev/null 2>&1; then
        _aicp_top=$(git -C "$_aicp_cwd" rev-parse --show-toplevel 2>/dev/null)
        if [ -n "$_aicp_top" ] && [ "$_aicp_top" != "$_aicp_cwd" ] && [ -d "$_aicp_top/.ai-context" ]; then
            echo "$_aicp_top/.ai-context"
            return 0
        fi
    fi
    # 3. local store (GitHub-less). The scaffold registers an unregistered repo here when there is
    #    no central store yet (non-blocking). Keyed by git toplevel; fall back to cwd outside git.
    _aicp_key="$_aicp_top"
    [ -z "$_aicp_key" ] && _aicp_key="$_aicp_cwd"
    _aicp_local=$(_ai_context_local_lookup "$_aicp_key")
    if [ -n "$_aicp_local" ]; then
        echo "$_aicp_local"
        return 0
    fi
    # 4. derive (store-first default — even unregistered repos resolve into the store)
    _ai_context_derive_dir "$_aicp_cwd"
}

# Predicate: does <cwd> resolve into the local (GitHub-less) store? (return 0 yes / 1 no)
# Usage: _ai_context_is_local <cwd>
_ai_context_is_local() {
    _ail_root=$(_ai_context_local_root)
    case "$(_ai_context_base_dir "$1")" in
        "$_ail_root"/*) return 0 ;;
        *)              return 1 ;;
    esac
}

# Predicate: is <toplevel> pinned local-only (mapping local:true)? (return 0 yes / 1 no)
# Checks the local store mapping first, then the central mapping (either may carry local:true).
# Usage: _ai_context_is_local_pinned <toplevel>
_ai_context_is_local_pinned() {
    _alp_top="$1"
    [ -z "$_alp_top" ] && return 1
    command -v jq >/dev/null 2>&1 || return 1
    _alp_lmap=$(_ai_context_local_mapping)
    if [ -f "$_alp_lmap" ]; then
        _alp_v=$(jq -r --arg top "$_alp_top" '.projects[$top].local // empty' "$_alp_lmap" 2>/dev/null)
        [ "$_alp_v" = "true" ] && return 0
    fi
    _alp_cmap="${AI_CONTEXT_MAPPING:-${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}/.mapping.json}"
    if [ -f "$_alp_cmap" ]; then
        _alp_v=$(jq -r --arg top "$_alp_top" '.projects[$top].local // empty' "$_alp_cmap" 2>/dev/null)
        [ "$_alp_v" = "true" ] && return 0
    fi
    return 1
}

# Echoes the author identifier (shared by the workspaces/<author>/ namespace and decisions naming).
# Derivation order: gh login → git config user.name → $USER
# (spec: docs/specs/2026-06-04_ai-context-personal-state-separation; same logic as decisions naming)
# Usage: _ai_context_author [cwd] (with cwd, git config is read from that repo)
_ai_context_author() {
    # gh api is a network call, so only successful results are cached persistently
    # (do not hit it on every hot-path UserPromptSubmit/SessionStart). The offline
    # git/$USER fallback is not cached persistently = naturally recovers to the
    # canonical value (gh login) once back online. However, for 5 minutes after a
    # gh failure a **negative cache** suppresses retries (the old implementation hit
    # a network timeout on every prompt when offline/unauthenticated; found and
    # fixed in the 2026-06-05 audit).
    _aca_cache="${TMPDIR:-/tmp}/banto-ai-context-author-$(id -u 2>/dev/null || echo u)"
    if [ -s "$_aca_cache" ]; then
        cat "$_aca_cache"
        return 0
    fi
    _aca_neg="${_aca_cache}.neg"
    _aca_try_gh=1
    if [ -f "$_aca_neg" ]; then
        _aca_age=$(( $(date +%s) - $(stat -c %Y "$_aca_neg" 2>/dev/null || stat -f %m "$_aca_neg" 2>/dev/null || echo 0) ))
        [ "$_aca_age" -lt 300 ] && _aca_try_gh=0
    fi
    _aca_author=""
    if [ "$_aca_try_gh" = "1" ]; then
        _aca_author=$(gh api user --jq '.login' 2>/dev/null)
    fi
    if [ -n "$_aca_author" ]; then
        printf '%s\n' "$_aca_author" > "$_aca_cache" 2>/dev/null || true
        rm -f "$_aca_neg" 2>/dev/null
    else
        [ "$_aca_try_gh" = "1" ] && touch "$_aca_neg" 2>/dev/null
        if [ -n "${1:-}" ]; then
            _aca_author=$(git -C "$1" config user.name 2>/dev/null)
        else
            _aca_author=$(git config user.name 2>/dev/null)
        fi
        [ -z "$_aca_author" ] && _aca_author="${USER:-unknown}"
    fi
    echo "$_aca_author"
}

# Echoes the effective WS pointer file (for reading). Priority:
#   1. <git-dir>/banto-ws-pointer.md … per-checkout (independent per worktree = no clashes in parallel work.
#      A worktree's git-dir is .git/worktrees/<name>, so it shares the checkout's fate and is never committed)
#   2. <base>/WORKSPACE.md … per-store compatibility fallback (right after migration / non-git)
# Usage: _ai_context_ws_pointer <base> [cwd]
_ai_context_ws_pointer() {
    _awp_base="$1"
    [ -z "$_awp_base" ] && return 1
    if command -v git >/dev/null 2>&1; then
        _awp_gd=$(git -C "${2:-$PWD}" rev-parse --absolute-git-dir 2>/dev/null)
        if [ -n "$_awp_gd" ] && [ -f "$_awp_gd/banto-ws-pointer.md" ]; then
            echo "$_awp_gd/banto-ws-pointer.md"
            return 0
        fi
    fi
    echo "$_awp_base/WORKSPACE.md"
}

# Echoes the WS pointer write target (used by /ws new and switch).
# Always the git-dir (per-checkout) inside git; <base>/WORKSPACE.md outside git.
# Usage: _ai_context_ws_pointer_target <base> [cwd]
_ai_context_ws_pointer_target() {
    _awt_base="$1"
    [ -z "$_awt_base" ] && return 1
    if command -v git >/dev/null 2>&1; then
        _awt_gd=$(git -C "${2:-$PWD}" rev-parse --absolute-git-dir 2>/dev/null)
        if [ -n "$_awt_gd" ]; then
            echo "$_awt_gd/banto-ws-pointer.md"
            return 0
        fi
    fi
    echo "$_awt_base/WORKSPACE.md"
}

# Echoes the current workspace's real dir (<base>/workspaces/<author>/<topic>).
# <topic> comes from the "# Workspace: ..." line of the effective pointer (git-dir first → WORKSPACE.md).
# Without the new layout (legacy / unmigrated), outputs nothing and returns 1.
# Usage: _ai_context_ws_dir <base> [cwd]
_ai_context_ws_dir() {
    _awd_base="$1"
    [ -z "$_awd_base" ] && return 1
    _awd_ws=$(_ai_context_ws_pointer "$_awd_base" "${2:-}")
    [ -f "$_awd_ws" ] || return 1
    _awd_topic=$(grep -m1 '^# Workspace:' "$_awd_ws" 2>/dev/null | sed 's/^# Workspace:[[:space:]]*//')
    [ -z "$_awd_topic" ] && return 1
    _awd_author=$(_ai_context_author "${2:-}")
    if [ -d "$_awd_base/workspaces/$_awd_author/$_awd_topic" ]; then
        echo "$_awd_base/workspaces/$_awd_author/$_awd_topic"
        return 0
    fi
    return 1
}

# Echoes the current workspace's effective tasks file path (read fallback, always on).
# Returns the new layout <base>/workspaces/<author>/<topic>/tasks.md if present, else the
# legacy <base>/tasks/active.md (non-destructive guarantee for legacy projects). <topic>
# comes from the "# Workspace: ..." line of <base>/WORKSPACE.md. Hooks use this in Phase 2.
# Usage: _ai_context_active_tasks <base> [cwd]
_ai_context_active_tasks() {
    _aat_base="$1"
    [ -z "$_aat_base" ] && return 1
    _aat_dir=$(_ai_context_ws_dir "$_aat_base" "${2:-}")
    if [ -n "$_aat_dir" ] && [ -f "$_aat_dir/tasks.md" ]; then
        echo "$_aat_dir/tasks.md"
        return 0
    fi
    echo "$_aat_base/tasks/active.md"
}

# Primary use is sourcing the functions. Skills / CLI can fetch one line via explicit flags:
#   base=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD")
#   author=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author "$PWD")
# When sourced, the parent's positional args may be inherited, so output only on explicit flags
# (so dashboards etc. sourcing this with CWD in $1 do not emit spurious output).
case "${1:-}" in
    --resolve) _ai_context_base_dir "${2:-$PWD}" ;;
    --derive)  _ai_context_derive_dir "${2:-$PWD}" ;;
    --author)  _ai_context_author "${2:-$PWD}" ;;
    --ws-pointer)        _c="${2:-$PWD}"; _ai_context_ws_pointer "$(_ai_context_base_dir "$_c")" "$_c" ;;
    --ws-pointer-target) _c="${2:-$PWD}"; _ai_context_ws_pointer_target "$(_ai_context_base_dir "$_c")" "$_c" ;;
esac
