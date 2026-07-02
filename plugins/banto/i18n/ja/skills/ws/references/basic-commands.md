# ws 基本コマンド手順 — /ws / /ws list

ユーザー向け出力（メッセージや一覧）: ユーザーが日本語で話していれば日本語で応答する。

## /ws（引数なし）: 現在の WS を表示

```
Read("<git-dir>/banto-ws-pointer.md")   # 実効ポインタ（非 git 環境は {base}/WORKSPACE.md に fallback）
# in multi mode also read WORKSPACE-refs.md
Read("{base}/WORKSPACE-refs.md")  # only when the file exists
```

なければ: "No workspace is set up. You can create one with /ws new."

## /ws list: 全 WS の一覧

```bash
AUTHOR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author)
```
```
Glob("{base}/workspaces/<AUTHOR>/*/workspace.md")      # new layout (active)
Glob("{base}/workspaces/<AUTHOR>/old/*/workspace.md")  # new layout (archived)
# legacy (unmigrated projects only): Glob(".ai-context/workspaces/*.md")
```

表示（multi モードでは primary / references を明示）:
```markdown
## Active
- [research] topic-a (primary, current)
- [model] example-model-24b (reference, multi mode)
- [task] api-design

## Archived
- [research] topic-b (2026-04-08)
```
