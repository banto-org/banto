# Separation of the 3 layers / directory layout

## Separation of the 3 layers

| Feature | Purpose | Directory | Branch | WORKSPACE.md |
|---|---|---|---|---|
| `/ws switch <name>` | **Full work-context switch** (commit-grained heavy work) | same | **auto-switch** (follows the 「ブランチ:」 in workspace.md) | rewrite the lightweight pointer (single) |
| `/ws multi <ws1> <ws2>` | **Parallel reference within the same branch** (research/experiment etc., mostly uncommitted drafts) | same | not switched | one primary + reference in `WORKSPACE-refs.md` |
| `claude -w <name>` | **Physical separation** (separate directory, separate process) | separate | auto `worktree-<name>` | Claude Code official feature, banto stays out |

## Directory layout (new layout)

```
{base}/                            (store: ~/ai-context-store/<project>/ or ~/ai-context-local/<project>/)
├── WORKSPACE.md                   ← lightweight pointer (per-checkout local, gitignore. WS name + branch + entity path)
├── WORKSPACE-refs.md              ← exists only during /ws multi (list of reference WS, local)
├── DASHBOARD.md                   ← hook-managed bird's-eye view (local, gitignore)
└── workspaces/
    └── <author>/                  ← member namespace (derived with --author)
        ├── [research] topic-b/
        │   ├── workspace.md       ← definition (branch/dependency/related docs. shared in the store)
        │   ├── tasks.md           ← this WS's active tasks (equivalent to the old tasks/active.md)
        │   └── tasks-old/         ← Phase archive (equivalent to the old tasks/old)
        ├── [task] api-design/
        └── old/                   ← completed WS (cold memory)
```

**Design principle (B2)**: `WORKSPACE.md` is **a lightweight pointer (plain file), not a symlink**. The central store sits outside cwd and a relative symlink breaks across worktrees, so symlinks were abolished (design decision made). Being a plain file, **no Windows fallback is needed** either.

**legacy compatibility**: unmigrated projects stay directly under `workspaces/*.md` (old layout). The hook keeps them non-destructively via read fallback, and this skill too operates on the legacy paths when it detects the legacy layout.
