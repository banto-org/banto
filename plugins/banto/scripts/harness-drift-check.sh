#!/bin/sh
# harness-drift-check.sh — detects drift between the editing repo and the running plugin (live cache).
#
# Self-driving monitor for the CONCEPT principle "editing repo = running plugin, always in sync".
# Detects recurrence of the 4-way state split from decision 2026-05-29_005
# (main stale / worktree live / cache copy / store divergence).
#   spec: docs/specs/2026-06-10_harness-next-level (P2)
#
# Output (stdout): markdown lines when drift exists, nothing otherwise. Picked up by pending-channel.sh drift.
# Usage: harness-drift-check.sh [cwd]
# fail-open: jq missing / out-of-scope repo → no output, exit 0.

set -u

command -v jq >/dev/null 2>&1 || exit 0
CWD="${1:-$PWD}"

# Find plugin.json in the editing repo (banto development repo layout)
EDIT_PJ=""
for cand in \
    "$CWD/plugins/banto/.claude-plugin/plugin.json" \
    "$CWD/.claude-plugin/plugin.json"; do
    [ -f "$cand" ] && EDIT_PJ="$cand" && break
done
# Out of scope (not the banto development repo) → do nothing
[ -z "$EDIT_PJ" ] && exit 0

# plugin.json of the running plugin (hook origin = live cache or the repo itself).
# CLAUDE_PLUGIN_ROOT is only substituted in hooks.json commands — when this script runs
# outside that context, auto-resolve the live cache from installed_plugins.json instead of
# silently no-opping (a silent no-op here is a false GREEN for the drift monitor).
RUN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$RUN_ROOT" ]; then
    RUN_ROOT=$(jq -r '.plugins["banto@banto-marketplace"][0].installPath // empty' \
        "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null)
fi
RUN_PJ="$RUN_ROOT/.claude-plugin/plugin.json"
if [ ! -f "$RUN_PJ" ]; then
    printf 'harness-drift-check: live plugin not resolvable (CLAUDE_PLUGIN_ROOT unset and no installed_plugins.json entry) — drift NOT verified.\n' >&2
    exit 0
fi

EDIT_VER=$(jq -r '.version // empty' "$EDIT_PJ" 2>/dev/null)
RUN_VER=$(jq -r '.version // empty' "$RUN_PJ" 2>/dev/null)
[ -z "$EDIT_VER" ] || [ -z "$RUN_VER" ] && exit 0

# If both point at the same file there is no drift (hooks running directly from the repo)
EDIT_REAL=$(cd "$(dirname "$EDIT_PJ")" 2>/dev/null && pwd)
RUN_REAL=$(cd "$(dirname "$RUN_PJ")" 2>/dev/null && pwd)
[ "$EDIT_REAL" = "$RUN_REAL" ] && DRIFT_VER=0 || DRIFT_VER=1

TODAY=$(date +%Y-%m-%d 2>/dev/null || echo "")
OUT=""

if [ "$DRIFT_VER" = "1" ] && [ "$EDIT_VER" != "$RUN_VER" ]; then
    OUT="## ⚠️ harness drift (${TODAY})
- Editing repo = \`${EDIT_VER}\` / running plugin (cache) = \`${RUN_VER}\` → **version mismatch**.
- Fix: if the version was already bumped, run \`claude plugin marketplace update banto-marketplace && claude plugin update banto@banto-marketplace\`, then restart to go live."
fi

# Declaration drift inside the editing repo: marketplace.json must carry the same version
# as plugin.json (a stale 5.21.25 marketplace nearly shipped on 2026-06-11).
MKT="$CWD/.claude-plugin/marketplace.json"
if [ -f "$MKT" ]; then
    MKT_VER=$(jq -r '.plugins[0].version // empty' "$MKT" 2>/dev/null)
    MKT_META=$(jq -r '.metadata.version // empty' "$MKT" 2>/dev/null)
    if { [ -n "$MKT_VER" ] && [ "$MKT_VER" != "$EDIT_VER" ]; } \
       || { [ -n "$MKT_META" ] && [ "$MKT_META" != "$EDIT_VER" ]; }; then
        [ -n "$OUT" ] && OUT="$OUT
"
        OUT="${OUT}## ⚠️ Declaration drift (${TODAY})
- \`.claude-plugin/marketplace.json\` declares \`${MKT_VER:-?}\` (metadata \`${MKT_META:-?}\`) while \`plugin.json\` is \`${EDIT_VER}\` → bump both in the same commit (CI also gates this)."
    fi
fi

# Same-version different-content drift (the forbidden state: version equal but trees diverged).
# Plugin rename also lands here (.name mismatch). Content compared via a lightweight checksum
# over hooks.json + hook/script/skill sources (cksum is POSIX; ordering fixed by sort).
if [ "$DRIFT_VER" = "1" ] && [ "$EDIT_VER" = "$RUN_VER" ]; then
    EDIT_NAME=$(jq -r '.name // empty' "$EDIT_PJ" 2>/dev/null)
    RUN_NAME=$(jq -r '.name // empty' "$RUN_PJ" 2>/dev/null)
    _tree_sum() { # plugin root dir
        find "$1/hooks" "$1/scripts" "$1/skills" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.json' -o -name '*.md' \) 2>/dev/null \
            | LC_ALL=C sort | while IFS= read -r _f; do cksum < "$_f" 2>/dev/null; done | cksum | awk '{print $1}'
    }
    EDIT_SUM=$(_tree_sum "$(dirname "$(dirname "$EDIT_PJ")")")
    RUN_SUM=$(_tree_sum "$(dirname "$(dirname "$RUN_PJ")")")
    if [ "$EDIT_NAME" != "$RUN_NAME" ] || [ "$EDIT_SUM" != "$RUN_SUM" ]; then
        [ -n "$OUT" ] && OUT="$OUT
"
        OUT="${OUT}## ⚠️ Same-version different-content drift (${TODAY})
- Editing repo and running plugin both claim \`${EDIT_VER}\` but their contents differ (name: \`${EDIT_NAME:-?}\` vs \`${RUN_NAME:-?}\`, tree checksum mismatch) → **forbidden state**.
- Fix: bump the version in the editing repo, then update the live plugin (never leave same-version different-content drift)."
    fi
fi

# Rule-declared lockfiles must all be enforced by lint-guard.sh (declaration ⊆ hook; H-20 recurrence check)
CE_RULE="$CWD/plugins/banto/templates/rules/code-editing.md"
LG_HOOK="$CWD/plugins/banto/hooks/lint-guard.sh"
if [ -f "$CE_RULE" ] && [ -f "$LG_HOOK" ]; then
    MISSING_LF=""
    for lf in $(grep -oE '"\*\*/[^"]+"' "$CE_RULE" 2>/dev/null | tr -d '"' | sed 's#\*\*/##' \
                | grep -E '(\.lock|\.lockb|^go\.sum$|^package-lock\.json$)' | sort -u); do
        grep -F "$lf" "$LG_HOOK" >/dev/null 2>&1 || MISSING_LF="$MISSING_LF $lf"
    done
    if [ -n "$MISSING_LF" ]; then
        [ -n "$OUT" ] && OUT="$OUT
"
        OUT="${OUT}## ⚠️ Lockfile declaration drift (${TODAY})
- code-editing.md declares lockfiles not enforced by lint-guard.sh:${MISSING_LF} → add them to the hook case (declaration must not exceed enforcement)."
    fi
fi

# Uncommitted plugin changes in the editing repo are an early sign of "not yet propagated to the cache"
if command -v git >/dev/null 2>&1; then
    EDIT_ROOT=$(git -C "$(dirname "$EDIT_PJ")" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$EDIT_ROOT" ]; then
        DIRTY=$(git -C "$EDIT_ROOT" status --porcelain -- plugins/banto 2>/dev/null | head -1)
        if [ -n "$DIRTY" ]; then
            [ -n "$OUT" ] && OUT="$OUT
"
            OUT="${OUT}## ⚠️ Uncommitted plugin changes (${TODAY})
- Uncommitted changes exist under \`plugins/banto\` in the editing repo → possibly not yet propagated to the live cache."
        fi
    fi
fi

# Reference liveness (decision 2026-06-22: reference survival is deterministic + continuous →
# belongs in this hook, not a one-off audit axis). Each references/<file>.md linked from a SKILL.md
# must resolve to a non-empty file; a broken/empty reference silently breaks progressive loading.
# Variable-path links (references/{sub}.md) don't match the literal regex, so they're skipped.
SK_DIR="$CWD/plugins/banto/skills"
if [ -d "$SK_DIR" ]; then
    REF_PROBLEMS=""
    for smd in "$SK_DIR"/*/SKILL.md; do
        [ -f "$smd" ] || continue
        sdir=$(dirname "$smd")
        for ref in $(grep -oE 'references/[A-Za-z0-9_.-]+\.md' "$smd" 2>/dev/null | sort -u); do
            rp="$sdir/$ref"
            if [ ! -f "$rp" ]; then
                REF_PROBLEMS="$REF_PROBLEMS
- \`$(basename "$sdir")/SKILL.md\` → \`$ref\` (missing)"
            elif [ ! -s "$rp" ]; then
                REF_PROBLEMS="$REF_PROBLEMS
- \`$(basename "$sdir")/SKILL.md\` → \`$ref\` (empty)"
            fi
        done
    done
    if [ -n "$REF_PROBLEMS" ]; then
        [ -n "$OUT" ] && OUT="$OUT
"
        OUT="${OUT}## ⚠️ Reference drift (${TODAY})${REF_PROBLEMS}"
    fi
fi

[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
