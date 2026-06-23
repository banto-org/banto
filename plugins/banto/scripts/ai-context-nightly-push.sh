#!/bin/sh
# ai-context-nightly-push.sh — auto commit + push (direct to main) of central ai-context stores at night.
#
# Knowledge-only stores allow direct pushes to main (push-policy separation from decision 005).
# Zero AI judgment involved (plain commit + push), so run it via cron / launchd / scheduled routine.
#
# Target stores: ~/.claude/banto-ai-context-stores (one store repo path per line, # comments allowed)
#   Example:
#     /Users/me/ai-context-store-personal
#     /Users/me/ai-context-store-org
#
# Safety guards:
#   - Verify each listed path is an "ai-context store" via the marker before pushing
#     (never direct-push a code repo to main by mistake). Marker: .ai-context-store at the repo root
#   - No-op when there are no changes
#   - Push only when the current branch is main (otherwise warn and skip)
#   - --dry-run for inspection only
set -u

STORES_LIST="${BANTO_STORES_LIST:-$HOME/.claude/banto-ai-context-stores}"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

log() { printf '%s\n' "$*"; }

[ -f "$STORES_LIST" ] || { log "[nightly-push] store list not configured: $STORES_LIST (doing nothing)"; exit 0; }

# Stable timestamp (for the commit message)
TS=$(date '+%Y-%m-%d %H:%M')

rc=0
while IFS= read -r line; do
  # skip comments / blank lines
  case "$line" in ''|\#*) continue ;; esac
  store=$(printf '%s' "$line" | sed 's/[[:space:]]*$//')
  [ -n "$store" ] || continue

  if [ ! -d "$store/.git" ]; then
    log "[skip] not a git repo: $store"; continue
  fi
  if [ ! -f "$store/.ai-context-store" ]; then
    log "[skip] no store marker (.ai-context-store) (prevents mistargeting a code repo): $store"; continue
  fi

  branch=$(git -C "$store" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
  if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
    log "[skip] not on main/master (branch=$branch): $store"; continue
  fi

  if git -C "$store" diff --quiet --ignore-submodules HEAD 2>/dev/null && \
     [ -z "$(git -C "$store" status --porcelain)" ]; then
    log "[ok] no changes: $store"; continue
  fi

  if [ "$DRY" = "1" ]; then
    log "[dry-run] commit+push target: $store"
    git -C "$store" status --short | sed 's/^/    /'
    continue
  fi

  git -C "$store" add -A
  if git -C "$store" commit -q -m "chore(ai-context): nightly sync $TS"; then
    if git -C "$store" push -q origin "$branch"; then
      log "[pushed] $store ($branch)"
    else
      log "[ERROR] push failed: $store"; rc=1
    fi
  else
    log "[ok] no commit needed: $store"
  fi
done < "$STORES_LIST"

exit $rc
