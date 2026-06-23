# /ws switch <名前>: 切り替え（branch 自動切替付き）

## Step 1: 未コミット変更のチェック（**必須**）

```bash
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "⚠ 未コミットの変更があります。"
    echo "  以下のいずれかを実施してから /ws switch を再実行してください:"
    echo "  - git commit（コミットする）"
    echo "  - git stash（退避する）"
    echo "  - git checkout .（破棄する、destructive）"
    exit 1
fi
```

→ 未コミット時は**中止**（destructive 回避）。ユーザー判断を仰ぐ。

## Step 2: 軽量ポインタを書き換え

symlink は廃止（B2、設計判断済み）。
書き込み先は **git-dir ポインタ**（per-checkout・並走 worktree で独立）:
`PTR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer-target)`。
切替先 WS の実体 `workspace.md` から「ブランチ:」を読み、`$PTR` に**プレーンファイルとして Write**:

```markdown
# Workspace: [scope] new-topic

ブランチ: {実体 workspace.md の「ブランチ:」}
実体: workspaces/<author>/[scope] new-topic/workspace.md

<!-- per-checkout ローカルポインタ。作業文脈は上記の実体 workspace.md を Read すること -->
```

multi モードから切替える場合、`WORKSPACE-refs.md` も削除（single モードに戻す）。
プレーンファイルなので Windows fallback は不要。

**legacy 構成**（`workspaces/*.md` 直下の未移行案件）では従来どおり実体 `.md` をコピーして WORKSPACE.md にする。

## Step 3: 新 WS の「ブランチ:」行を読んで branch 自動切替

```bash
PTR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer)
target_branch=$(grep -m1 '^ブランチ:' "$PTR" | sed 's/^ブランチ:\s*//')
current_branch=$(git branch --show-current 2>/dev/null)

if [ -n "$target_branch" ] && [ "$target_branch" != "$current_branch" ]; then
    # 既存ブランチに切替、なければ新規作成
    if git show-ref --verify --quiet "refs/heads/$target_branch"; then
        git checkout "$target_branch"
    else
        git checkout -b "$target_branch"
    fi
fi
```

- 既存ブランチ → `git checkout`
- 未作成 → `git checkout -b`
- WORKSPACE.md に「ブランチ:」行がない / main 等の共通ブランチ指定時はスキップ

## Step 4: 新 WS をコンテキストに反映（**必須**）

```
Read($PTR)                                                              # ポインタ（--ws-pointer）
Read("workspaces/<author>/[scope] new-topic/workspace.md")              # 実体（関連doc/依存）
Read("workspaces/<author>/[scope] new-topic/tasks.md")                  # この WS のタスク
```

書換え直後のファイルは Claude の自動注入には入らないため、必ず明示 Read（タスクごと文脈が切り替わる）。

## Step 5: 依存 WS の確認（あれば）

「依存 WS `[research] topic-a` から引き継ぐファイルがあります。確認しますか？」
