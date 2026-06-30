# /ws new / /ws archive / /ws import の詳細

> `{base}` = ai-context ベース（store-first、`--resolve` で解決）。
> `<author>` = `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author` で導出。

## /ws new: 新規作成

1. プロジェクトの `{base}/config.json` を Read
2. スコープタイプを確認（default_scope 設定があればそれ、なければ対話）
3. トピック名を確認（英語、ハイフン区切り推奨）
4. 現在 WS がある場合: keep（保存して切替）or archive（`workspaces/<author>/old/` に移動）を選択
5. 実体 dir `{base}/workspaces/<author>/[scope] topic-name/` を作成し、`workspace.md` と `tasks.md`（雛形）を書く:

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

6. **軽量ポインタ**を書く（symlink 廃止・プレーンファイル）。書き込み先は git-dir
   （per-checkout・並走独立）: `PTR=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer-target)` に Write:

```markdown
# Workspace: [scope] topic-name

ブランチ: {git branch --show-current}
実体: workspaces/<author>/[scope] topic-name/workspace.md

<!-- per-checkout ローカルポインタ。作業文脈は上記の実体 workspace.md を Read すること -->
```

`WORKSPACE-refs.md` が残っていれば削除（single モードへ）。

7. 初回のみ `.claude/rules/workspace.md` を生成（workspace ルール、本スキル末尾参照）。

## /ws archive: アーカイブ

1. 現在の WS 名を特定: `head -1 {base}/WORKSPACE.md` の `# Workspace: [scope] name` から抽出（ポインタはプレーンファイル。readlink は不要＝symlink 廃止）
2. 実体 dir `workspaces/<author>/[scope] name/` を `workspaces/<author>/old/[scope] name/` へ移動（store 内なので `mv`。tasks.md / tasks-old/ ごと移る）
3. `WORKSPACE.md` および `WORKSPACE-refs.md`（あれば）を削除
4. 「アーカイブしました。/ws new で新規作成できます」

## /ws import <名前>: インポート

1. 指定 WS の関連ドキュメントを読む
2. 現在の WS の関連ドキュメントに追加するか対話的に確認
3. 依存欄に追加
