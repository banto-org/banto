# Workspace ルール

## 話題切替の自律検出

ユーザーの発言が現在のワークスペース（WORKSPACE.md の `# Workspace: [scope] topic` 行）のスコープから明確に外れた場合:

1. 既存の `.ai-context/workspaces/` に該当するWSがあるか確認（`Glob`）
2. ある → 「{WS名} に切り替えますか？」と提案（`/ws switch` を案内）
3. ない → 「新しいワークスペース `[scope] new-topic` を作りますか？」と提案（`/ws new` を案内）
4. 判断に迷う場合はスキップ（偽陽性を避ける）

## 関連ドキュメントの自動更新

`.ai-context/decisions/` や `.ai-context/docs/` に**新しいファイルを作成**した場合:

1. 現在のWSのスコープに関連しているか判断
2. 関連 → WORKSPACE.md の「## 関連ドキュメント」欄に追加を提案
3. 無関係 → 追加しない
4. PostToolUse hook から「WORKSPACE.md に未登録」と通知されたら add/replace/skip のいずれかを判断

## セッションライフサイクル

- **セッション開始時**（SessionStart hook 経由）: 注入された WORKSPACE.md の内容を把握し、以後の作業に反映
- **/ws switch 後**: 新しい WORKSPACE.md を必ず `Read` でコンテキストに取り込む
- **clear/compact 時**: WSの「継続/アーカイブ」を理由付きで推奨

## 禁止

- WORKSPACE.md のフォーマット（`# Workspace: [scope] topic` / `ブランチ:` / `依存:` / `## 関連ドキュメント`）を壊さない
- スコープ外のファイル参照を勝手に追加しない
