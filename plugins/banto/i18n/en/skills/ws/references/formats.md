# ws format specs — lightweight pointer / workspace.md / multi-mode hook

## Lightweight pointer format

per-checkout (**inside the git-dir** = not committed, independent per worktree). Get the location with `--ws-pointer-target`. Holds **only the WS name + branch + entity path**:

```markdown
# Workspace: [scope] topic-name

ブランチ: feature/api-redesign
実体: workspaces/<author>/[scope] topic-name/workspace.md

<!-- per-checkout local pointer. Read the entity workspace.md above for the work context -->
```

## workspace.md (entity) format

```markdown
# Workspace: [scope] topic-name

ブランチ: feature/api-redesign
依存: [research] topic-b

## 関連ドキュメント
- decisions/2026-04-07_topic-b-breakthrough.md
- docs/research/topic-b-training-cost.md
```

- Do not write a work summary (it drifts)
- Related documents (the 「## 関連ドキュメント」 section) are force-updated by a hook (write on the entity side)
- The 「ブランチ:」 line drives the `/ws switch` auto branch switch (skipped for shared names like main). It exists in both the pointer and the entity and is synced on switch
- Tasks live in `tasks.md` in the same dir (equivalent to the old `tasks/active.md`); Phase archives go to `tasks-old/`

## multi-mode hook integration

Detailed notes: see the end of [`multi-mode.md`](multi-mode.md).
