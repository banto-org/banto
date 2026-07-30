# /ws new / /ws archive / /ws import の詳細

> `{base}` = ai-context ベース（store-first、`--resolve` で解決）。
> `<author>` = `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author` で導出。

## /ws new: 新規作成

1. プロジェクトの `{base}/config.json` を Read
2. スコープタイプを確認（default_scope 設定があればそれ、なければ対話）
3. トピック名を確認（英語、ハイフン区切り推奨）
4. **実装 WS か確認**（既定 = 実装。`[design]` 系スコープなど明らかに設計主体なら設計 WS を提案）。worktree 並走の手動起動はフラグなしの素の `claude` を案内する（モデル選定は都度の判断 — 処方的な既定は置かない）
5. 現在 WS がある場合: keep（保存して切替）or archive（`workspaces/<author>/old/` に移動）を選択
6. 実体 dir `{base}/workspaces/<author>/[scope] topic-name/` を作成し、`workspace.md` と `tasks.md`（雛形）を書く:

```markdown
<!-- workspace.md -->
# Workspace: [scope] topic-name

ブランチ: {git branch --show-current}
依存: (なし)

## 関連ドキュメント
(なし)
```

```markdown
<!-- tasks.md（雛形） -->
# Tasks — [scope] topic-name

- [ ] （最初のタスクをここに）
```

`tasks-old/` も `mkdir -p` で用意する。

7. **軽量ポインタ**を書く（symlink 廃止・プレーンファイル）。書き込み先は git-dir
   （per-checkout・並走独立）: `PTR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer-target)` に Write:

```markdown
# Workspace: [scope] topic-name

ブランチ: {git branch --show-current}
実体: workspaces/<author>/[scope] topic-name/workspace.md

<!-- per-checkout ローカルポインタ。作業文脈は上記の実体 workspace.md を Read すること -->
```

`WORKSPACE-refs.md` が残っていれば削除（single モードへ）。

8. 初回のみ `$CLAUDE_PLUGIN_ROOT/templates/workspace-rule.md` を `.claude/rules/workspace.md` へコピーして生成（workspace ルールの正本テンプレート）。

## /ws archive: アーカイブ

1. 現在の WS 名を特定: 実効ポインタ（`<git-dir>/banto-ws-pointer.md`、非 git は `{base}/WORKSPACE.md`）の先頭行 `# Workspace: [scope] name` から抽出（ポインタはプレーンファイル。readlink は不要＝symlink 廃止）
2. 実体 dir `workspaces/<author>/[scope] name/` を `workspaces/<author>/old/[scope] name/` へ移動（store 内なので `mv`。tasks.md / tasks-old/ ごと移る）
3. 実効ポインタ（`<git-dir>/banto-ws-pointer.md`、非 git は `WORKSPACE.md`）および `WORKSPACE-refs.md`（あれば）を削除
4. 「アーカイブしました。/ws new で新規作成できます」

## /ws import <名前>: インポート

1. 指定 WS の関連ドキュメントを読む
2. 現在の WS の関連ドキュメントに追加するか対話的に確認
3. 依存欄に追加
