---
name: ws
description: |
  Workspace + git-town orchestrator for the 3-tier branch model (main ← epic ← task worktree): switching, parallel work, scope carving, completion merges, and shipping to main via intent detection (worktree isolation → git worktree / `claude -w`; branch hierarchy + drift → git-town).
  Triggers: "workspace", "switch work", "parallel branch", "separate branch", "worktree", "epic", "this work is done", "merge it", "release it", "ship it"
  Do not use when: a small one-off edit on the current branch (just edit and commit normally). A bare "in parallel" to run tasks right now means self-driving parallel Agents (one message, multiple Agent calls), not a new workspace/worktree. Advancing the next work item in active.md/tasks.md is `ai-context`, not this skill.
allowed-tools: Read Write Edit Glob Grep Bash
user-invocable: true
argument-hint: "[switch|new|multi|solo|archive|import|epic|task|done|ship|list] (defaults to natural-language intent detection)"
compatibility: Claude Code (requires bash, git, jq; git-town 推奨)
---

# Workspace Manager

> **Storage base (store-first)**: every `.ai-context/...` path in this skill (including workspaces/) refers to the ai-context base. When the central store is in use, Read/Write under the 「ai-context ベース: &lt;絶対パス&gt;」 (absolute path) injected by the SessionStart/PreCompact hooks (if unknown: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Topic-based workspace management + 3-tier branch operation: **main ← epic (large scope) ← task (small-scope worktree)**.

## Design principle: intent-first (most important)

**Never make the user decide which command to use** (CONCEPT anti-goal).
Detect the intents in the table below from the user's natural language and let Claude drive the operation. Commands (`/ws ...`)
remain as deterministic aliases, but users are not expected to memorize them.

| User utterance (examples) | Intent | Operation | Autonomy |
|---|---|---|---|
| 「決済のリデザインを始める」「大きめの作業」 / "start the payment redesign", "a bigger piece of work" | Start a large scope | **epic**: `git town hack` + WS creation | **L2: propose and proceed** (disclose the adopted interpretation) |
| 「API は並行で」「これは別 worktree で」「同時に進めて」 / "do the API in parallel", "put this in a separate worktree", "run these at the same time" | Parallel small scope | **task**: `git town append` on the epic + worktree | L2 → light confirmation (self-driving once the epic is established) |
| 「この作業終わった」「task 完了」「epic に戻して」 / "this work is done", "task complete", "merge it back into the epic" | Finish small scope | **done**: test → `git town merge` → sync → cleanup | **L3: auto-execute** (report results only) |
| 「main に入れて」「リリース」「これで出して」 / "put it into main", "release", "ship it" | Finish large scope | **ship**: `git town propose` → **PR** | **Human gate** (confirm before creating the PR; safety rule) |
| 「別の作業に切り替え」「〜の続きやる」 / "switch to other work", "continue working on ..." | Context switch | switch (as before) | L1 |
| 「研究テーマ A と B を見比べたい」 / "compare research topics A and B side by side" | Parallel reference | multi (as before) | L1 |

Division of judgment: **bookkeeping (sync, cleanup, done detection) runs silently and automatically / structure-creating operations (new epics) are proposals with an adopted interpretation / only irreversible, outward-facing operations (PR, main) go through a human**.
Do not propose an epic for one-off work that does not warrant one (avoid bureaucratizing misfires; when in doubt, use a normal feature branch).

## Proactive parallelism proposal (fan-out Agents vs worktree)

Even when the user does not say "in parallel," if the work decomposes into independent subtasks (**no shared file · no sequential dependency**), proactively propose parallelizing it instead of running serially (an extension of intent-first). Criteria for fan-out Agents (read / independent edits · short-lived · leanest) vs a task worktree (parallel branches · conflicts · long-running), plus the 3-condition divisibility test: [`references/parallel-proposal.md`](references/parallel-proposal.md).

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

Detailed procedures, fallbacks, and safety checks: [`references/git-town-flow.md`](references/git-town-flow.md)

Key points (verified on git-town 23.x):
- **epic**: `git town hack <epic>` (branches off main, parent tracked). Creates the WS (`[feat] <epic>`) at the same time
- **task**: **always on the epic checkout** run `git town append <task>` (it becomes a child of current) → physically separate with `git worktree add ../<repo>-wt-<task> <task>` → start the new session with `claude -w` or in that dir
- **drift propagation**: `git town sync` (epic update → cascades to all tasks; works from inside a worktree too). Run automatically at task session start and before done
- **done**: confirm tests PASS → on the task branch run `git town merge` (merges into the parent epic + auto-deletes the branch) → `git town sync` → worktree remove. **Never use `git town ship`** (main-only; proven to reject stacked children)
- **ship**: `git town propose` (creates the PR; gh fallback available). **PR/main is a human gate** — fires on utterances like 「これで出して」 / "ship it", and confirms once before creating
- **git-town not installed**: graceful degrade (substitute plain git steps + suggest `brew install git-town` once)

## Separation of the 3 layers / directory layout

Details: [`references/architecture.md`](references/architecture.md)

Key points:
- `/ws switch` = full work-context switch (auto branch switch) / `/ws multi` = parallel reference within the same branch / `claude -w` = physical separation (official worktree)
- Directories (new layout): `workspaces/<author>/[scope] topic/{workspace.md, tasks.md, tasks-old/}` (entity) + **lightweight pointer** (per-checkout) + `WORKSPACE-refs.md` (multi mode only)
- **The pointer's real location = the git-dir** (`<git-dir>/banto-ws-pointer.md`; independent per worktree = no current-WS collisions in parallel work). Get the write target with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer-target`; read with `--ws-pointer` (git-dir first → falls back to the store's WORKSPACE.md)
- Derive the author with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author` (do not reimplement)
- **Pointer files (not symlinks)** — lightweight plain-text pointers; no Windows fallback needed
- Legacy (`workspaces/*.md` directly / unmigrated projects) is handled read-compatibly (the hook falls back)

## Scope types

| Type | Switch criterion | Recommended operation |
|---|---|---|
| `[branch]` | when the git branch changes | 1:1 mapping via `/ws switch`, branch auto-switches |
| `[feat]` `[task]` | when the feature/task changes | `/ws switch` with branch split recommended (commit-grained) |
| `[research]` `[experiment]` `[model]` | when the research/experiment topic changes | parallel via `/ws multi` is OK (mostly uncommitted drafts) |
| `[test]` `[training]` | when the test/training run changes | depends on use; mainly `/ws switch` |

Free-form types are also allowed (infra, data, paper, etc.).

## Procedures

User-facing output (messages and listings below): if the user speaks Japanese, respond in Japanese.

### /ws (no arguments) / /ws list: display

`/ws` reads WORKSPACE.md to show the current WS; `/ws list` globs workspaces/ to list active / archived. Concrete Read/Glob steps and display format: [`references/basic-commands.md`](references/basic-commands.md).

### /ws new / /ws archive / /ws import: create / retire / import

Detailed procedure: [`references/new-and-archive.md`](references/new-and-archive.md)

Key points:
- `/ws new`: read config.json → confirm scope + topic → create the entity `workspaces/<author>/[scope] name/{workspace.md, tasks.md(scaffold), tasks-old/}` → write `WORKSPACE.md` as the lightweight pointer
- `/ws archive`: move the entity dir to `workspaces/<author>/old/`, delete WORKSPACE.md
- `/ws import`: pull another WS's related documents in and add them to the 「依存:」 (dependency) field

### /ws switch <name>: switch (with automatic branch switching)

Detailed procedure: [`references/switch-procedure.md`](references/switch-procedure.md)

Main steps:
1. Check for uncommitted changes (abort if any; avoid destructive operations)
2. Rewrite `WORKSPACE.md` as the new WS's lightweight pointer (delete WORKSPACE-refs.md)
3. Auto-switch the branch using the 「ブランチ:」 line of the entity `workspace.md` (git checkout / -b)
4. Read the pointer + entity `workspace.md` + `tasks.md` to inject context
5. Check dependent WS

### /ws multi / /ws solo: parallel multi-WS reference mode

A mode for referencing multiple research topics or experiments on the same branch at once. Detailed procedure: [`references/multi-mode.md`](references/multi-mode.md)

Key points:
- `/ws multi <ws1> <ws2> ...` separates primary (write target) + references (read-only)
- Creates `.ai-context/WORKSPACE-refs.md` to record reference info
- `/ws solo` returns to single mode (deletes refs.md)


## Format specs (lightweight pointer / workspace.md / multi-mode hook)

The lightweight pointer (**inside the git-dir**, WS name + branch + entity path only, independent per worktree) and the workspace.md entity (the 「ブランチ:」 line drives the `/ws switch` auto-switch; the 「## 関連ドキュメント」 section is force-updated by a hook; tasks live in `tasks.md` in the same dir) formats, plus the multi-mode hook integration: [`references/formats.md`](references/formats.md).
