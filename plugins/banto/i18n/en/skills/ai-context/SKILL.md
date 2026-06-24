---
name: ai-context
description: |
  AI context management: decision logs / checkpoints / editing the task file (tasks.md) + next-task navigation + Phase completion / document routing / scaffold-suppression management. Internal search is owned by the `search` skill.
  Triggers: "decision", "design choice", "save this", "checkpoint", "compact", "clear", "task", "TODO", "Phase", "continue", "next task", "carry on", "tidy up the docs", "it's a mess", "exclude", "leave it alone", "disable".
  Do not use for: searching context that's already stored (use the `search` skill) or investigating external sources (use `research`). During implementation a bare "do it" / "go ahead" means self-driving (act directly); only task-qualified phrases ("next task", "carry on") route to next-task navigation. Switching git worktrees / branches for scope is `ws`, not this skill.
allowed-tools: Read Write Edit Glob Grep Bash Agent
argument-hint: "[bootstrap|init|status|doctor|sort|next|phase-done|ignore|tasks|migrate|prune]"
compatibility: Claude Code (requires bash, git, jq)
---

# AI Context

> **About the storage base (store-first)**: every `.ai-context/...` path in this skill refers to the **ai-context base directory** —
> the absolute path the SessionStart / PreCompact hook injects as "ai-context base: &lt;absolute path&gt;". Always
> Read/Write **under that injected absolute path**, and never write to a relative `.ai-context/` (an in-repo `.ai-context/` exists only in
> grandfathered legacy repos, where it keeps working as the base until you migrate it with `/ai-context migrate`).
> If the base is unknown, resolve it in one line: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`.

> **Output language**: write the artifacts you generate (decision logs / tasks.md / checkpoints / status reports, etc.) in the user's conversation language. The Japanese templates under `references/` are only structural scaffolds — translate the headings/labels to match the conversation language.

## Subcommand router (explicit user invocation)

Interpret the first token of `$ARGUMENTS` as the subcommand, Read the corresponding references/ file, and follow its procedure.

| Subcommand | Role | Details |
|---|---|---|
| `bootstrap` | Interactive setup when the store isn't set up (register existing / create new / local-only) | "Store bootstrap" below |
| `init` | Create from scratch (first-time setup) | `references/setup.md` |
| `status` | Show what exists (no writes) | `references/status.md` |
| `doctor` | Detect corruption / misplacement (no writes) | `references/doctor.md` |
| `sort` | Interactively route misplaced files inside `.ai-context/` (writes) | `references/sort.md` |
| `sort project` | Organize scattered docs across the whole project | `references/sort.md` |
| `next` | Identify the next unfinished task and carry it through to implementation | `references/task-lifecycle.md` |
| `phase-done [N]` | Phase completion check + verification + archive | `references/task-lifecycle.md` |
| `ignore` | Manage scaffold-suppression paths (writes) | `references/ignore.md` |
| `tasks split` | Split tasks.md by Phase | `references/task-lifecycle.md` |
| `migrate [path\|--all]` | Migrate a project's ai-context to the central store | `references/setup.md` |
| `prune` | Detect empty / already-migrated legacy / mis-generated folders and delete on confirmation | `references/setup.md` |

If the argument is empty or unknown, show usage.

**Firing from natural language**: beyond explicit subcommands, auto-route from context: "continue", "next", "next task", "go ahead" → `next`; "organize the docs", "it's a mess" → `sort project`; "phase done" → `phase-done`; when the SessionStart hook shows the "store not set up" notice, or "create a store" / "set up ai-context-store" → `bootstrap`.

**Central store operation (teams / multiple projects)**: the end-to-end procedure for consolidating ai-context from an in-repo `.ai-context/` into `~/ai-context-store/<project>/` (setup → migrate `migrate` → reference → push → tear down `prune`) lives in [`references/central-store-guide.md`](references/central-store-guide.md).

## Store bootstrap (`bootstrap`)

When this repo isn't registered with a central ai-context-store, the SessionStart hook shows the "store not set up" notice exactly once (it never silently creates a local store). The hook can't hold a conversation, so run the actual setup dialogue here. Confirm **the three options in a single conversation** (no modals — ask one at a time in plain prose):

1. **If you already have an ai-context-store on GitHub**: confirm the repo as `org/name` → take it in via register-existing mode (don't create):
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" --register <org>/<name>
   ```
   This only clones + registers the mapping, and saves the org to `~/.claude/banto-store-target.conf`.
2. **If you don't have one and want to create it**: confirm which org (or GitHub username) it goes under → create it as private (fixed):
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" --create <org>
   ```
   This creates it with `gh repo create --private` and saves the chosen org to `~/.claude/banto-store-target.conf`. From the second project onward the org is already saved, so you only need to confirm whether to create (no need to re-enter the org).
3. **If you want to use it local-only (a fallback that doesn't use GitHub)**: prepare just the store root and mapping locally and register this repo. **Run it with the explicit opt-in env** (by default nothing is created silently):
   ```bash
   BANTO_BOOTSTRAP_LOCAL=1 sh "$CLAUDE_PLUGIN_ROOT/hooks/_ai-context-scaffold.sh" "$PWD"
   ```
   Once registered, the store base is injected from the next SessionStart on (the marker `~/.claude/banto-bootstrap-asked/<slug>` keeps the `bootstrap` notice from showing again).

In any branch, once registration is done, "ai-context base: &lt;absolute path&gt;" is injected from the next SessionStart on, and you can write decisions / docs / tasks to the store side. To only save the org, use `--org <org>`; to move an existing in-repo `.ai-context/` into the store, use `migrate` rather than `bootstrap` (read compatibility is preserved, so there's no rush).

## Saving decisions (auto-save / format / secrets)

Details: [`references/decisions.md`](references/decisions.md)

- **When**: the moment a design choice happens (don't wait for a commit). Save = design direction / technology selection / architecture change / trade-off / root cause. Don't save = simple implementation / typo / a plain factual answer.
- **Where**: `.ai-context/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md` (a PreToolUse hook injects the suggested name; the old `YYYY-MM-DD_NNN_` format still works too).
- **Format**: lightweight (title + decision) / full (starting point / options / deciding factor / why-not / **friction** / **lessons learned**). Friction and lessons are the core of organizational learning.
- **Secrets** (iron rule): never write `sk-*` / `ghp_*` / `Bearer *` / `.env` values into decisions / checkpoints → replace with `{SECRET}`. On exposure, **revoke / rotate** immediately (it stays in chat history).

## Directory structure / prefixes

Details: [`references/directory-structure.md`](references/directory-structure.md)

Main buckets:
- `decisions/` design-choice logs / `docs/` report-style documents (prefix required) / `workspaces/<author>/<topic>/tasks.md` (new layout; legacy is `tasks/active.md`) / `sessions/`
- Prefixes directly under `docs/`: `[Review]` `[QA]` `[Audit]` `[Status]` `[Design]` `[Guide]` `[Memo]` `[Index]` (enforced by a hook; don't invent new prefixes on your own)

## Task management rules

| Purpose | Tool |
|------|-------|
| Tracking work within a session | `TaskCreate` `TaskUpdate` (Claude Code built-in) |
| Persistent project tasks | The effective tasks file (the path under the "Tasks in progress" heading at SessionStart; new layout = `workspaces/<author>/<topic>/tasks.md`, legacy = `tasks/active.md`) |

**Task file priority:**
1. An existing `tasks.md` / `TODO.md` / `ROADMAP.md` exists → use it
2. None → create the effective tasks file (use the new-layout `tasks.md` if present, otherwise `tasks/active.md`)

**Non-standard task files**: the hook presents them as information only. Move it only when the user explicitly says "move it".

### Auto-archive when all tasks are done

Details: [`references/task-lifecycle.md`](references/task-lifecycle.md)

In short: when the hook detects that every task in the effective tasks file is complete (`- [ ]` is 0 + `- [x]` is 1 or more) → it shelves the file as `YYYY-MM-DD_{phase}.md` (new layout = `tasks-old/` in the same WS, legacy = `tasks/old/`; follow the path in the hook notice; the name is extracted from the `## Phase:` header). It doesn't archive when an existing `tasks.md` / `TODO.md` is in use.

## First-time setup / denylist management

Details: [`references/setup.md`](references/setup.md)

In short:
- **fallback**: in environments without hooks (Claude Desktop / IDE extensions / Web UI), generate `.ai-context/` idempotently with `bash "${CLAUDE_PLUGIN_ROOT}/hooks/_ai-context-scaffold.sh"`
- **denylist**: for paths registered in `~/.claude/banto-ignore`, the hook exits early. Manage them with `/ai-context ignore add/list/remove`

## Searching past context

**Search is owned by the `search` skill**. When the user says things like "we decided this before" / "remember...", that skill fires automatically. You can also call it explicitly with `/search <query>`. Claude expands the query into 3 tiers → a ranking script scores candidates with grep → the top hits are verified by Read (targets: decisions/docs under `.ai-context/` + `extra_docs_dirs` in `config.json`).

## Managing the search text layer (combined.txt)

`combined.txt`, the grep target for search, **is regenerated automatically by a hook (`ai-context-combined-rebuild.sh`) on save**:
- on writes to `.ai-context/decisions/`
- on writes to `.ai-context/docs/`
- runs in the background (debounced)

No manual action needed. To add search targets, edit `extra_docs_dirs` in `config.json` directly; it takes effect from the next hook regeneration.

## Creating checkpoints

Follow the **`save-checkpoint` skill (the `/save-checkpoint` command)** — it is the single source of truth. When the hook notifies "create a checkpoint", run it the same way, via that skill's procedure.

- Checkpoint file: `.ai-context/sessions/checkpoint-{YYYY-MM-DD}-{HHMM}.md`
- The PreCompact hook auto-deletes it after injecting it into the next session, so the AI doesn't need to delete it

## Help when called with no arguments

```
Usage: /ai-context <bootstrap|init|status|doctor|sort|next|phase-done|ignore|tasks|migrate|prune>

Examples:
  /ai-context bootstrap
  /ai-context init
  /ai-context tasks split --auto
```

If the user speaks Japanese, respond in Japanese (including this help text).
