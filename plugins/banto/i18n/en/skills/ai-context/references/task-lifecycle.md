# Task lifecycle (next / phase-done / auto-archive / split)

## The always-update duty (task mirror)

tasks.md (the store canon) and the built-in task UI (TaskCreate / TaskUpdate) are **both updated every time work moves**. The moment SessionStart injects tasks.md, create UI tasks via TaskCreate for any open item this session will touch. Three operating rules:

1. **On start**: locate the item in tasks.md and set the UI task to in_progress
2. **On completion**: check the item off in tasks.md (`- [x]`) and set the UI task to completed — never finish only one side
3. **A new request (implementation or investigation alike; includes deferred/additional instructions like "also", "and", "later")**: when asked for work that is not in tasks.md, append it to tasks.md first as `- [ ] {concise task}`, then start (the record lives in the current workspace's tasks.md; if the topic falls outside the workspace's scope, propose /ws switch / new first). Do not task-ify questions, chit-chat, or immediate trivial edits. The `task-router.sh` UserPromptSubmit hook nudges this entry per-prompt (nudge only, not enforced)


<!-- merged from next.md -->
## next — task navigator (merged the former sdd-core skill)

Identify the next incomplete task from the effective tasks file (`workspaces/<author>/<topic>/tasks.md`), gather context, and carry it through to implementation and verification.

Invocation: `/ai-context next`, or ai-context fires on natural language like "continue", "next", "next task", "go ahead" and enters this procedure.

## Finding the task file

The search order, the rule of respecting the project's main files, and the new-creation decision follow SKILL.md "Task management rules" (single source of truth). Summary:

1. Respect the project's existing `tasks.md` / `TODO.md` / `ROADMAP.md` if present
2. Otherwise use / create the current WS's `tasks.md` (`workspaces/<author>/<topic>/tasks.md`) — legacy `{base}/tasks/active.md` is a read fallback only, never auto-created

## Navigation flow

### 1. Identify the task

Read the task file and find the first incomplete `- [ ]`. Confirm the dependency tasks (`deps:`) are complete.

### 2. Gather context (run in parallel)

Run the following **in parallel with the Agent tool**:

- Search for related past design decisions with the search skill (`/search <query>`) (Claude expands the query → grep scoring → Read verification)
- Confirm related design documents if any
- Grasp the current state of the target code (symbol overview / find symbol, etc.)

### 3. Present the task information

```markdown
## Next task: T{X.Y} — {task name}

**Phase**: Phase {X}: {Phase name}
**Deps**: {state of the dependency tasks}

### Related context
- past decisions: {summary of the search skill's results}

### Implementation target
- {target files, related components}
```

### 4. Implement

- Modify existing code → symbol-level editing (Serena, etc.)
- Create a new file → Write tool
- If there are tests, run them to confirm

### 5. Completion handling

- Update the task file to `- [x]`
- Update the Phase progress counter `[completed/total]`

### 6. Archive on Phase completion

The naming rule and the archive procedure follow SKILL.md "Auto-archive when all tasks are complete" + this document's "Auto-archive when all tasks are complete" section. `/ai-context phase-done` is performed with verification by this document's "phase-done" section.

## Task format

```markdown
## Phase 1: Environment setup [2/5]

- [x] T1.1: Next.js init | deps: none
- [x] T1.2: install packages | deps: T1.1
- [ ] T1.3: Tailwind setup | deps: T1.2  ← next is here
- [ ] T1.4: Supabase setup | deps: T1.2
- [ ] T1.5: environment variables | deps: T1.3, T1.4
```

## Commit convention

```
<type>(<scope>): <subject>
type: feat, fix, docs, style, refactor, test, chore
scope: feature name or Phase number
subject: include the Task ID
```

Example: `feat(diagnosis): Task 4.2 implement QuestionCard`

<!-- merged from phase-done.md -->
## phase-done — Phase completion check (merged the former phase-done skill)

Confirm whether the current Phase is complete, verify it, and get ready to proceed to the next Phase.

Invocation: `/ai-context phase-done [Phase number]` (explicit). When omitted, the latest Phase in the effective tasks file (tasks.md).

## Execution procedure

### 1. Completion confirmation

Confirm all tasks of the current Phase are `- [x]`. Location of the task file:
- new layout: `{base}/workspaces/<author>/<topic>/tasks.md` (the path under SessionStart's "tasks in progress" heading)
- legacy: `{base}/tasks/active.md` (`{base}` is resolved for central/legacy)
- `tasks.md` / `TODO.md` / `ROADMAP.md` (project-specific)

If there are incomplete tasks, list them and confirm with the user.

### 2. Build / test verification

```bash
npm run build && npm run lint && npm test   # ← one example. The actual PM is project-dependent
```

Following the `dependencies` rule, substitute the PM indicated by the project's manifest / lockfile (Node = the PM the lockfile indicates / Flutter = flutter test / Rust = cargo test, etc.).

### 3. E2E tests

Run E2E tests with the qa-tester agent (launch it directly with `Agent(subagent_type="qa-tester", ...)`). Only when there is UI / API whose behavior needs confirming.

### 4. Result judgment

- All pass → "Phase X complete. Ready to proceed to Phase X+1"
- Failures present → report the error content and propose fixes

### 5. Archive the completed Phase (when using the effective tasks file)

Move the completed Phase aside as `YYYY-MM-DD_phase{N}-{name}.md` (new layout → the same WS's `tasks-old/`, legacy → `{base}/tasks/old/`):

1. Extract the completed Phase portion
2. Save it to the destination directory
3. Delete that Phase portion from the tasks file

(Follows the naming rule of this document's "Auto-archive when all tasks are complete" section. The hook may detect full completion and guide this procedure.)

Note: the search layer is auto-regenerated by the hook (no manual step).

## Related

- Running the next task is `/ai-context next` (this document's "next" section)
- A normal completion mark is simply marking `- [x]` (this subcommand is unnecessary)
- E2E tests are the qa-tester agent (launched directly)

<!-- merged from auto-archive.md -->
## Auto-archive when all tasks are complete

When all tasks in the effective tasks file (new layout `workspaces/<author>/<topic>/tasks.md`, legacy is `tasks/active.md`) are complete (`- [ ]` is 0 and `- [x]` is 1 or more), the hook auto-detects it and prompts an archive. **The hook notification includes the destination path** — follow it.

## Archive procedure (the AI executes upon the hook notification)

1. Extract the Phase name from the leading `## Phase:` or `# Phase:` of the tasks file
2. Destination file name: `YYYY-MM-DD_{phase-name}.md`
   - Destination dir: new layout → the same WS's `tasks-old/`, legacy → `tasks/old/` (use the path in the hook notification)
   - `{phase-name}` = Phase name (spaces → hyphens, up to 40 chars)
   - Example: `2026-04-08_plugin-best-practice-conformance.md`
3. Move the tasks file to the destination with `git mv` (within the store use `mv`)
4. Create a new tasks file or replace it with the template for the next Phase
5. Report completion to the user + confirm the next work

## Strictly follow the naming rule

- Date prefix is mandatory (for chronological sorting)
- The Phase name is extracted from the header inside the tasks file (do not name it manually)
- The extension is `.md`

When existing project files (`tasks.md`, `TODO.md`, etc.) are in use, do not archive (respect the project's management rules).

<!-- merged from tasks-split.md -->
## tasks split subcommand

Split the effective tasks file by Phase and archive completed Phases.
The target is `workspaces/<author>/<topic>/tasks.md` for the new layout (destination `tasks-old/`),
or `tasks/active.md` for legacy (destination `tasks/old/`). The path under SessionStart's "tasks in progress" heading is the effective file.

## Execution procedure

1. Read the effective tasks file
2. Split into Phases by the `## Phase:` or `# Phase:` line
3. For each Phase:
   - All tasks `- [x]` complete → archive candidate at `YYYY-MM-DD_{phase-slug}.md` in the destination dir
   - Partially complete → confirm in text "in progress, archive it?"
   - Not started → leave it in the tasks file as-is
4. After user approval, archive with `git mv` or `mv`
5. Rebuild the tasks file (only the remaining Phases)

## Arguments

- no argument → interactively confirm each Phase
- `--auto` → auto-archive only completed Phases (don't touch incomplete ones)
- `--phase <name>` → operate only on a specific Phase

