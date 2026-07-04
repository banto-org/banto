---
name: ai-context
description: |
  AI context management: decision logs / checkpoints / task file (tasks.md) editing + next-task navigation + Phase completion / document sorting / memos / knowledge promotion / store bootstrap + health diagnostics. Internal search is owned by the `search` skill.
  Triggers: "decision", "design choice", "save", "checkpoint", "compact", "clear", "task", "TODO", "Phase", "continue", "next task", "carry on", "tidy up the docs", "it's a mess", "exclude", "don't touch it", "disable", "make a note", "jot this down", "summarize and save this conversation", "turn into knowledge", "promote to knowledge", "show me the drafts", "save as a lesson", "create a store", "pin local", "health check".
  Do not use when: searching context already stored (use the `search` skill) or investigating external sources (use `research`). A bare "do it" / "go ahead" during implementation means self-driving (act directly); only task-qualified phrases ("next task", "carry on") route to next-task navigation. Saving session state is `save-checkpoint`; switching git worktree / branch for scoping is `ws`, not this skill.
allowed-tools: Read Write Edit Glob Grep Bash Agent
argument-hint: "[bootstrap|local|doctor|sort|next|phase-done|ignore|tasks|migrate|memo|knowledge]"
compatibility: Claude Code (requires bash, git, jq)
---

# AI Context

> **About the storage base (store-first)**: every `{base}/...` path in this skill refers to the **ai-context base directory** —
> the absolute path injected by the SessionStart / PreCompact hook as "ai-context base: &lt;absolute path&gt;". Always
> Read/Write **under that injected absolute path**, and never write to a relative `.ai-context/` (an in-repo `.ai-context/`
> exists only in grandfathered legacy repos and keeps working as the base until you migrate with `/ai-context migrate`).
> If the base is unknown, resolve it in one line: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`.

> **Output language**: write the artifacts you generate (decision logs / tasks.md / checkpoints / status reports / memos / knowledge, etc.) in the user's conversation language. The Japanese templates under `references/` are only structural scaffolds — translate the headings/labels to match the conversation language.

## Subcommand router (explicit user invocation)

Interpret the first token of `$ARGUMENTS` as a subcommand, Read the corresponding references/ file, and follow its procedure.

| Subcommand | Role | Details |
|---|---|---|
| `bootstrap` | Create / register a store + migrate the provisional local (`ai-context-local`) → store (absorbs init) | "Store bootstrap" below |
| `local` | Pin this repo to local-only (mapping `local:true`; never sent to GitHub by bootstrap / migration) | "Pin to local" below |
| `doctor` | Health diagnostics (subsumes status, no writes; calls the store health lint) | `references/doctor.md` |
| `sort` | Interactively sort misplaced files inside `{base}/` (writes) | `references/sort.md` |
| `sort project` | Organize scattered documents across the whole project | `references/sort.md` |
| `next` | Identify the next open task and carry it through to implementation | `references/task-lifecycle.md` |
| `phase-done [N]` | Phase completion check + verification + archival | `references/task-lifecycle.md` |
| `ignore` | Manage scaffold-suppression paths (writes) | `references/ignore.md` |
| `tasks split` | Split tasks.md by Phase | `references/task-lifecycle.md` |
| `migrate [path\|--all]` | Migrate a project's ai-context to the central store | `references/setup.md` |
| `memo [text]` | Turn the conversation / given content into a `[Memo]` document (absorbs the former `memo` skill) | "Memo (`memo`)" below |
| `knowledge [list\|promote\|<topic>]` | List / promote / create knowledge drafts (absorbs the former `knowledge` skill) | "Knowledge (`knowledge`)" below |
| `ref [location/URI]` | Register an external document's location card under `docs/refs/` (also fires on "it's here") | "Location registration (`ref`)" below |

If the argument is empty or unknown, show usage.

### Backward-compat aliases (one release only, accepted with a warning)

Old subcommands / old skill names are **accepted, but emit a one-line deprecation warning and steer you to the new form** (slated for removal next release):

| Old form | New form accepted and steered to |
|---|---|
| `/ai-context init` | `bootstrap` (merged into store create / register + provisional-local migration) |
| `/ai-context status` | `doctor` (status merged in; health diagnostics double as the status display) |
| `/ai-context prune` | (Removed) Cleanup of empty / migrated-legacy / mis-generated folders is automated by a hook. If manual cleanup is needed, follow the `doctor` report |
| `/memo ...` / "make a note" | `ai-context memo [text]` (runs the same procedure) |
| `/knowledge ...` / "turn into knowledge" | `ai-context knowledge [list\|promote\|<topic>]` (runs the same procedure) |

Warning example: "`init` has been merged into `bootstrap` (this alias will be removed next release). Continuing as bootstrap." — once you've emitted the warning, **continue right away with the new form's procedure** (don't block the work).

**Firing from natural language**: in addition to explicit subcommands, route automatically from context: "continue" / "next" / "next task" / "go ahead" → `next`; "organize the docs" / "it's a mess" → `sort project`; "phase done" → `phase-done`; "make a note" / "jot this down" / "summarize and save this conversation" → `memo`; "turn into knowledge" / "promote to knowledge" / "list the drafts" / "save as a lesson" → `knowledge`; "create a store" / "set up ai-context-store" / "I want to push this to GitHub" and the SessionStart hook's bootstrap prompt → `bootstrap`; "keep this repo local-only" / "don't push to GitHub" / "pin local" → `local`; "health check" / "health diagnostics" / "show me the status" / "tell me what's here" → `doctor`.

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

In either branch, once registration is done, from the next SessionStart "ai-context base: &lt;absolute path&gt;" is injected as the store-side absolute path, and you can write decisions / docs / tasks to the store. To only save the org, use `--org <org>`; to move an existing in-repo `.ai-context/` into the store, use `migrate` rather than `bootstrap` (read compatibility is preserved, so there's no rush).

## Pin to local (`local`)

Pin a repo you want to manage **local-only**, without pushing to GitHub. It sets a `local:true`-equivalent marker on the corresponding project in the mapping, so the repo is never sent to GitHub by `bootstrap` or migration from then on.

```bash
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" local
```

Once pinned, this repo's ai-context stays resident at `~/ai-context-local/<project>/`, and `bootstrap` / migration are skipped. If you want to undo it, migrate to a store again with `bootstrap`.

> **interface (WT-A)**: `ai-context-store-init.sh local [--cwd <dir>]` sets `local:true` on the corresponding project in the mapping.

## Saving decisions (auto-save / format / secrets)

Details: [`references/decisions.md`](references/decisions.md)

- **When**: the moment a design decision occurs (don't wait for a commit). Save = design direction / technology choice / architecture change / trade-off / root cause. Don't save = plain implementation / typo / a mere factual answer.
- **Where**: `{base}/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md` (the PreToolUse hook injects the recommended name; the old `YYYY-MM-DD_NNN_` format is still valid).
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

Save the conversation / given content as a `[Memo]`-prefixed document under `{base}/docs/` (absorbs the former `memo` skill; also fires on "make a note" / "jot this down" / "summarize and save this conversation"). Write the *body* of the memo in the user's conversation language. The section headings (`## Content` / `## Topics discussed`, etc.) are fixed structural markers and are not translated.

### Mode 1: no arguments (summarize the conversation)

Summarize the current conversation into a memo. Items to extract: topics discussed / decisions made / open issues / key findings & insights.
Destination: `{base}/docs/[Memo] session-summary-{YYYY-MM-DD}.md`

```markdown
# [Memo] Session Summary

- **Date**: {today's date}
- **Author**: AI

## Topics discussed
- {topic 1}
- {topic 2}

## Decisions made
-

## Open issues
-

## Key findings / insights
-
```

In Mode 1, **present the summary as text and then save** (after-the-fact disclosure — saving to the store is a non-destructive "run freely" operation per safety.md; the user can request edits afterward).

### Mode 2: with an argument (memoize the given content)

Record the content of `$ARGUMENTS` as a memo.
Destination: `{base}/docs/[Memo] {slugified argument}-{YYYY-MM-DD}.md`

```markdown
# [Memo] {title from the argument}

- **Date**: {today's date}
- **Author**: AI

## Content

{structured write-up of $ARGUMENTS}
```

Saving and reporting follow the common pattern (`${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` §2 pattern B / §3 naming convention / §4 report format / §1.6 style conventions). A Japanese memo body follows `~/.claude/rules/writing-ja.md` (noun-ending style / no だ・である・です・ます at sentence end / fewer katakana-English terms / half-width space around alphanumerics / don't round numbers).

## Knowledge (`knowledge`)

Review and promote knowledge drafts (`{base}/docs/knowledges/drafts/`), organizing them into formal knowledge entries (absorbs the former `knowledge` skill; also fires on "turn into knowledge" / "show me the drafts" / "save as a lesson"). Respond and write in the user's conversation language.

Structure: see [`references/directory-structure.md`](references/directory-structure.md) for details. Promotion target = `{base}/docs/knowledges/{topic}.md`, draft = `{base}/docs/knowledges/drafts/{topic}.md`.

### Determine the mode (the first token of `$ARGUMENTS`)

- **No argument / `list`** → list drafts
- **A number / `promote`** → promotion mode
- **A topic string** → create a new knowledge entry

#### list (list drafts)

1. `Glob("{base}/docs/knowledges/drafts/*.md")`
2. Read the first 3 lines (the title) of each file
3. Display the list and ask for the number(s) to promote (or "all"):

```
## Knowledge drafts

1. **PostToolUse JSON shell expansion issue** (drafts/posttooluse-json-shell-expansion.md)
2. **search query expansion tuning** (drafts/search-query-expansion-tuning.md)

Pick the ones to promote (number, or "all").
```

#### promote (promotion)

1. Read the selected file in full, display it, and ask the user for edits
2. Once confirmed, move it from `drafts/` directly into `knowledges/`:
   ```bash
   git mv "{base}/docs/knowledges/drafts/{file}" "{base}/docs/knowledges/{file}"
   ```
   (use `mv` if the store is not under git)
3. search ranking scans decisions/docs directly, so the file is searchable right after the move (the FTS5 section index auto-follows the Write via the PostToolUse hook)

#### Create new

Save `$ARGUMENTS` as the topic directly into `knowledges/`:

```markdown
# {topic}

## Problem
{what happened}

## Cause
{why it happened}

## Solution
{how it was solved}

## Lesson
{how to prevent the same problem}

## Related
- {related decisions/ files}
- {related research/ files}
```

Naming follows the knowledge exception (no prefix; the title becomes the filename) (`_common-pattern.md` §3 "knowledge exception"). Promoted knowledge is searchable across the store via the `search` skill (`/search <query>`).

> **Auto-saving drafts (hook)**: when `ai-context-auto.sh` detects "got stuck", "the cause is", "solved it", "pattern", "figured it out", "turned out", "discovered", "noticed", "gotcha", "workaround", "notice", it prompts to save a draft. Accumulated drafts are surfaced by the SessionStart hook (`knowledge-draft-review.sh`) once they exceed a threshold, and handled by this `knowledge` procedure.

## Directory structure / prefixes

Details, canonical source: [`references/directory-structure.md`](references/directory-structure.md) (the folder → writing skill/hook → prefix/format mapping table. The store layout / bucket list / prefix definitions are canonical there alone and not repeated here).

## Task management rules

| Purpose | Tool |
|------|-------|
| In-session work tracking | `TaskCreate` `TaskUpdate` (Claude Code built-in) |
| Persistent project tasks | The effective tasks file (the path under the SessionStart "ongoing tasks" heading; new layout = `workspaces/<author>/<topic>/tasks.md`, legacy = `tasks/active.md`) |

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
- **migration**: moving an existing in-repo `.ai-context/` to the central store is `/ai-context migrate` (read compatibility preserved)

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
  /ai-context memo この会話の要点
  /ai-context knowledge list
  /ai-context tasks split --auto
```

If the user speaks Japanese, respond in Japanese (including this help text).
