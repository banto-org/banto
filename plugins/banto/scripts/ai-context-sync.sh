#!/bin/sh
# ai-context-sync.sh — pulls (rebase) + commits + pushes the central ai-context store (for hooks and manual use).
#
# Differences from nightly-push.sh:
#   - Picks up not only "commit uncommitted changes" but also "push unpushed (ahead) commits"
#     (nightly-push only acts when the working tree is dirty, missing committed-but-unpushed state).
#   - Takes a single store as an argument (for PreCompact / SessionStart hooks calling after cwd resolution).
#
# Execution paths:
#   Invoked as `sh ai-context-sync.sh <store>` from the PreCompact hook / launchd / cron.
#   Direct pushes to main of a knowledge store are allowed by the marker exception in safety.md
#   (decisions/2026-05-29_005, 2026-05-30_002). This script only targets knowledge stores carrying
#   the `.ai-context-store` marker and never touches code repos (see safety guards below).
#
# Safety guards (misfire prevention; never direct-push a code repo to main):
#   - Push only repos with the `.ai-context-store` marker above the target dir (knowledge stores only)
#   - Push only when the current branch is main/master
#   - With an upstream, EVERY sync pulls (--rebase) to integrate other machines' knowledge;
#     no-op only when there is no upstream and nothing to commit/push
#   - --dry-run shows the content without actually pushing
#
# Usage:
#   sh ai-context-sync.sh <store-root-or-subdir> [--dry-run]
#     Walks upward from <store-root-or-subdir> looking for the marker to determine the store root.
#
# POSIX compatible: macOS / Linux / WSL
set -u

TARGET="${1:-}"
DRY=0
[ "${2:-}" = "--dry-run" ] && DRY=1
[ "${1:-}" = "--dry-run" ] && { DRY=1; TARGET="${2:-}"; }

[ -z "$TARGET" ] && { echo "usage: ai-context-sync.sh <store-root-or-subdir> [--dry-run]" >&2; exit 2; }
[ -d "$TARGET" ] || { echo "[sync] dir does not exist: $TARGET" >&2; exit 2; }

log() { printf '%s\n' "$*"; }

# Walk upward looking for the `.ai-context-store` marker to determine the store root
find_store_root() {
    d=$(cd "$1" 2>/dev/null && pwd) || return 1
    while [ -n "$d" ] && [ "$d" != "/" ]; do
        [ -f "$d/.ai-context-store" ] && { printf '%s' "$d"; return 0; }
        d=$(dirname "$d")
    done
    return 1
}

STORE=$(find_store_root "$TARGET") || {
    log "[skip] marker (.ai-context-store) not found (prevents mistargeting a code repo): $TARGET"
    exit 0
}

[ -d "$STORE/.git" ] || { log "[skip] not a git repo: $STORE"; exit 0; }

branch=$(git -C "$STORE" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
    # Caution: never place $var directly adjacent to full-width brackets in messages
    # (macOS /bin/sh = bash 3.2 in POSIX mode misreads the multibyte boundary and crashes
    # with an unbound variable under set -u — a real bug, proven in 2026-06-05 audit TEST 12a).
    log "[skip] not on main/master (branch=$branch): $STORE"; exit 0
fi

# ---- Serialization lock (when PreCompact + SessionEnd double-register and syncs run in parallel,
# git index/ref locks collide and one side claims "no commit needed" while actually failing the lock.
# Prevents that accident. 2026-06-05 audit TEST 10) ----
GITDIR=$(git -C "$STORE" rev-parse --git-dir 2>/dev/null || echo "$STORE/.git")
case "$GITDIR" in /*) ;; *) GITDIR="$STORE/$GITDIR" ;; esac
LOCKD="$GITDIR/banto-sync.lock.d"
if ! mkdir "$LOCKD" 2>/dev/null; then
    _lk_mtime=$(stat -c %Y "$LOCKD" 2>/dev/null || stat -f %m "$LOCKD" 2>/dev/null || echo 0)
    _lk_age=$(( $(date +%s) - _lk_mtime ))
    if [ "$_lk_age" -lt 300 ]; then
        log "[skip] another sync is running (lock age ${_lk_age}s): $STORE"; exit 0
    fi
    # Take over stale locks older than 5 minutes (crash residue)
    rmdir "$LOCKD" 2>/dev/null
    mkdir "$LOCKD" 2>/dev/null || { log "[skip] failed to acquire lock: $STORE"; exit 0; }
fi
trap 'rmdir "$LOCKD" 2>/dev/null' EXIT INT TERM

# ---- no_sync excludes: per-project {proj}/meta/policy.json の .ignore.no_sync[] を
# store の .git/info/exclude（マーカー区間）へ再生成する。注意: git の exclude は
# 「未追跡ファイル」にのみ効く。既に追跡済みのファイルは対象外（それは人間の判断で rm --cached）。
if command -v jq >/dev/null 2>&1; then
    EXCL="$GITDIR/info/exclude"
    mkdir -p "$GITDIR/info" 2>/dev/null
    TMPX="$EXCL.banto.tmp"
    { [ -f "$EXCL" ] && sed '/^# BANTO-NO-SYNC BEGIN$/,/^# BANTO-NO-SYNC END$/d' "$EXCL"; } > "$TMPX" 2>/dev/null || : > "$TMPX"
    {
        echo "# BANTO-NO-SYNC BEGIN"
        for _pol in "$STORE"/*/meta/policy.json; do
            [ -f "$_pol" ] || continue
            _proj=$(basename "$(dirname "$(dirname "$_pol")")")
            jq -r '.ignore.no_sync[]? // empty' "$_pol" 2>/dev/null | while IFS= read -r _pat; do
                [ -n "$_pat" ] && printf '%s/%s\n' "$_proj" "$_pat"
            done
        done
        echo "# BANTO-NO-SYNC END"
    } >> "$TMPX"
    mv "$TMPX" "$EXCL" 2>/dev/null || rm -f "$TMPX"
fi

# Determine state
DIRTY=0
[ -n "$(git -C "$STORE" status --porcelain 2>/dev/null)" ] && DIRTY=1

AHEAD=0
if git -C "$STORE" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    AHEAD=$(git -C "$STORE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
fi

HAS_UPSTREAM=0
git -C "$STORE" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 && HAS_UPSTREAM=1

if [ "$DIRTY" = "0" ] && [ "$AHEAD" = "0" ] && [ "$HAS_UPSTREAM" = "0" ]; then
    log "[ok] already in sync (no changes / ahead=0 / no upstream): $STORE"; exit 0
fi

TS=$(date '+%Y-%m-%d %H:%M')

if [ "$DRY" = "1" ]; then
    log "[dry-run] $STORE (branch=$branch, dirty=$DIRTY, ahead=$AHEAD)"
    [ "$DIRTY" = "1" ] && git -C "$STORE" status --short | sed 's/^/    to commit: /'
    [ "$AHEAD" != "0" ] && git -C "$STORE" log --oneline '@{u}..HEAD' 2>/dev/null | sed 's/^/    to push: /'
    exit 0
fi

rc=0
# 1) Commit local changes FIRST (protects them in a commit before any rebase;
#    an aborted rebase then restores the tree exactly. Safer than pull-with-autostash).
if [ "$DIRTY" = "1" ]; then
    git -C "$STORE" add -A
    if ! git -C "$STORE" commit -q -m "chore(ai-context): sync $TS"; then
        # The old implementation claimed every commit failure was "no commit needed" (hiding real
        # failures like lock contention behind success logs; 2026-06-05 audit). Only say
        # "not needed" when staged is truly empty.
        if git -C "$STORE" diff --cached --quiet 2>/dev/null; then
            log "[ok] no commit needed: $STORE"
        else
            log "[ERROR] commit failed (lock contention etc.; staged changes retried on next sync): $STORE"
            rc=1
        fi
    fi
fi

# 2) Pull EVERY sync (multi-machine stores: integrate remote knowledge before pushing).
#    --rebase keeps the store history linear; --ff is implied for the behind-only case.
#    On conflict: abort the rebase (local state fully restored) and surface an ERROR —
#    conflict resolution is a human/AI checkpoint, never automated here.
if [ "$HAS_UPSTREAM" = "1" ]; then
    if git -C "$STORE" pull -q --rebase origin "$branch" 2>/dev/null; then
        log "[pulled] $STORE ($branch)"
    else
        git -C "$STORE" rebase --abort >/dev/null 2>&1
        log "[ERROR] pull --rebase failed (conflict or network). Local commits kept; resolve manually: $STORE"
        rc=1
    fi
fi

# 3) Push whatever is ahead after the pull (skip when the pull already failed).
AHEAD=0
if [ "$HAS_UPSTREAM" = "1" ]; then
    AHEAD=$(git -C "$STORE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
fi
if [ "$rc" = "0" ] && [ "$AHEAD" != "0" ]; then
    if git -C "$STORE" push -q origin "$branch"; then
        log "[pushed] $STORE ($branch)"
    else
        log "[ERROR] push failed: $STORE"; rc=1
    fi
elif [ "$rc" = "0" ]; then
    log "[ok] in sync after pull (nothing to push): $STORE"
fi

exit $rc
