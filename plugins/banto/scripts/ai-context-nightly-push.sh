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

  DIRTY=0
  [ -n "$(git -C "$store" status --porcelain)" ] && DIRTY=1

  if [ "$DRY" = "1" ]; then
    log "[dry-run] pull+commit+push target (dirty=$DIRTY): $store"
    git -C "$store" status --short | sed 's/^/    /'
    continue
  fi

  # commit local first → pull --rebase (every run; multi-machine stores) → push
  if [ "$DIRTY" = "1" ]; then
    git -C "$store" add -A
    git -C "$store" commit -q -m "chore(ai-context): nightly sync $TS" || log "[warn] commit failed: $store"
  fi

  if git -C "$store" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    if ! git -C "$store" pull -q --rebase origin "$branch" 2>/dev/null; then
      git -C "$store" rebase --abort >/dev/null 2>&1
      log "[ERROR] pull --rebase failed (conflict or network); resolve manually: $store"; rc=1; continue
    fi
    ahead=$(git -C "$store" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  else
    ahead=1   # no upstream info; attempt the push and let git decide
  fi

  if [ "$ahead" != "0" ]; then
    if git -C "$store" push -q origin "$branch"; then
      log "[pushed] $store ($branch)"
    else
      log "[ERROR] push failed: $store"; rc=1
    fi
  else
    log "[ok] in sync after pull (nothing to push): $store"
  fi
done < "$STORES_LIST"

exit $rc
