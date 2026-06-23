# Details of /ws new / /ws archive / /ws import

> `<base>` = the ai-context base (store-first, resolved with `--resolve`).
> `<author>` = derived with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author`.

## /ws new: create a new one

1. Read the project's `<base>/config.json`
2. Confirm the scope type (use default_scope if set, otherwise dialogue)
3. Confirm the topic name (English, hyphen-separated recommended)
4. If a current WS exists: choose keep (save and switch) or archive (move to `workspaces/<author>/old/`)
5. Create the entity dir `<base>/workspaces/<author>/[scope] topic-name/` and write `workspace.md` and `tasks.md` (scaffold):

```markdown
<!-- workspace.md -->
# Workspace: [scope] topic-name

ブランチ: {git branch --show-current}
依存: (none)

## 関連ドキュメント
(none)
```

```markdown
<!-- tasks.md（雛形） -->
# Tasks — [scope] topic-name

- [ ] (first task goes here)
```

Also prepare `tasks-old/` with `mkdir -p`.

6. Write the **lightweight pointer** (symlink abolished, plain file). The write target is the git-dir
   (per-checkout, independent across parallel work): Write to `PTR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer-target)`:

```markdown
# Workspace: [scope] topic-name

ブランチ: {git branch --show-current}
実体: workspaces/<author>/[scope] topic-name/workspace.md

<!-- per-checkout local pointer. Read the entity workspace.md above for the work context -->
```

If `WORKSPACE-refs.md` remains, delete it (back to single mode).

7. Only on the first time, generate `.claude/rules/workspace.md` (the workspace rule, see the end of this skill).

## /ws archive: archive

1. Identify the current WS name: extract from `# Workspace: [scope] name` of `head -1 <base>/WORKSPACE.md` (the pointer is a plain file. readlink is unneeded = symlink abolished)
2. Move the entity dir `workspaces/<author>/[scope] name/` to `workspaces/<author>/old/[scope] name/` (within the store, so `mv`. moves along with tasks.md / tasks-old/)
3. Delete `WORKSPACE.md` and `WORKSPACE-refs.md` (if any)
4. "Archived. You can create a new one with /ws new"

## /ws import <name>: import

1. Read the related documents of the specified WS
2. Confirm interactively whether to add them to the current WS's related documents
3. Add to the dependency field
