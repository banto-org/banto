---
name: ai-context
description: |
  AI context management: decision logs / checkpoints / task file (tasks.md) editing + next-task navigation + Phase completion / document sorting / scaffold ignore management. Internal search is owned by the `search` skill.
  Triggers: "decision", "design decision", "save", "checkpoint", "compact", "clear", "task", "TODO", "Phase", "continue", "next task", "continue the work", "organize the docs", "docs are a mess", "exclude", "don't touch this", "disable"
  Do not use when: searching context that is already stored (use the `search` skill) or investigating external sources (use `research`). A bare "do it" mid-implementation means proceed by self-driving (act directly) — only task-qualified phrases ("next task", "continue the work") route to next-task navigation. Switching the git worktree/branch for a scope is `ws`, not this skill.
allowed-tools: Read Write Edit Glob Grep Bash Agent
argument-hint: "[init|status|doctor|sort|next|phase-done|ignore|tasks|migrate|prune]"
compatibility: Claude Code (requires bash, git, jq)
---

# AI Context

> **About the storage base (store-first)**: every `.ai-context/...` path in this skill refers to the **ai-context base directory** —
> the absolute path the SessionStart / PreCompact hooks inject as 「ai-context ベース: &lt;absolute path&gt;」 (literal hook label; "ベース" = base). Always Read/Write under
> **that injected absolute path**; never write to a relative `.ai-context/` (an in-repo `.ai-context/` exists only in grandfathered
> legacy repos, where it keeps working as the base until migrated with `/ai-context migrate`).
> If the base is unknown, resolve it in one line: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`.

> **Output language**: write generated artifacts (decision logs / tasks.md / checkpoints / status reports, etc.) in the user's conversation language. The Japanese templates in `references/` are structural scaffolds only — translate their headings/labels to match the conversation language.

## Subcommand router (explicit user invocation)

Interpret the first token of `$ARGUMENTS` as a subcommand, Read the corresponding references/ file, and follow its procedure.

| Subcommand | Role | Details |
|---|---|---|
| `init` | Create from scratch (first-time setup) | `references/setup.md` |
| `status` | Show what exists (no writes) | `references/status.md` |
| `doctor` | Detect breakage / misplacement (no writes) | `references/doctor.md` |
| `sort` | Interactively triage misplaced files inside `.ai-context/` (writes) | `references/sort.md` |
| `sort project` | Organize scattered documents across the whole project | `references/sort.md` |
| `next` | Identify the next open task and carry it through to implementation | `references/task-lifecycle.md` |
| `phase-done [N]` | Phase completion check + verification + archive | `references/task-lifecycle.md` |
| `ignore` | Manage scaffold suppression paths (writes) | `references/ignore.md` |
| `tasks split` | Split tasks.md by Phase | `references/task-lifecycle.md` |
| `migrate [path\|--all]` | Migrate a project's ai-context to the central store | `references/setup.md` |
| `prune` | Detect and confirm-delete empty / migrated-legacy / mis-generated folders | `references/setup.md` |

If the argument is empty or unknown, show usage.

**Firing from natural language**: besides explicit subcommands, auto-route from context: 「続き」「次」「次のタスク」「進めて」 / "continue", "next", "next task", "go ahead" → `next`; 「ドキュメント整理」「散らかってる」 / "organize the docs", "it's a mess" → `sort project`; 「Phase 完了」 / "phase done" → `phase-done`.

**Central store operation (teams / multiple projects)**: the end-to-end procedure for consolidating ai-context from in-repo `.ai-context/` into `~/ai-context-store/<project>/` (setup → migration `migrate` → referencing → push → removal `prune`) is in [`references/central-store-guide.md`](references/central-store-guide.md).

## Saving decisions (auto-save / format / secrets)

Details: [`references/decisions.md`](references/decisions.md)

- **When**: the moment a design decision occurs (never wait for a commit). Save = design policy / technology choice / architecture change / trade-off / root cause. Do not save = simple implementation / typo / plain factual answer.
- **Where**: `.ai-context/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md` (a PreToolUse hook injects the recommended name; the old `YYYY-MM-DD_NNN_` format remains valid).
- **Format**: lightweight (title + decision) / full (starting point / options / deciding factor / why rejected / **friction** / **lessons learned**). Friction and lessons are the core of organizational learning.
- **Secrets** (hard rule): never write `sk-*` / `ghp_*` / `Bearer *` / `.env` values into decisions / checkpoints → replace with `{SECRET}`. On exposure, immediately recommend **revoke / rotation** (it stays in chat history).

## Directory structure / prefixes

Details: [`references/directory-structure.md`](references/directory-structure.md)

Main buckets:
- `decisions/` design decision logs / `docs/` report-style docs (prefix required) / `workspaces/<author>/<topic>/tasks.md` (new layout; legacy is `tasks/active.md`) / `sessions/`
- Prefixes directly under `docs/`: `[Review]` `[QA]` `[Audit]` `[Status]` `[Design]` `[Guide]` `[Memo]` `[Index]` (hook-enforced; do not invent new prefixes)

## Task management rules

| Purpose | Tool |
|------|-------|
| In-session work tracking | `TaskCreate` `TaskUpdate` (built into Claude Code) |
| Persistent project tasks | The effective tasks file (the path under the SessionStart 「進行中タスク」 ("tasks in progress") heading; new layout = `workspaces/<author>/<topic>/tasks.md`, legacy = `tasks/active.md`) |

**Task file precedence:**
1. An existing `tasks.md` `TODO.md` `ROADMAP.md` exists → use it
2. None → create the effective tasks file (the new-layout `tasks.md` if present, otherwise `tasks/active.md`)

**Non-standard task files**: the hook surfaces them as information only. Move them only when the user explicitly says 「移動して」 / "move it".

### Auto-archive when all tasks are complete

Details: [`references/task-lifecycle.md`](references/task-lifecycle.md)

Gist: a hook detects that the effective tasks file has all tasks done (zero `- [ ]` + at least one `- [x]`) → moves it aside as `YYYY-MM-DD_{phase}.md` (new layout = the same WS's `tasks-old/`, legacy = `tasks/old/`; follow the path in the hook notification; the name is extracted from the `## Phase:` header). No archiving when an existing `tasks.md` / `TODO.md` is in use.

## First-time setup / denylist management

Details: [`references/setup.md`](references/setup.md)

Gist:
- **fallback**: in hook-less environments (Claude Desktop / IDE extensions / Web UI), generate `.ai-context/` idempotently with `bash "${CLAUDE_PLUGIN_ROOT}/hooks/_ai-context-scaffold.sh"`
- **denylist**: hooks exit early for paths registered in `~/.claude/banto-ignore`. Manage with `/ai-context ignore add/list/remove`

## Searching past context

**Search is owned by the `search` skill**. When the user says things like 「前に決めた」「思い出して」 ("we decided this before", "remember..."), that skill auto-fires. It can also be invoked explicitly with `/search <query>`. Claude expands the query into 3 layers → the ranking script scores candidates via grep → top hits are verified with Read (targets: decisions/docs under `.ai-context/` + `extra_docs_dirs` from `config.json`).

## Managing the search text layer (combined.txt)

`combined.txt`, the grep target for search, is **auto-regenerated on save by a hook (`ai-context-combined-rebuild.sh`)**:
- on writes to `.ai-context/decisions/`
- on writes to `.ai-context/docs/`
- runs in the background (debounced)

No manual operation is needed. To add search targets, edit `extra_docs_dirs` in `config.json` directly; it takes effect from the next hook regeneration.

## Creating checkpoints

Follow the **`save-checkpoint` skill (`/save-checkpoint` command)** — it is the single source of truth. When a hook notifies 「チェックポイント作成」 (create a checkpoint), execute with that skill's procedure as well.

- Checkpoint file: `.ai-context/sessions/checkpoint-{YYYY-MM-DD}-{HHMM}.md`
- The PreCompact hook auto-deletes it after injecting it into the next session, so the AI does not need to delete it

## Help when invoked with no arguments

```
Usage: /ai-context <init|status|doctor|sort|next|phase-done|ignore|tasks|migrate|prune>

Examples:
  /ai-context init
  /ai-context tasks split --auto
```

If the user speaks Japanese, respond in Japanese (including this help text).
