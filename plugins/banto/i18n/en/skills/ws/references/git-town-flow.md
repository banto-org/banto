# git-town flow — detailed procedure for 3-tier operation (epic / task / done / ship)

> Design: a thin wrapper over git-town + `claude -w`. Commands = aliases, natural language = the main path (intent-first. design decision made).
> Command semantics are **verified on real hardware with Git Town 23.0.2** (2026-06-10).

## Prerequisite check (once at the start of every operation)

```bash
command -v git-town >/dev/null 2>&1 && echo "git-town present" || echo "git-town absent"
# if the main branch is not configured, set it non-interactively
git config git-town.main-branch >/dev/null 2>&1 || git config git-town.main-branch "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main)"
```

When git-town is **not present**: use each operation's "fallback", and only on the first time
guide once with "Installing `brew install git-town` enables auto-propagation (sync) of epic updates to all tasks" (do not repeat it every time).

## epic — create the large-scope branch (L2: proposal with adopted interpretation)

Utterance examples: "start the payment redesign", "go into a bigger piece of work"

1. **Misfire guard**: do not propose an epic for a single small task. Rule of thumb — it splits into multiple independent subtasks / takes more than a few days / parallel work is expected. When in doubt, start with a normal feature branch and propose promotion later.
2. uncommitted changes check (if any, abort and report)
3. Create the branch: `git town hack <epic-name>` (branches off main, parent=main is recorded)
   - fallback: `git checkout main && git pull && git checkout -b <epic-name>`
4. Create the WS entity (same procedure as `/ws new`. scope defaults to `[feat]`) + update the pointer
5. Report: "Cut the epic `<name>` (adopted interpretation: XX. can roll back if unneeded)"

## task — carve out the small-scope worktree (self-driving once the epic is established)

Utterance examples: "do the API in parallel", "put this in a separate worktree"

1. **Always run on the epic checkout** (`git town append` creates **a child of current**. confirmed on real hardware).
   If not currently on the epic, `git checkout <epic>` first, then:
   ```bash
   git town append <task-name>          # create as a child of the epic (parent=epic is recorded)
   git checkout <epic>                  # return to the epic (free up task for worktree add)
   git worktree add "../$(basename "$PWD")-wt-<task-name>" <task-name>
   ```
   - fallback: `git checkout -b <task-name> <epic>` + the same worktree add (no parent tracking = no sync, manual rebase)
2. Guidance: "Physically separated to `../<repo>-wt-<task>`. By default banto drives the execution (independent, non-conflicting → fan-out Agent; otherwise this session advances the worktree's work). Only when genuinely independent, long-running parallel work is needed is there an option to manually start plain `claude` there (do not use `claude -w` for this — it creates a separate ad-hoc worktree outside the task hierarchy)". If you choose manual startup, plain `claude` with no flag is the default (model selection is a per-case judgment — no prescriptive default)
3. When running in parallel it is automatically listed in the session-registry / fleet dashboard (P4 core). Same-branch collisions are warned as pending

## sync — drift propagation (bookkeeping: silently automatic)

- **When**: at the start of a task session / right before done / after a direct commit lands on the epic
- **What**: `git town sync` (epic→all tasks cascade propagation. **proven to work from inside a worktree too**)
- If a conflict appears, stop and report (do not auto-resolve)
- fallback (no git-town): sync is unavailable. Manually sync the epic's updates from inside the task worktree with `git merge <epic>` (or `git rebase <epic>`). State once, the first time only, that this is expected degraded behavior, not an error (don't repeat it every time)

## done — finish a small scope (L3: auto-execute, report only)

Utterance examples: "this work is done", "task complete" / propose it when detecting that all items in tasks.md are checked

1. Run tests → confirm PASS (if FAIL, abort done and report. consecutive failures stop the loop via the TF counter)
2. **Parent check (safety check, mandatory)**: verify the merge target is the intended epic
   ```bash
   git config "git-town-branch.$(git branch --show-current).parent"   # → should be the epic name
   ```
   If the parent is main or another branch, **abort and report** (the append may have been issued in the wrong place)
   - If the parent config is empty (git-town absent, or the branch was created with plain git): skip this git-town-dependent check and substitute a verbal confirmation of the current branch's fork point instead (do not misread empty as a "parent mismatch" and abort)
3. On the task branch: `git town merge` (**merges into the parent epic + auto-deletes the task branch**. proven.
   Do not use `git town ship` — it is main-only and on stacked children it rejects with "ship the parent too")
   - The merge method is the tool default (usually merge). Only when a squash is needed, do it manually with `git checkout <epic> && git merge --squash <task>`
   - fallback (no git-town): `git checkout <epic> && git merge <task> && git branch -d <task>`
4. Propagate to other tasks with `git town sync` → clean up the worktree:
   ```bash
   git worktree remove "../<repo>-wt-<task>" 2>/dev/null || git worktree prune
   ```
5. Report only: "Merged `<task>` into the epic and cleaned up the worktree. Remaining tasks: …"

## ship — epic → main (human gate: confirm once before creating the PR)

Utterance examples: "put it into main", "release it", "ship it"

1. Confirm all tasks are done (if any remain, enumerate and confirm)
2. `git town sync` → confirm the full test suite PASSes
3. **Confirmation (the only human gate)**: "I will create the PR for epic `<name>` → main. OK?"
4. `git town propose` (if forge is unconfigured, fallback: `gh pr create --base main --head <epic>`)
5. Direct push to main is blocked by odd-kill-switch (a structural gate that cannot be escaped). The dev/stg CI gates are delegated to the PR-side pipeline

## Troubleshooting

| Symptom | Cause | Remedy |
|---|---|---|
| `git town merge` heads for main | append was issued on main (parent=main) | detected by the parent check in done step 2 → re-point with `git town set-parent` |
| `ship would ship epic as well` | used `git town ship` on a stacked child | by design. use `git town merge` |
| conflict during sync | epic and task edited the same file | report without auto-resolving. recommend a file-ownership mapping in AGENTS.md |
| worktree cannot be removed | uncommitted changes remain | report the contents and leave it to the user (do not force) |

## Practical ceilings / known caveats

- Parallel worktrees have a practical ceiling of 4–8
- Long-lived epics should rebase + sync onto main on a 1–2 week cycle
- Agent `isolation: worktree` (subagent worktree) is still unstable — verify important tasks manually
