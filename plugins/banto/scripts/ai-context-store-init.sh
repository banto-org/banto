#!/bin/sh
# ai-context-store-init.sh — prepares the central store locally (clone or create) + registers it for nightly push.
#
# The target follows config/store-target.conf (bundled constants). In the team distribution this
# constant is locked, so any PC / GitHub account creates and pushes to the same org
# (prevents silently re-pointing where knowledge leaks to).
#
# Usage:
#   sh ai-context-store-init.sh            # clone if the remote exists, otherwise guidance (for members)
#   sh ai-context-store-init.sh --create   # create a private repo if the remote is missing (admin first run)
#
# Design: .ai-context/decisions/2026-05-30_002_ai-context-store-org-locked-target_*.md
set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF="$PLUGIN_ROOT/config/store-target.conf"
[ -f "$CONF" ] || { printf 'Error: constants file not found: %s\n' "$CONF"; exit 1; }
# shellcheck disable=SC1090
. "$CONF"

# user-scope override (survives `claude plugin update` — edits to the plugin-scope conf above
# are reverted on every update for marketplace installs; 2026-06-12 audit H-15).
# Still a deliberate file, not an ambient env var: the locked-value rationale is preserved.
USER_CONF="$HOME/.claude/banto-store-target.conf"
if [ -f "$USER_CONF" ]; then
    # shellcheck disable=SC1090
    . "$USER_CONF"
fi

LOCAL="${AI_CONTEXT_STORE_LOCAL:-$AI_CONTEXT_STORE_LOCAL_DEFAULT}"
if [ -z "${AI_CONTEXT_STORE_ORG:-}" ]; then
    printf 'Error: AI_CONTEXT_STORE_ORG is not set.\n'
    printf '  Persistent (recommended): create %s with a line like\n' "$USER_CONF"
    printf '    AI_CONTEXT_STORE_ORG="your-github-org-or-username"\n'
    printf '  (Editing %s also works but is reverted by `claude plugin update`.\n' "$CONF"
    printf '   Deliberately no env override — the locked value prevents silently re-pointing\n'
    printf '   where team knowledge gets pushed. Local-only store works without it.)\n'
    exit 1
fi
REMOTE="$AI_CONTEXT_STORE_ORG/$AI_CONTEXT_STORE_REPO"
STORES_LIST="${BANTO_STORES_LIST:-$HOME/.claude/banto-ai-context-stores}"
DO_CREATE=0
[ "${1:-}" = "--create" ] && DO_CREATE=1

command -v git >/dev/null 2>&1 || { printf 'Error: git is required\n'; exit 1; }
command -v gh  >/dev/null 2>&1 || { printf 'Error: gh CLI is required (brew install gh)\n'; exit 1; }

printf 'Target remote : %s\n' "$REMOTE"
printf 'Local clone   : %s\n\n' "$LOCAL"

# 1. Prepare the local clone
if [ -d "$LOCAL/.git" ]; then
    printf '✓ already exists locally: %s\n' "$LOCAL"
elif gh repo view "$REMOTE" >/dev/null 2>&1; then
    printf 'remote exists → cloning...\n'
    git clone "https://github.com/$REMOTE.git" "$LOCAL" || { printf 'Error: clone failed\n'; exit 1; }
elif [ "$DO_CREATE" = "1" ]; then
    printf 'remote missing → creating a private repo (--create)...\n'
    gh repo create "$REMOTE" --private --description "banto central ai-context store (must stay private)" || { printf 'Error: creation failed\n'; exit 1; }
    if ! git clone "https://github.com/$REMOTE.git" "$LOCAL" 2>/dev/null; then
        mkdir -p "$LOCAL"
        ( cd "$LOCAL" && git init -q && git remote add origin "https://github.com/$REMOTE.git" )
    fi
else
    printf 'Error: remote %s does not exist.\n' "$REMOTE"
    printf '  Ask an admin to create it, or run with --create if this is the first setup.\n'
    exit 1
fi

# 2. Guarantee structure + marker (.ai-context-store prevents misfiring on code repos)
#    Layout is per-project (decisions/2026-05-30_003 + design-discussion memo §4.2).
#    Project knowledge is isolated under <store>/<project>/. The resolver digs the project
#    dir on first write, so init does not create it. Only marker / README / _shared here.
cd "$LOCAL" || { printf 'Error: cannot enter %s\n' "$LOCAL"; exit 1; }
touch .ai-context-store
# _shared: cross-project shared knowledge (decisions / docs not belonging to a specific project)
for d in _shared/decisions _shared/docs; do
    mkdir -p "$d"
    [ -e "$d/.gitkeep" ] || touch "$d/.gitkeep"
done
# M1 (decisions/2026-05-30_003): manage the store's ignores centrally in the root .gitignore.
#   No per-project .gitignore (flatten layout: under <project>/sessions/ the .ai-context/
#   prefix would become dead config). Trailing-slash patterns match at any depth = effective
#   under every project dir. .mapping.json stays local to each PC (never committed to the store).
ensure_ignore() {
    [ -f .gitignore ] || : > .gitignore
    for _pat in "$@"; do
        grep -qxF "$_pat" .gitignore || printf '%s\n' "$_pat" >> .gitignore
    done
}
ensure_ignore '.mapping.json' \
    'project-index/' 'full-index/' '*-combined.txt' \
    'sessions-cache/' 'tmp/' \
    'sessions/' 'drafts/' \
    '.obsidian/' '.DS_Store' '\[Memo\]*' \
    'WORKSPACE.md' 'WORKSPACE-refs.md' 'DASHBOARD.md'
[ -f README.md ] || cat > README.md <<'MD'
# ai-context store

banto's central knowledge store. **Must stay private** (contains internal names and cross-project knowledge).

## Layout (per-project)

```
<store>/
├── .ai-context-store      … marker preventing misfires on code repos (required at the root)
├── .mapping.json          … cwd → project resolution table
├── _shared/               … cross-project shared knowledge
│   └── {decisions,docs}/
└── <project>/             … isolated per project (auto-created on first write)
    └── {decisions,docs,tasks,workspaces}/
```

Each project's knowledge is separated under `<project>/` (inter-project information isolation = decisions/2026-05-30_001).
`<project>/` is created by the resolver on first write, so it does not appear in an empty store.
MD

# 3. Initial commit + push (knowledge stores allow direct pushes to main: the kill-switch recognizes the marker)
if [ -n "$(git status --porcelain)" ]; then
    git add -A
    git commit -q -m "chore(ai-context-store): init structure + marker" || true
    git branch -M main 2>/dev/null || true
    if git push -u origin main; then
        printf '✓ push done\n'
    else
        printf '⚠ push incomplete. Manually: git -C "%s" push -u origin main\n' "$LOCAL"
    fi
fi

# 3.5 Auto-generate .mapping.json from the template (first setup on a new machine / new member)
#     The template is remotes-based (auto-connects by matching the project's git remote), so
#     clones of each repo connect to central without writing machine-specific paths
#     (the resolver's remote fallback = v5.21.22).
if [ -f "$LOCAL/.mapping-template.json" ] && [ ! -f "$LOCAL/.mapping.json" ]; then
    cp "$LOCAL/.mapping-template.json" "$LOCAL/.mapping.json"
    printf '✓ generated .mapping.json from the template (remotes-based, no path registration needed)\n'
elif [ -f "$LOCAL/.mapping.json" ]; then
    printf '✓ .mapping.json already exists (apply template diffs manually as needed)\n'
fi

# 4. Register for nightly push
mkdir -p "$(dirname "$STORES_LIST")"
if ! grep -qxF "$LOCAL" "$STORES_LIST" 2>/dev/null; then
    printf '%s\n' "$LOCAL" >> "$STORES_LIST"
    printf '✓ registered for nightly push: %s\n' "$STORES_LIST"
fi

printf '\nDone. store = %s (%s)\n' "$LOCAL" "$REMOTE"
printf 'Next: to enable nightly push, install the launchd plist (see templates/ci/*.plist.example)\n'
