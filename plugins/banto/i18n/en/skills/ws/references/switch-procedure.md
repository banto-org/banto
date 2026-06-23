# /ws switch <name>: switch (with automatic branch switching)

## Step 1: check for uncommitted changes (**mandatory**)

```bash
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "⚠ There are uncommitted changes."
    echo "  Do one of the following, then re-run /ws switch:"
    echo "  - git commit (commit them)"
    echo "  - git stash (stash them away)"
    echo "  - git checkout . (discard them, destructive)"
    exit 1
fi
```

→ When there are uncommitted changes, **abort** (avoid destructive). Defer to user judgment.

## Step 2: rewrite the lightweight pointer

Symlinks are abolished (B2, design decision made).
The write target is the **git-dir pointer** (per-checkout, independent across parallel worktrees):
`PTR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer-target)`.
Read the 「ブランチ:」 from the target WS's entity `workspace.md`, and **Write it to `$PTR` as a plain file**:

```markdown
# Workspace: [scope] new-topic

ブランチ: {the 「ブランチ:」 from the entity workspace.md}
実体: workspaces/<author>/[scope] new-topic/workspace.md

<!-- per-checkout local pointer. Read the entity workspace.md above for the work context -->
```

When switching from multi mode, also delete `WORKSPACE-refs.md` (back to single mode).
Being a plain file, no Windows fallback is needed.

**legacy layout** (unmigrated projects directly under `workspaces/*.md`): copy the entity `.md` as before and make it WORKSPACE.md.

## Step 3: read the new WS's 「ブランチ:」 line and auto-switch the branch

```bash
PTR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer)
target_branch=$(grep -m1 '^ブランチ:' "$PTR" | sed 's/^ブランチ:\s*//')
current_branch=$(git branch --show-current 2>/dev/null)

if [ -n "$target_branch" ] && [ "$target_branch" != "$current_branch" ]; then
    # switch to the existing branch, or create it if absent
    if git show-ref --verify --quiet "refs/heads/$target_branch"; then
        git checkout "$target_branch"
    else
        git checkout -b "$target_branch"
    fi
fi
```

- existing branch → `git checkout`
- not yet created → `git checkout -b`
- skip when WORKSPACE.md has no 「ブランチ:」 line / when a shared branch like main is specified

## Step 4: reflect the new WS into context (**mandatory**)

```
Read($PTR)                                                              # pointer (--ws-pointer)
Read("workspaces/<author>/[scope] new-topic/workspace.md")              # 実体（関連doc/依存）
Read("workspaces/<author>/[scope] new-topic/tasks.md")                  # this WS's tasks
```

Files just rewritten are not picked up by Claude's auto-injection, so always Read them explicitly (the context switches per task).

## Step 5: check dependent WS (if any)

"There are files to carry over from the dependent WS `[research] topic-a`. Do you want to check?"
