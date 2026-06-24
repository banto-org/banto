# ws basic commands — /ws / /ws list

User-facing output (messages and lists): if the user is speaking Japanese, respond in Japanese.

## /ws (no arguments): show the current WS

```
Read("{base}/WORKSPACE.md")
# in multi mode also read WORKSPACE-refs.md
Read("{base}/WORKSPACE-refs.md")  # only when the file exists
```

If none: "No workspace is set up. You can create one with /ws new."

## /ws list: list all WSs

```bash
AUTHOR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author)
```
```
Glob("{base}/workspaces/<AUTHOR>/*/workspace.md")      # new layout (active)
Glob("{base}/workspaces/<AUTHOR>/old/*/workspace.md")  # new layout (archived)
# legacy (unmigrated projects only): Glob(".ai-context/workspaces/*.md")
```

Display (in multi mode, make primary / references explicit):
```markdown
## Active
- [research] topic-a (primary, current)
- [model] example-model-24b (reference, multi mode)
- [task] api-design

## Archived
- [research] topic-b (2026-04-08)
```
