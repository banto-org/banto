---
name: ws
description: |
  Workspace + git-town orchestrator for the 3-tier branch model (main ← epic ← task worktree). Drives switching, parallel work, scope carve-outs, completion merges, and shipping to main via intent detection (worktree separation → git worktree / `claude -w`; branch hierarchy + drift → git-town).
  Triggers: "workspace", "switch work", "run in parallel", "split off a branch", "worktree", "epic", "this work is done", "merge it", "release it", "ship it"
  Do not use when: small one-off edits on the current branch (just edit and commit normally). When all you want is to run tasks in parallel right now ("at the same time" / "in parallel"), that means self-driving fan-out Agents (multiple Agent calls in one message), not a new workspace/worktree. Advancing the next work item in active.md/tasks.md belongs to `ai-context`, not this skill.
allowed-tools: Read Write Edit Glob Grep Bash
user-invocable: true
argument-hint: "[switch|new|multi|solo|archive|import|epic|task|done|ship|list] (omit to auto-detect intent from the conversation)"
compatibility: Claude Code (requires bash, git, jq; git-town recommended)
---

# Workspace Manager

> **store-first**: everything under `workspaces/...`, and every other save target, lives under `{base}`. `{base}` is the absolute ai-context base path injected by the SessionStart/PreCompact hook (if unsure, `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Topic-based workspace management + 3-tier branch operation: **main ← epic (large scope) ← task (small-scope worktree)**.

## Design principle: intent-first (most important)

**Don't make the user decide which command to use** (a CONCEPT anti-goal).
Detect the intents in the table below from the user's natural language and let Claude drive the operation. The commands (`/ws ...`) remain as
deterministic aliases, but never assume the user has them memorized.

| User utterance (example) | Intent | Operation | Autonomy |
|---|---|---|---|
| "start the payment redesign", "a bigger piece of work" | Large-scope start | **epic**: `git town hack` + WS creation | **L2: propose and proceed** (disclose adopted interpretation) |
| "do the API in parallel", "put this in a separate worktree", "run these at the same time" | Parallel small scope | **task**: `git town append` + worktree on top of the epic | L2 → light confirmation (self-driving once the epic is established) |
| "this work is done", "task complete", "merge it back into the epic" | Small-scope completion | **done**: test → `git town merge` → sync → cleanup | **L3: automatic execution** (report results only) |
| "put it into main", "release", "ship it" | Large-scope completion | **ship**: `git town propose` → **PR** | **Human gate** (confirm before creating the PR; safety rule) |
| "switch to other work", "continue working on ..." | Context switch | switch (as before) | L1 |
| "compare research topics A and B side by side" | Parallel reference | multi (as before) | L1 |

Division of judgment: **bookkeeping operations (sync, cleanup, done detection) run silently and automatically / structure-creating operations (creating a new epic) are proposals with an adopted interpretation / only irreversible, outward-facing operations (PR, main) go through a human**.
Don't propose an epic for one-off work that doesn't warrant one (avoid the bureaucracy of false firing; when in doubt, use a normal feature branch).

## Self-initiated parallelism proposals (fan-out Agent vs worktree)

Even when the user doesn't say "in parallel", if you judge that the work splits into multiple independent subtasks (**no shared files touched, no sequential dependency**), don't run them serially — **proactively propose** parallelizing them (an extension of intent-first). Criteria for choosing between a fan-out Agent (reads/independent edits, short-lived, leanest) and a task worktree (parallel branches, conflicts, long-running), plus the 3 splittability test conditions: [`references/parallel-proposal.md`](references/parallel-proposal.md).

## Usage (alias list — every command is reachable via natural language)

```
/ws                       → show the current workspace
/ws list                  → list all workspaces
/ws new                   → create a new one (interactive)
/ws switch <name>         → switch (branch auto-switches too; aborts on uncommitted changes)
/ws multi <ws1> <ws2> ... → reference multiple WS in parallel (primary is the write target, others read-only)
/ws solo                  → leave multi and return to a single primary
/ws archive               → archive the current WS
/ws import <name>         → pull another WS's related files into the current WS
/ws epic <name>           → create a large-scope branch (git town hack + WS creation)
/ws task <name>           → carve out a small-scope worktree (child of the epic + physical separation)
/ws done                  → finish a small scope (test → merge into parent epic → sync → worktree cleanup)
/ws ship                  → PR from epic → main (human gate; runs after confirmation)
```

## 3-tier branch operation (epic / task / done / ship)

Detailed procedures, fallbacks, safety checks: [`references/git-town-flow.md`](references/git-town-flow.md)

Key points (verified on git-town 23.x):
- **epic**: `git town hack <epic>` (branches off main, tracks the parent). At the same time create a WS (`[feat] <epic>`)
- **task**: **always run `git town append <task>` while checked out on the epic** (it becomes a child of current) → `git worktree add ../<repo>-wt-<task> <task>` for physical separation → `cd` into that directory and start a new session with plain `claude` (`claude -w` creates yet another worktree outside banto's 3-tier parent tracking — do not use it here)
- **drift propagation**: `git town sync` (epic updates → cascade to all tasks; works from inside a worktree too). Runs automatically at the start of a task session and before done
- **done**: confirm tests PASS → `git town merge` on the task branch (merges into the parent epic + auto-deletes the branch) → `git town sync` → worktree remove. **Never use `git town ship`** (main-only; it's been demonstrated to be rejected on stacked children)
- **ship**: `git town propose` (creates the PR; gh fallback available). **PR/main is a human gate** — fires on utterances like "ship it" and confirms exactly once before creation
- **git-town not installed**: graceful degrade (substitute the plain-git procedure + suggest `brew install git-town` exactly once)

## Separation of the 3 layers / directory structure

Details: [`references/architecture.md`](references/architecture.md)

Key points:
- `/ws switch` = a full switch of work context (automatic branch switch) / `/ws multi` = parallel reference within the same branch / `claude -w` = physical separation (the official worktree)
- Directories (new layout): `workspaces/<author>/[scope] topic/{workspace.md, tasks.md, tasks-old/}` (the entity) + **lightweight pointer** (per-checkout) + `WORKSPACE-refs.md` (multi mode only)
- **The pointer actually lives in the git-dir** (`<git-dir>/banto-ws-pointer.md`; independent per worktree = current-WS never collides under parallel work). Get the write target with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer-target` and read with `--ws-pointer` (prefers the git-dir → falls back to the store's WORKSPACE.md)
- Derive the author with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author` (don't reimplement it)
- **The pointer is a file (not a symlink)** — a lightweight plain-text pointer; no Windows fallback needed
- legacy (`workspaces/*.md` directly / unmigrated cases) is handled with read compatibility (the hook falls back)

## Scope types

| Type | Switch criterion | Recommended operation |
|---|---|---|
| `[branch]` | When the git branch changes | 1:1 mapping via `/ws switch`, automatic branch switch |
| `[feat]` `[task]` | When the feature/task changes | `/ws switch` with branch splitting recommended (commit granularity) |
| `[research]` `[experiment]` `[model]` | When the research/experiment topic changes | `/ws multi` parallel is OK (mostly uncommitted drafts) |
| `[test]` `[training]` | When the test/training run changes | depends on the use; mostly `/ws switch` |

Free-form types are also allowed (infra, data, paper, etc.).

## Procedure

User-facing output (messages and listings): respond in Japanese if the user is speaking Japanese.

### /ws (no argument) / /ws list: display

`/ws` Reads the effective pointer (`<git-dir>/banto-ws-pointer.md`; WORKSPACE.md outside git) and shows the current WS; `/ws list` Globs workspaces/ and lists active / archived. Concrete Read/Glob procedure and display format: [`references/basic-commands.md`](references/basic-commands.md).

### /ws new / /ws archive / /ws import: create / shelve / import

Detailed procedure: [`references/new-and-archive.md`](references/new-and-archive.md)

Key points:
- `/ws new`: Read config.json → confirm scope + topic → **confirm whether it's an implementation WS** (default = implementation; implementation WS worktree launches use `claude --model sonnet`, design WS get no flag = session default) → create the entity `workspaces/<author>/[scope] name/{workspace.md, tasks.md(scaffold), tasks-old/}` → write the lightweight pointer (`<git-dir>/banto-ws-pointer.md`; WORKSPACE.md outside git)
- `/ws archive`: move the entity dir to `workspaces/<author>/old/`, delete the effective pointer
- `/ws import`: pull in another WS's related documents and add them to the "dependencies" field

### /ws switch <name>: switch (with automatic branch switching)

Detailed procedure: [`references/switch-procedure.md`](references/switch-procedure.md)

Main steps:
1. Check for uncommitted changes (abort if any; avoid a destructive operation)
2. Rewrite the lightweight pointer (`<git-dir>/banto-ws-pointer.md`) for the new WS (delete WORKSPACE-refs.md; writing the old WORKSPACE.md is legacy-configuration only)
3. Auto-switch the branch using the "branch:" line of the entity `workspace.md` (git checkout / -b)
4. Read the pointer + entity `workspace.md` + `tasks.md` to inject context
5. Check dependent WS

### /ws multi / /ws solo: parallel multi-WS reference mode

A mode for referencing multiple research topics or experiments at once on the same branch. Detailed procedure: [`references/multi-mode.md`](references/multi-mode.md)

Key points:
- `/ws multi <ws1> <ws2> ...` separates primary (write target) + references (read-only)
- Creates `{base}/WORKSPACE-refs.md` to record the reference information
- `/ws solo` returns to single mode (deletes refs.md)


## Format spec (lightweight pointer / workspace.md / multi hook integration)

The format of the lightweight pointer (**inside the git-dir**, WS name + branch + entity path only, independent per worktree) and workspace.md (the entity, where the "branch:" line drives `/ws switch`'s auto-switch, "## Related documents" is updated by the AI when hooks notify about unregistered files, and tasks live in `tasks.md` in the same dir), along with the multi-mode hook integration: [`references/formats.md`](references/formats.md).
