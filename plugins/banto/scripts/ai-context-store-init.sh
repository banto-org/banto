#!/bin/sh
# ai-context-store-init.sh — prepares the central store locally (clone or create) + registers it for nightly push.
#
# The target follows config/store-target.conf (bundled constants). In the team distribution this
# constant is locked, so any PC / GitHub account creates and pushes to the same org
# (prevents silently re-pointing where knowledge leaks to).
#
# Usage:
#   sh ai-context-store-init.sh                    # clone if the remote exists, otherwise guidance (for members)
#   sh ai-context-store-init.sh --create [<org>]   # create a private repo if the remote is missing (admin first run)
#   sh ai-context-store-init.sh --register <org/name>  # register an EXISTING repo (clone + map, never create) (A4)
#   sh ai-context-store-init.sh --org <org>        # remember <org> only (saved to the user-scope conf) (A3)
#
#   # ai-context-subsystem-redesign (spec 2026-06-24) — non-blocking local store + later GitHub backing:
#   sh ai-context-store-init.sh bootstrap [<org/name>|<org>] [--cwd <dir>]
#       # back this repo with a GitHub central store: register an existing <org/name>, or create one in
#       # <org> (persisted to ~/.claude/banto-store-target.conf), then MIGRATE ~/ai-context-local/<project>
#       # into the central store (additive rsync; never overwrites — conflicts are reported and skipped,
#       # leaving both copies). With no arg, falls back to the persisted/bundled org. Idempotent.
#   sh ai-context-store-init.sh local [--cwd <dir>]
#       # pin this repo local-only (local store mapping local:true). Skips bootstrap/migration forever.
#
# A bare <org> argument (or --create <org> / --org <org>) is SAVED to the user-scope conf
# ~/.claude/banto-store-target.conf so later projects reuse it and only confirm creation (A3).
# The bundled config/store-target.conf stays the fallback default.
#
# Design: .ai-context/decisions/2026-05-30_002_ai-context-store-org-locked-target_*.md
#         docs/specs/2026-06-24_ai-context-subsystem-redesign_spec.md (bootstrap / local / migration)
set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF="$PLUGIN_ROOT/config/store-target.conf"
[ -f "$CONF" ] || { printf 'Error: constants file not found: %s\n' "$CONF"; exit 1; }
# shellcheck disable=SC1090
. "$CONF"

# paths helper provides local-store roots / derive / lookups (spec 2026-06-24).
AI_PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
# shellcheck disable=SC1090
[ -f "$AI_PATHS" ] && . "$AI_PATHS"

# Resolve the git toplevel of <dir> (or $PWD). Echoes nothing outside git.
_aci_toplevel() { # [dir]
    command -v git >/dev/null 2>&1 || return 1
    git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null
}

# user-scope override (survives `claude plugin update` — edits to the plugin-scope conf above
# are reverted on every update for marketplace installs; 2026-06-12 audit H-15).
# Still a deliberate file, not an ambient env var: the locked-value rationale is preserved.
USER_CONF="$HOME/.claude/banto-store-target.conf"
if [ -f "$USER_CONF" ]; then
    # shellcheck disable=SC1090
    . "$USER_CONF"
fi

LOCAL="${AI_CONTEXT_STORE_LOCAL:-$AI_CONTEXT_STORE_LOCAL_DEFAULT}"

# === spec 2026-06-24 subcommands: local / bootstrap ========================
# These take a different argument shape ([<org>] [--cwd <dir>]) than the legacy flags,
# so parse them up front and translate into the legacy flow (bootstrap) or exit (local).
DO_MIGRATE=0
SUBCMD=""
BOOT_ORG_ARG=""
BOOT_CWD="$PWD"
case "${1:-}" in
    local|bootstrap)
        SUBCMD="$1"; shift
        # remaining args: optional <org/name>|<org>, optional --cwd <dir>
        while [ $# -gt 0 ]; do
            case "$1" in
                --cwd) BOOT_CWD="${2:-$PWD}"; shift 2 || shift ;;
                -*)    printf 'Error: unknown option for %s: %s\n' "$SUBCMD" "$1"; exit 1 ;;
                *)     BOOT_ORG_ARG="$1"; shift ;;
            esac
        done
        ;;
esac

# Migrate ~/ai-context-local/<project> → central store/<project>. Additive only: NEVER overwrite.
# Conflicting files (already present in dest) are reported and left in BOTH places (manual merge).
# rsync --ignore-existing is the primary path; cp -n is the POSIX fallback. Returns 0 always.
_aci_migrate_local() { # src_dir dest_dir
    _aml_src="$1"; _aml_dest="$2"
    [ -d "$_aml_src" ] || { printf 'No local store to migrate (%s absent) — nothing to do.\n' "$_aml_src"; return 0; }
    mkdir -p "$_aml_dest" 2>/dev/null
    # Report conflicts (files present in both) up front so the user can merge them by hand.
    _aml_conflicts=0
    while IFS= read -r _aml_f; do
        [ -n "$_aml_f" ] || continue
        _aml_rel="${_aml_f#"$_aml_src"/}"
        if [ -e "$_aml_dest/$_aml_rel" ]; then
            [ "$_aml_conflicts" = "0" ] && printf '⚠ conflicts — these exist in the central store already; left in BOTH (merge manually):\n'
            printf '    %s\n' "$_aml_rel"
            _aml_conflicts=$((_aml_conflicts + 1))
        fi
    done <<MIGRATE_CONFLICT_SCAN
$(find "$_aml_src" -type f 2>/dev/null)
MIGRATE_CONFLICT_SCAN
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --ignore-existing "$_aml_src"/ "$_aml_dest"/ 2>/dev/null
    else
        # cp -n = no-clobber (BSD + GNU). Recreate the tree, then copy non-existing files.
        ( cd "$_aml_src" 2>/dev/null || exit 0
          find . -type d -exec mkdir -p "$_aml_dest/{}" \; 2>/dev/null
          find . -type f | while IFS= read -r _cf; do
              cp -n "$_cf" "$_aml_dest/$_cf" 2>/dev/null
          done )
    fi
    if [ "$_aml_conflicts" = "0" ]; then
        printf '✓ migrated local store → central (additive): %s → %s\n' "$_aml_src" "$_aml_dest"
    else
        printf '✓ migrated non-conflicting files; %s conflict(s) left in both (source kept at %s)\n' "$_aml_conflicts" "$_aml_src"
    fi
    return 0
}

# `local`: pin this repo local-only (local store mapping local:true). Skip bootstrap/migration.
if [ "$SUBCMD" = "local" ]; then
    command -v jq >/dev/null 2>&1 || { printf 'Error: jq is required\n'; exit 1; }
    command -v _ai_context_local_mapping >/dev/null 2>&1 \
        || { printf 'Error: paths helper not found (%s)\n' "$AI_PATHS"; exit 1; }
    _ltop=$(_aci_toplevel "$BOOT_CWD")
    [ -z "$_ltop" ] && { printf 'Error: not inside a git repo (%s)\n' "$BOOT_CWD"; exit 1; }
    _lroot=$(_ai_context_local_root)
    _lmap=$(_ai_context_local_mapping)
    mkdir -p "$_lroot" 2>/dev/null
    [ -f "$_lroot/.ai-context-local" ] || touch "$_lroot/.ai-context-local" 2>/dev/null
    if [ ! -f "$_lmap" ]; then
        printf '{\n  "version": 2,\n  "store_root": "%s",\n  "projects": {}\n}\n' "$_lroot" > "$_lmap"
    fi
    # derive a project slug if the repo is not registered yet (so `local` works before any session).
    _lproj=$(jq -r --arg top "$_ltop" '.projects[$top].project // empty' "$_lmap" 2>/dev/null)
    if [ -z "$_lproj" ]; then
        _lproj=$(AI_CONTEXT_STORE_ROOT="$_lroot" AI_CONTEXT_MAPPING="$_lmap" _ai_context_derive_dir "$_ltop")
        _lproj=$(basename "$_lproj")
    fi
    if jq --arg top "$_ltop" --arg p "$_lproj" \
          '.projects[$top] = ((.projects[$top] // {}) + {"project": $p, "local": true})' \
          "$_lmap" > "$_lmap.tmp" 2>/dev/null; then
        mv "$_lmap.tmp" "$_lmap"
    else
        rm -f "$_lmap.tmp" 2>/dev/null
        printf 'Error: failed to update local mapping (%s)\n' "$_lmap"; exit 1
    fi
    mkdir -p "$_lroot/$_lproj" 2>/dev/null
    printf '✓ pinned local-only: %s → %s (local:true; bootstrap/migration will skip it)\n' "$_ltop" "$_lroot/$_lproj"
    exit 0
fi

# `bootstrap`: translate into the legacy create/register flow + enable migration at the end.
if [ "$SUBCMD" = "bootstrap" ]; then
    command -v jq >/dev/null 2>&1 || { printf 'Error: jq is required\n'; exit 1; }
    # local-pinned repos must not be auto-sent to GitHub (spec Never).
    if command -v _ai_context_is_local_pinned >/dev/null 2>&1; then
        _btop=$(_aci_toplevel "$BOOT_CWD")
        if [ -n "$_btop" ] && _ai_context_is_local_pinned "$_btop"; then
            printf 'This repo is pinned local-only (local:true). bootstrap is a no-op.\n'
            printf '  Unpin by editing %s if you really want to back it with GitHub.\n' "$(_ai_context_local_mapping)"
            exit 0
        fi
    fi
    DO_MIGRATE=1
    # An <org/name> arg → register an existing repo; a bare <org> → create in that org.
    case "$BOOT_ORG_ARG" in
        */*) set -- --register "$BOOT_ORG_ARG" ;;
        ?*)  set -- --create "$BOOT_ORG_ARG" ;;
        *)   set -- --create ;;   # no arg → create with the persisted/bundled org
    esac
fi

# --- argument parsing -------------------------------------------------------
# Modes:
#   --create [<org>]       create a private repo if the remote is missing
#   --register <org/name>  register an EXISTING repo (clone + map), never create (A4)
#   --org <org>            persist <org> to the user-scope conf only (A3) and exit
#   <org>                  bare org → persist it (A3), then proceed like the default clone path
DO_CREATE=0
DO_REGISTER=0
REGISTER_REPO=""
ARG_ORG=""
case "${1:-}" in
    --create)   DO_CREATE=1; ARG_ORG="${2:-}" ;;
    --register) DO_REGISTER=1; REGISTER_REPO="${2:-}"
                [ -z "$REGISTER_REPO" ] && { printf 'Error: --register requires <org/name>\n'; exit 1; } ;;
    --org)      ARG_ORG="${2:-}"
                [ -z "$ARG_ORG" ] && { printf 'Error: --org requires <org>\n'; exit 1; } ;;
    "")         : ;;
    -*)         printf 'Error: unknown option: %s\n' "$1"; exit 1 ;;
    *)          ARG_ORG="$1" ;;
esac

# A3: remember the chosen org in the user-scope conf so later projects reuse it.
# --register implies an org from the repo path; a bare/--create/--org arg is the explicit org.
persist_org() { # org
    [ -z "$1" ] && return 0
    mkdir -p "$(dirname "$USER_CONF")" 2>/dev/null
    if [ -f "$USER_CONF" ] && grep -q '^AI_CONTEXT_STORE_ORG=' "$USER_CONF" 2>/dev/null; then
        # replace the existing line in place (portable: rewrite via a temp file)
        _po_tmp="$USER_CONF.tmp.$$"
        sed "s|^AI_CONTEXT_STORE_ORG=.*|AI_CONTEXT_STORE_ORG=\"$1\"|" "$USER_CONF" > "$_po_tmp" 2>/dev/null \
            && mv "$_po_tmp" "$USER_CONF" || rm -f "$_po_tmp" 2>/dev/null
    else
        printf 'AI_CONTEXT_STORE_ORG="%s"\n' "$1" >> "$USER_CONF"
    fi
    AI_CONTEXT_STORE_ORG="$1"
    printf '✓ remembered org → %s (%s)\n' "$1" "$USER_CONF"
}

if [ -n "$ARG_ORG" ]; then
    persist_org "$ARG_ORG"
fi

# --register: derive org/repo from the given org/name, persist the org, register only.
if [ "$DO_REGISTER" = "1" ]; then
    REG_ORG="${REGISTER_REPO%%/*}"
    REG_REPO="${REGISTER_REPO#*/}"
    if [ -z "$REG_ORG" ] || [ -z "$REG_REPO" ] || [ "$REG_ORG" = "$REGISTER_REPO" ]; then
        printf 'Error: --register expects <org/name> (e.g. my-org/ai-context-store)\n'; exit 1
    fi
    persist_org "$REG_ORG"
    AI_CONTEXT_STORE_REPO="$REG_REPO"
fi

# --org alone: persist and exit (no clone/create).
if [ -n "$ARG_ORG" ] && [ "${1:-}" = "--org" ]; then
    printf '\nDone. org saved. Re-run with --create or --register, or just start a session to bootstrap.\n'
    exit 0
fi

if [ -z "${AI_CONTEXT_STORE_ORG:-}" ]; then
    printf 'Error: AI_CONTEXT_STORE_ORG is not set.\n'
    printf '  Persistent (recommended): pass the org once — it is saved to %s:\n' "$USER_CONF"
    printf '    sh ai-context-store-init.sh --org <your-github-org-or-username>\n'
    printf '  (Editing %s also works but is reverted by `claude plugin update`.\n' "$CONF"
    printf '   Deliberately no env override — the locked value prevents silently re-pointing\n'
    printf '   where team knowledge gets pushed. Local-only store works without it.)\n'
    exit 1
fi
REMOTE="$AI_CONTEXT_STORE_ORG/$AI_CONTEXT_STORE_REPO"
STORES_LIST="${BANTO_STORES_LIST:-$HOME/.claude/banto-ai-context-stores}"

command -v git >/dev/null 2>&1 || { printf 'Error: git is required\n'; exit 1; }
command -v gh  >/dev/null 2>&1 || { printf 'Error: gh CLI is required (brew install gh)\n'; exit 1; }

printf 'Target remote : %s\n' "$REMOTE"
printf 'Local clone   : %s\n\n' "$LOCAL"

# 1. Prepare the local clone
if [ -d "$LOCAL/.git" ]; then
    printf '✓ already exists locally: %s\n' "$LOCAL"
elif gh repo view "$REMOTE" >/dev/null 2>&1; then
    # remote exists → clone it (this is also the --register path: register an existing repo, A4)
    printf 'remote exists → cloning...\n'
    git clone "https://github.com/$REMOTE.git" "$LOCAL" || { printf 'Error: clone failed\n'; exit 1; }
elif [ "$DO_REGISTER" = "1" ]; then
    # --register requires the repo to already exist; never create it (A4).
    printf 'Error: --register target %s does not exist (register only clones an existing repo).\n' "$REMOTE"
    printf '  Create it first (--create), or fix the org/name.\n'
    exit 1
elif [ "$DO_CREATE" = "1" ]; then
    printf 'remote missing → creating a private repo (--create)...\n'
    gh repo create "$REMOTE" --private --description "banto central ai-context store (must stay private)" || { printf 'Error: creation failed\n'; exit 1; }
    if ! git clone "https://github.com/$REMOTE.git" "$LOCAL" 2>/dev/null; then
        mkdir -p "$LOCAL"
        ( cd "$LOCAL" && git init -q && git remote add origin "https://github.com/$REMOTE.git" )
    fi
else
    printf 'Error: remote %s does not exist.\n' "$REMOTE"
    printf '  Ask an admin to create it, run with --create if this is the first setup,\n'
    printf '  or run with --register <org/name> to register an existing store repo.\n'
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

# 5. bootstrap migration (spec 2026-06-24): move ~/ai-context-local/<project> into the central store,
#    register the repo in the central mapping, and drop its entry from the local mapping.
if [ "$DO_MIGRATE" = "1" ] && command -v _ai_context_local_root >/dev/null 2>&1; then
    B_TOP=$(_aci_toplevel "$BOOT_CWD")
    if [ -n "$B_TOP" ]; then
        L_ROOT=$(_ai_context_local_root)
        L_MAP=$(_ai_context_local_mapping)
        C_MAP="${AI_CONTEXT_MAPPING:-$LOCAL/.mapping.json}"
        # derive the central project slug for this repo (deterministic, collision-safe)
        if command -v _ai_context_derive_dir >/dev/null 2>&1; then
            C_DIR=$(AI_CONTEXT_STORE_ROOT="$LOCAL" AI_CONTEXT_MAPPING="$C_MAP" _ai_context_derive_dir "$B_TOP")
        else
            C_DIR="$LOCAL/$(basename "$B_TOP")"
        fi
        C_PROJ=$(basename "$C_DIR")
        # local project slug (where the temp store lives), if registered locally
        L_PROJ=""
        [ -f "$L_MAP" ] && L_PROJ=$(jq -r --arg top "$B_TOP" '.projects[$top].project // empty' "$L_MAP" 2>/dev/null)
        if [ -n "$L_PROJ" ] && [ -d "$L_ROOT/$L_PROJ" ]; then
            _aci_migrate_local "$L_ROOT/$L_PROJ" "$C_DIR"
        else
            printf 'No local store registered for this repo — central store ready, nothing to migrate.\n'
        fi
        # register in the central mapping (path-based; remotes still auto-connect clones elsewhere).
        # Create the mapping if it does not exist yet (.mapping.json is per-PC, never committed).
        if [ ! -f "$C_MAP" ]; then
            printf '{\n  "version": 2,\n  "store_root": "%s",\n  "projects": {}\n}\n' "$LOCAL" > "$C_MAP" 2>/dev/null
        fi
        if [ -f "$C_MAP" ]; then
            if jq --arg top "$B_TOP" --arg p "$C_PROJ" \
                  '.projects[$top] = ((.projects[$top] // {}) + {"project": $p, "local": false})' \
                  "$C_MAP" > "$C_MAP.tmp" 2>/dev/null; then
                mv "$C_MAP.tmp" "$C_MAP"
                printf '✓ registered in the central mapping: %s → %s\n' "$B_TOP" "$C_DIR"
            else
                rm -f "$C_MAP.tmp" 2>/dev/null
            fi
        fi
        # drop the local mapping entry so the resolver now points at the central store
        if [ -n "$L_PROJ" ] && [ -f "$L_MAP" ]; then
            if jq --arg top "$B_TOP" 'del(.projects[$top])' "$L_MAP" > "$L_MAP.tmp" 2>/dev/null; then
                mv "$L_MAP.tmp" "$L_MAP"
                printf '✓ removed the local mapping entry (now backed by the central store)\n'
            else
                rm -f "$L_MAP.tmp" 2>/dev/null
            fi
        fi
    fi
fi

printf '\nDone. store = %s (%s)\n' "$LOCAL" "$REMOTE"
printf 'Next: to enable nightly push, install the launchd plist (see templates/ci/*.plist.example)\n'
