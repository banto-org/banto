# ws 形式仕様 — 軽量ポインタ / workspace.md / multi hook

## 軽量ポインタ形式

per-checkout（**git-dir 内** = コミットされない、worktree ごとに独立）。場所は `--ws-pointer-target` で取得。**WS 名 + ブランチ + 実体パスのみ**を持つ:

```markdown
# Workspace: [scope] topic-name

ブランチ: feature/api-redesign
実体: workspaces/<author>/[scope] topic-name/workspace.md

<!-- per-checkout ローカルポインタ。作業文脈は上記の実体 workspace.md を Read すること -->
```

## workspace.md（実体）形式

```markdown
# Workspace: [scope] topic-name

ブランチ: feature/api-redesign
依存: [research] topic-b

## 関連ドキュメント
- decisions/2026-04-07_topic-b-breakthrough.md
- docs/research/topic-b-training-cost.md
```

- 作業サマリは書かない（drift する）
- 関連ドキュメント（「## 関連ドキュメント」 セクション）は hook が強制更新する（実体側に書く）
- 「ブランチ:」 行は `/ws switch` の自動ブランチ切替を駆動する（main などの共有名ではスキップ）。ポインタと実体の両方に存在し、switch 時に同期される
- タスクは同一 dir の `tasks.md` に置く（旧 `tasks/active.md` 相当）；Phase アーカイブは `tasks-old/` へ

## multi モードの hook 連携

詳細メモ: [`multi-mode.md`](multi-mode.md) の末尾を参照。
