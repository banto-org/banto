---
name: ai-context
description: |
  AI context management: decision logs / checkpoints / task file (tasks.md) editing + next-task navigation + Phase completion / document sorting / memos / knowledge promotion / store bootstrap + health diagnostics + standing-approval (grants) management. Internal search is owned by the `search` skill.
  Triggers: "decision", "design choice", "save", "checkpoint", "compact", "clear", "task", "TODO", "Phase", "continue", "next task", "carry on", "tidy up the docs", "it's a mess", "exclude", "don't touch it", "disable", "make a note", "jot this down", "summarize and save this conversation", "turn into knowledge", "promote to knowledge", "show me the drafts", "save as a lesson", "create a store", "pin local", "health check", "standing approval", "grant permission".
  Do not use when: searching context already stored (use the `search` skill) or investigating external sources (use `research`). A bare "do it" / "go ahead" during implementation means self-driving (act directly); only task-qualified phrases ("next task", "carry on") route to next-task navigation. Saving session state is `save-checkpoint`; switching git worktree / branch for scoping is `ws`, not this skill.
allowed-tools: Read Write Edit Glob Grep Bash Agent
argument-hint: "[bootstrap|local|doctor|sort|next|phase-done|ignore|tasks|migrate|memo|knowledge]"
compatibility: Claude Code (requires bash, git, jq)
---

# AI Context

> **Storage base (store-first)**: `{base}` is the absolute ai-context base path injected by the SessionStart/PreCompact hook. Always Read/Write under it (in-repo `.ai-context/` is retired — it is non-destructively auto-migrated to the store on detection; never write to it by hand). If unknown, resolve it: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`.
>
> **Output language**: write generated artifacts in the user's conversation language. The Japanese templates under `references/` are only structural scaffolds — translate the headings/labels to match the conversation language.

## Subcommand router (explicit user invocation)

Interpret the first token of `$ARGUMENTS` as a subcommand, Read the corresponding references/ file, and follow its procedure.

| Subcommand | Role | Details |
|---|---|---|
| `bootstrap` | Create / register a store + migrate the provisional local (`ai-context-local`) → store (absorbs init) | "Store bootstrap" below |
| `local` | Pin this repo to local-only (mapping `local:true`; never sent to GitHub by bootstrap / migration) | "Pin to local" below |
| `doctor` | Health diagnostics (subsumes status, no writes; calls the store health lint + cross-project migration status [projects not yet promoted to central]) | `references/doctor.md` |
| `sort` | Interactively sort misplaced files inside `{base}/` (writes) | `references/sort.md` |
| `sort project` | Organize scattered documents across the whole project | `references/sort.md` |
| `next` | Identify the next open task and carry it through to implementation | `references/task-lifecycle.md` |
| `phase-done [N]` | Phase completion check + verification + archival | `references/task-lifecycle.md` |
| `ignore` | Manage scaffold-suppression paths (writes) | `references/ignore.md` |
| `tasks split` | Split tasks.md by Phase | `references/task-lifecycle.md` |
| `migrate [path\|--all]` | Migrate a project's ai-context to the central store | `references/setup.md` |
| `memo [text]` | Turn the conversation / given content into a `[Memo]` document | "Memo (`memo`)" below |
| `knowledge [list\|promote\|<topic>]` | List / promote / create knowledge drafts | "Knowledge (`knowledge`)" below |
| `ref [location/URI]` | Register an external document's location card under `docs/refs/` (also fires on "it's here") | "Location registration (`ref`)" below |

If the argument is empty or unknown, show usage.

**Firing from natural language**: in addition to explicit subcommands, route automatically from context: "continue" / "next" / "next task" / "go ahead" → `next`; "organize the docs" / "it's a mess" → `sort project`; "phase done" → `phase-done`; "make a note" / "jot this down" / "summarize and save this conversation" → `memo`; "turn into knowledge" / "promote to knowledge" / "list the drafts" / "save as a lesson" → `knowledge`; "create a store" / "set up ai-context-store" / "I want to push this to GitHub" and the SessionStart hook's bootstrap prompt → `bootstrap`; "keep this repo local-only" / "don't push to GitHub" / "pin local" → `local`; "health check" / "health diagnostics" / "show me the status" / "tell me what's here" / "what hasn't migrated" / "check migration status" → `doctor`; "allow PR creation for this repo" / "allow production work" / "grant standing approval for push" / "standing approval" / "grant permission" → "Standing approval (grants)".

**Central store operations (teams / multiple projects)**: the end-to-end procedure for aggregating, syncing, and running the central store across a team (setup → migrate `migrate` → reference → push) lives in [`references/central-store-guide.md`](references/central-store-guide.md).

## Store bootstrap (`bootstrap`)

For an unregistered repo with no central store, the SessionStart hook immediately and without blocking prepares `~/ai-context-local/<project>/` (a provisional local with the same layout as the store) and gives a one-line notice (it does not silently create a GitHub-backed store). `bootstrap` is the step that **migrates this provisional local into a real store after the fact**. Since the hook cannot converse, the actual dialogue happens here. Confirm the **three choices in a single conversation** (no modals — ask one at a time in plain prose):

1. **If you already have an ai-context-store on GitHub**: confirm the repo as `org/name` → register + migrate the provisional local in one command:
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" bootstrap <org>/<name>
   ```
2. **If there isn't one and you're creating it fresh**: confirm which org (or GitHub username) to put it under → create as private-only + migrate in one command:
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" bootstrap <org>
   ```
   Creates it with `gh repo create --private` and saves the chosen org to `~/.claude/banto-store-target.conf` (from the second time on, the org is already saved, so you only confirm whether to create — no need to re-enter the org).

After registering/creating, if this repo has a provisional local (`ai-context-local/<project>`), `bootstrap` **migrates it into the store, add-first** (existing files are not overwritten; conflicts are confirmed). After migration the provisional-local entry in the mapping disappears, and from the next SessionStart the store's absolute path is injected.

> **interface (WT-A)**: `ai-context-store-init.sh bootstrap [<org/name>|<org>]` wraps register-or-create + provisional-local migration. Pinning to local is the `local` subcommand. The legacy flags `--create` / `--register` / `--org` are also available.

In either branch, once registration is done, from the next SessionStart "ai-context base: &lt;absolute path&gt;" is injected as the store-side absolute path, and you can write decisions / docs / tasks to the store. To only save the org, use `--org <org>`. An existing in-repo `.ai-context/` is not a resolver target — scaffold auto-migrates it to the store non-destructively on detection, so running `migrate` explicitly is not required (use it only when you want it done right now).

## Pin to local (`local`)

Pin a repo you want to manage **local-only**, without pushing to GitHub. It sets a `local:true`-equivalent marker on the corresponding project in the mapping, so the repo is never sent to GitHub by `bootstrap` or migration from then on.

```bash
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" local
```

Once pinned, this repo's ai-context stays resident at `~/ai-context-local/<project>/`, and `bootstrap` / migration are skipped. If you want to undo it, migrate to a store again with `bootstrap`.

> **interface (WT-A)**: `ai-context-store-init.sh local [--cwd <dir>]` sets `local:true` on the corresponding project in the mapping.

## Standing approval (grants)

Record a per-repo standing approval in `{base}/meta/grants.json` (fires on "allow PR creation for this repo" / "allow production work" / "grant standing approval for push"). After writing, recording the change as one line under `decisions/` is recommended.

Keys are `pr_create` (`gh pr create`), `pr_merge` (`gh pr merge` — covers others' PRs too), `push_feature` (push to a feature branch), and `prod_ops` (production-environment operations). Values are `allow` (standing approval — no further confirmation), `deny` (always block — an explicit refusal against accidental approval), or `confirm` (default — confirm every time). `allow`/`deny` are read deterministically by `release-guard.sh` (`pr_create` / `pr_merge`) and `prod-guard.sh` (`prod_ops`).

Time-boxed approvals are also supported (e.g. "only allow it for a week"): set the value to the object form `{"value": "allow", "until": "YYYY-MM-DD"}`, and it automatically reverts to `confirm` (confirm every time) the day after `until` — it never decays into `deny`.

```json
{"schema_version": 1, "grants": {"pr_create": "allow", "prod_ops": {"value": "allow", "until": "2026-07-17"}}}
```

## Saving decisions (auto-save / format / secrets)

Details: [`references/decisions.md`](references/decisions.md)

- **When**: the moment a design decision occurs (don't wait for a commit). Save = design direction / technology choice / architecture change / trade-off / root cause. Don't save = plain implementation / typo / a mere factual answer.
- **Where**: `{base}/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md` (derive the timestamp from `date`, do not write it from memory; the old `YYYY-MM-DD_NNN_` format is still valid).
- **Format**: lightweight (title + decision) / full (starting point / options / deciding factor / why rejected / **friction** / **lessons learned**). Friction and lessons are the core of organizational learning.
- **Secrets** (ironclad rule): don't write `sk-*` / `ghp_*` / `Bearer *` / `.env` values into decisions / checkpoints → replace with `{SECRET}`. On exposure, **revoke / rotate** immediately (it stays in the chat history).

## Location registration (`ref`) — external-document location cards

Register **only the location and relations** of an external document (SharePoint / file server / URL /
local file outside the store) as one card at `{base}/docs/refs/[Ref] <name>.md`. Never mirror the body —
when the content itself needs to be searchable, use the research skill to pull the text into `docs/research/`.
Triggers: "it's here", "remember this location", "register the location" — and **whenever Claude itself
reads an external document and uses it as evidence during work**, create/update the card proactively
as a by-product of the conversation.

```markdown
---
title: <human-readable name>
source: sharepoint | fileserver | url | local
uri: <https://… / smb://… / /Volumes/…>
fetched: <YYYY-MM-DD when the real document was last verified>
related:
  - <decisions/… or docs/… — related store documents (prefix form is fine)>
---
# <name>

<2–3-line summary (required): what the document is for and which work it relates to.>
```

- The frontmatter (`source` / `uri` / `fetched` / `related`) is the fixed structural-metadata contract.
- **The 2–3-line summary is required**: search only ever hits the card's summary — a card with just a title and a URL never becomes searchable.
- `related:` is extracted deterministically into the ledger's `references` relations + the search db's
  refs table. Traverse with `sh "$CLAUDE_PLUGIN_ROOT/scripts/store-query.sh" --related <fragment>`
  (→ outgoing / ← incoming).
- The canonical copy always lives at the external uri; the card holds only "where it is and what it relates to".
- Bulk inventory (auto-generation by directory scan) is `scripts/ref_scan.py` (Excel: sheet list + cross-sheet references. A card with an empty summary field gets a `(summary not filled in — won't surface in search)` placeholder — fill it in when you spot one).

## Memo (`memo`)

Save the conversation / given content as a `[Memo]`-prefixed document under `{base}/docs/` (also fires on "make a note" / "jot this down" / "summarize and save this conversation"). Write the *body* of the memo in the user's conversation language. The section headings (`## Content` / `## Topics discussed`, etc.) are fixed structural markers and are not translated.

No argument → summarize the conversation into `{base}/docs/[Memo] session-summary-{YYYY-MM-DD}.md`. With an argument → record the content of `$ARGUMENTS` into `{base}/docs/[Memo] {slugified argument}-{YYYY-MM-DD}.md`. Fill-in templates and style conventions: [`references/doc-templates.md`](references/doc-templates.md).

## Knowledge (`knowledge`)

Review and promote knowledge drafts (`{base}/docs/knowledges/drafts/`), organizing them into formal knowledge entries (also fires on "turn into knowledge" / "show me the drafts" / "save as a lesson"). Respond and write in the user's conversation language.

Determine the mode from the first token of `$ARGUMENTS`: no argument/`list` → list drafts, a number/`promote` → promotion, a topic string → create new. Procedure, fill-in templates, and the draft auto-save hook: [`references/doc-templates.md`](references/doc-templates.md). Canonical structure: [`references/directory-structure.md`](references/directory-structure.md) (promotion target = `{base}/docs/knowledges/{topic}.md`, draft = `{base}/docs/knowledges/drafts/{topic}.md`).

## Directory structure / prefixes

Details, canonical source: [`references/directory-structure.md`](references/directory-structure.md) (the folder → writing skill/hook → prefix/format mapping table. The store layout / bucket list / prefix definitions are canonical there alone and not repeated here).

## Task management rules

| Purpose | Tool |
|------|-------|
| In-session work tracking | `TaskCreate` `TaskUpdate` (Claude Code built-in) |
| Persistent project tasks | The effective tasks file (definition below) |

**Definition of the effective tasks file**: prefer the path under the SessionStart-injected "ongoing tasks" heading. In environments with no hook injection (Claude Desktop / IDE extensions, etc.), look for the current WS's `workspaces/<author>/<topic>/tasks.md`, falling back to the legacy `tasks/active.md`.

**Tasks-file priority:**
1. An existing `tasks.md` `TODO.md` `ROADMAP.md` exists → use it
2. None → create the effective tasks file (the new-layout `tasks.md` if present, otherwise `tasks/active.md`)

**Non-standard tasks files**: the hook only presents them as information. Move one only when the user explicitly says "move it".

### Auto-archive when all tasks are complete

Details: [`references/task-lifecycle.md`](references/task-lifecycle.md)

Summary: when the hook detects that all tasks in the effective tasks file are complete (zero `- [ ]` + one or more `- [x]`) → it files them away as `YYYY-MM-DD_{phase}.md` (new layout = the same WS's `tasks-old/`, legacy = `tasks/old/`; follow the path in the hook notice; the name is extracted from the `## Phase:` header). It does not archive when an existing `tasks.md` / `TODO.md` is in use.

## Setup / migration / denylist management

Details: [`references/setup.md`](references/setup.md)

Summary:
- **fallback**: in environments without hooks (Claude Desktop / IDE extensions / Web UI), use `bash "${CLAUDE_PLUGIN_ROOT}/hooks/_ai-context-scaffold.sh" "$PWD"` to idempotently generate the store skeleton (or the provisional local) (it does not create an in-repo `.ai-context/`)
- **denylist**: for paths registered in `~/.claude/banto-ignore`, the hook exits early. Manage them with `/ai-context ignore add/list/remove`
- **migration**: an existing in-repo `.ai-context/` is auto-migrated to the store non-destructively by scaffold on detection. `/ai-context migrate` is the explicit trigger for doing it right now

## Searching past context

**Search is owned by the `search` skill**. When the user says something like "we decided this before" / "remember…", that skill fires automatically. You can also call it explicitly with `/search <query>`. Claude expands the query into 3 tiers → a ranking script scores candidates with grep → the top hits are verified by Read (targets: decisions/docs under `{base}/` + `extra_docs_dirs` in `config.json`).

## Managing the search text layer (index / full-combined.txt)

Search ranking (`store-query.sh`) scans `{base}/decisions/` and `{base}/docs/` **directly** (it never reads combined.txt — search-layer-redesign spec branch 1A). Files become searchable right after a write; no manual action is needed.

Two layers complement it:
- **FTS5 section index**: auto-regenerated in the background by a hook (`ai-context-index-rebuild.sh`) on a write to `{base}/decisions/` or `{base}/docs/`.
- **full-combined.txt** (the deep-path layer, including session history): does not follow writes — it is only regenerated by SessionStart's daily throttle or on demand at deep-path start.

To add search targets, edit `extra_docs_dirs` in `config.json` directly; it takes effect from the next index / full-combined.txt regeneration.

## Creating checkpoints

Follow the **`save-checkpoint` skill (the `/save-checkpoint` command)** — it is the single source of truth. When a hook notifies "create a checkpoint", likewise run that skill's procedure.

- Checkpoint file: `{base}/sessions/checkpoint-{YYYY-MM-DD}-{HHMM}.md`
- The PreCompact hook auto-deletes it after injecting into the next session, so the AI does not need to delete it

## Help when called without arguments

```
Usage: /ai-context <bootstrap|local|doctor|sort|next|phase-done|ignore|tasks|migrate|memo|knowledge>

Examples:
  /ai-context bootstrap
  /ai-context local
  /ai-context memo the gist of this conversation
  /ai-context knowledge list
  /ai-context tasks split --auto
```

If the user speaks Japanese, respond in Japanese (including this help text).
