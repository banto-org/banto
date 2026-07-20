#!/bin/sh
# migrate-to-store.sh — migrates existing <cwd>/.ai-context/ assets into the central store (T3.1)
#
# Usage:
#   migrate-to-store.sh [--mode copy|history] [--apply] <cwd>
#     Default is dry-run (shows the migration plan without writing anything). Run with --apply.
#     --mode copy    : copy files into the store (safe, default). The original .ai-context/ remains.
#     --mode history : guide through git subtree split to create a history-preserving branch of
#                      .ai-context/ and pull it into the store repo (keeps history; store repo required).
#
# Scope: all files under .ai-context/ (standard dirs decisions/docs/tasks + non-standard dirs such as
#        audit/concept/chat-logs + WORKSPACE.md / config.json; changed to full aggregation in v5.21.7).
#        Exclusions are regenerated artifacts (project-index/ full-index/ *-combined.txt), per-machine
#        (.obsidian/), VCS (.git/), .DS_Store, and the per-project .gitignore only.
#        Note: .gitignore is for the in-repo layout (.ai-context/ prefix) and becomes dead config in the
#        flattened store, so it is not migrated. The store's ignores are managed by the root .gitignore.
#
# Safety principles:
#   - Default dry-run. Nothing is written without --apply
#   - copy never overwrites (skips with a warning when the store has a same-named file)
#   - The original .ai-context/ is never deleted (separate user decision in T3.4)
#
# POSIX compatible: macOS / Linux / WSL

set -u

MODE=copy
APPLY=0
CWD=""

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)  MODE="$2"; shift 2 ;;
        --apply) APPLY=1; shift ;;
        --*)     echo "unknown option: $1" >&2; exit 2 ;;
        *)       CWD="$1"; shift ;;
    esac
done

[ -z "$CWD" ] && { echo "usage: migrate-to-store.sh [--mode copy|history] [--apply] <cwd>" >&2; exit 2; }
[ -d "$CWD/.ai-context" ] || { echo "migrate: $CWD/.ai-context does not exist" >&2; exit 2; }
case "$MODE" in copy|history) ;; *) echo "migrate: --mode must be copy|history" >&2; exit 2 ;; esac

SCRIPT_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
RESOLVER="$SCRIPT_DIR/resolve-store-path.sh"

# Resolve the store's project dir
DEST=$(sh "$RESOLVER" --store-dir "$CWD" 2>/dev/null)
RC=$?
if [ $RC -ne 0 ] || [ -z "$DEST" ]; then
    echo "migrate: cwd is not registered in the mapping (register it in mapping.json first): $CWD" >&2
    exit 3
fi

SRC="$CWD/.ai-context"
# Scope: all files under .ai-context (full aggregation including non-standard dirs like audit/concept).
# Exclusions: regenerated artifacts, per-machine, VCS, per-project .gitignore: project-index/ full-index/
#        *-combined.txt .obsidian/ .git/ .DS_Store .gitignore (the store's root .gitignore manages ignores)

echo "=== ai-context migration ($([ $APPLY -eq 1 ] && echo APPLY || echo DRY-RUN) / mode=$MODE) ==="
echo "  from: $SRC"
echo "  to  : $DEST"
echo ""

if [ "$MODE" = "history" ]; then
    cat <<EOF
[history mode] steps to migrate while preserving git history (store repo required):

  1. In the project repo, split out the history of .ai-context/ only:
       git -C "$CWD" subtree split --prefix=.ai-context -b _aicontext-export
  2. In the store repo, pull in that history:
       git -C "$DEST" pull "$CWD" _aicontext-export --allow-unrelated-histories
  3. After the pull, delete the export branch:
       git -C "$CWD" branch -D _aicontext-export

  Note: the store repo ($DEST) must already be git-initialized (after Phase 5 / init).
  Note: automatic execution has large side effects, so this script only presents the steps.
EOF
    exit 0
fi

# --- Preparation for the new-layout conversion (spec 2026-06-04 personal-state-separation Phase 3) ---
#   tasks/active.md → workspaces/<author>/<topic>/tasks.md (topic from the WORKSPACE.md heading)
#   WORKSPACE.md / WORKSPACE-refs.md → excluded (per-checkout local pointers; never stored)
AUTHOR=""
[ -f "$SCRIPT_DIR/_ai-context-paths.sh" ] && AUTHOR=$(sh "$SCRIPT_DIR/_ai-context-paths.sh" --author "$CWD" 2>/dev/null)
TOPIC=""
[ -f "$SRC/WORKSPACE.md" ] && TOPIC=$(grep -m1 '^# Workspace:' "$SRC/WORKSPACE.md" 2>/dev/null | sed 's/^# Workspace:[[:space:]]*//')

# --- copy mode (all files under .ai-context except regenerated artifacts, per-machine, VCS) ---
find "$SRC" -type f \
    ! -path "*/project-index/*" ! -path "*/full-index/*" \
    ! -path "*/sessions-cache/*" ! -path "*/tmp/search/*" \
    ! -path "*/.obsidian/*" ! -path "*/.git/*" \
    ! -name ".DS_Store" ! -name "*-combined.txt" ! -name ".gitignore" 2>/dev/null \
| while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel=${f#"$SRC"/}
    case "$rel" in
        WORKSPACE.md|WORKSPACE-refs.md|DASHBOARD.md)
            echo "  skip (per-checkout local, excluded from migration): $rel"
            continue ;;
        tasks/active.md)
            if [ -n "$AUTHOR" ] && [ -n "$TOPIC" ]; then
                echo "  convert: tasks/active.md → workspaces/$AUTHOR/$TOPIC/tasks.md"
                rel="workspaces/$AUTHOR/$TOPIC/tasks.md"
            fi ;;
    esac
    dst="$DEST/$rel"
    if [ -e "$dst" ]; then
        echo "  skip (already exists): $rel"
    else
        echo "  $([ $APPLY -eq 1 ] && echo copy || echo would-copy): $rel"
        if [ $APPLY -eq 1 ]; then
            mkdir -p "$(dirname "$dst")"
            cp "$f" "$dst"
        fi
    fi
done

echo ""
if [ $APPLY -eq 1 ]; then
    echo "Done. The original $SRC was not deleted (legacy left in place / deletion is a separate user decision = T3.4)."
    echo "Next: the FTS5 section index auto-regenerates on the next decisions/docs write; full-combined.txt (deep-path search) refreshes on SessionStart's daily throttle or on demand at deep-search start → verify with /search."
else
    echo "This was a DRY-RUN. Add --apply to execute."
fi
