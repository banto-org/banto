# Migration / fallback setup / denylist (migrate / denylist)

> First-time setup (the old `init`) is now folded into `bootstrap` (SKILL.md, "store bootstrap").
> Cleanup of empty / already-migrated legacy / mis-generated folders (the old `prune`) is now automated by a hook (the manual subcommand is retired.
> If you need a manual cleanup, follow the `doctor` report). This file covers **migration (`migrate`)** and **fallback setup + denylist**.

<!-- merged from migrate.md -->
## migrate — migrate a project's ai-context into the central store

Copy-migrates the assets of an existing in-repo `.ai-context/` (a legacy project) into the central store (`~/ai-context-store/<project>/`).
The engine is `scripts/migrate-to-store.sh` (copy mode, dry-run by default, never deletes the source `.ai-context/`).

> Note: `.ai-context/` here refers to the **in-repo directory of a legacy repo** (the migration source).
> The destination base is the absolute path on the store side. Under store-first, new generation happens only on the base (store) side; nothing is written to the relative `.ai-context/`.

## Prerequisites

- The central store root (`~/ai-context-store/`, marker `.ai-context-store`) should already have been
  created automatically by the store-first scaffold. If it is missing: `mkdir -p ~/ai-context-store && touch ~/ai-context-store/.ai-context-store`
  (use `scripts/ai-context-store-init.sh` if you sync it with git across a team).
- Register the target cwd → project mapping in `.mapping.json` (`~/ai-context-store/.mapping.json`, local-only / gitignored) (step 1).

## `migrate [path]` (default path = cwd)

1. **Register the mapping**: the project name is decided by derive (a deterministic suffix is appended on a dirname collision):
   `PROJ=$(basename "$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --derive <abs-path>)")`
   → `.mapping.json`'s `.projects[<abs-path>] = {"project": $PROJ}` (added only if not already registered).
2. **dry-run**: check what will be migrated with `sh "$CLAUDE_PLUGIN_ROOT/scripts/migrate-to-store.sh" <path>`.
3. **apply**: `... --apply <path>` (copies the files under the in-repo `.ai-context/` = decisions/docs/tasks/archive/audit/concept etc. + `config.json`. `WORKSPACE.md` / `WORKSPACE-refs.md` / `DASHBOARD.md` (per-checkout local pointers), regenerated artifacts (`*-combined.txt`), `.obsidian/`, `.git/`, and `.DS_Store` are excluded. Existing files are skipped. v5.21.7+).
4. **Search layer**: regenerated automatically by a hook (no manual step needed).
5. **Report**: number of files migrated / store path / the source legacy is retained (its removal is automated by a hook).

## `migrate --all`

Enumerates the projects directly under `~/Documents/productCodes` that have an in-repo `.ai-context/`, and runs `migrate` on each.
**Excluded**: already-migrated / worktrees (a separate checkout of the same repo) / paths registered in the denylist.

### Handling of scope (client / NDA)
`--all` can aggregate and push the knowledge of projects that include other companies' work or NDA-covered material into a shared org store (`<your-org>/ai-context-store`).
This cross-client bulk move is designed to be **blocked by the safety classifier (a deterministic hook)**, and lifting the block requires the user's own `!` execution.
Whether a client project may be migrated (owner approval) is **assumed to be managed out-of-band by the operator**, and **the AI does not re-request approval** (no redundant confirmations). Leaving client projects as legacy is the default and the safe choice.

## Reflecting into the store (push)

After the migration copy, commit + push the store to share it / sync to other machines (optional, separate step):

```
git -C ~/ai-context-store add -A
git -C ~/ai-context-store commit -m "feat: migrate <project> ai-context to central store"
git -C ~/ai-context-store push origin main   # the store allows direct push to main via its marker
```

Search artifacts (`*-combined.txt` etc.), `.mapping.json`, and `[Memo]*` are already excluded by the store's `.gitignore` (the canonical reference for the categories is [`directory-structure.md`](directory-structure.md)).

<!-- merged from setup-and-denylist.md -->
## Fallback setup and denylist management

## Fallback setup (for environments where hooks don't run)

In a CLI environment, hooks (`ai-context-auto.sh` / `ai-context-session-start.sh` / `_ai-context-scaffold.sh`) auto-generate the skeleton on the central store side (or, when not yet registered, on a temporary local `~/ai-context-local/<project>/`) (store-first: no in-repo `.ai-context/` is created). **In Claude Desktop / IDE extensions / the Web UI, hooks do not fire**, so when this skill fires and detects that the base has not been generated, run the following with Bash as a fallback:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/_ai-context-scaffold.sh" "$PWD"
```

`_ai-context-scaffold.sh` writes **only on the store / temporary-local side** (ensures the store root + registers the mapping + generates the project skeleton). It never touches the repo's `.gitignore`. For the standard buckets that are generated, see the store layout in [`directory-structure.md`](directory-structure.md) (not repeated here).

**Verification procedure**: immediately after the skill fires, resolve the base with `BASE=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD")`, check `[ -d "$BASE/decisions" ]`, and run the command above if it is absent. Does nothing if it already exists (idempotent).

## Denylist management (excluding banto itself)

For cases where you **don't want hooks to run** in a particular project (prototypes / someone else's repository / a temporary working directory, etc.), the SessionStart / UserPromptSubmit hooks early-exit on any path (and anything under it) listed in `~/.claude/banto-ignore`.

When the user says something like "don't run ai-context in this project," "suppress the scaffold," or "I want to exclude this," register it via the command:

```
/ai-context ignore add            # exclude the current CWD
/ai-context ignore add <path>     # exclude an arbitrary path
/ai-context ignore list           # list registered entries
/ai-context ignore remove <N>     # remove line number N
```

See `references/ignore.md` for the file spec.

Note: adding to the denylist **only suppresses new store scaffolding for that path (and anything under it), on a per-project basis**. A project dir that was already created on the store / temporary-local side must be deleted manually by the user (not automated, since it is a destructive operation). Nothing is created on the repo side in the first place, so no repo cleanup is needed.

## Firing conditions for auto scaffold (location guard)

Separate from the denylist, `_ai_context_should_skip` **deterministically prevents mis-generation in non-project locations**:

- Auto scaffold runs **only inside a git work tree**. No store / temporary-local project dir is created directly under `$HOME`, at the filesystem root, or in a directory not under git management (so opening a session from HOME does not register a bogus project).
- Scaffold a new non-git project explicitly with `/init` + `harness-setup.sh --project` (the self-driving harness principle: create only when there is explicit intent).
- This guard does not depend on whether the denylist file exists (it is always in effect, even with no file).
