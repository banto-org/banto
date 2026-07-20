# Workspace ルール

## 話題切替の自律検出

ユーザーの発言が現在のワークスペース（WORKSPACE.md の `# Workspace: [scope] topic` 行）のスコープから明確に外れた場合:

1. 既存の `{base}/workspaces/` に該当するWSがあるか確認（`Glob`）
2. ある → 「{WS名} に切り替えますか？」と提案（`/ws switch` を案内）
3. ない → 「新しいワークスペース `[scope] new-topic` を作りますか？」と提案（`/ws new` を案内）
4. 判断に迷う場合はスキップ（偽陽性を避ける）

## 関連ドキュメントの自動更新

`{base}/decisions/` や `{base}/docs/` に**新しいファイルを作成**した場合:

1. 現在のWSのスコープに関連しているか判断
2. 関連 → WORKSPACE.md の「## 関連ドキュメント」欄に追加を提案
3. 無関係 → 追加しない
4. PostToolUse hook から「WORKSPACE.md に未登録」と通知されたら add/replace/skip のいずれかを判断

## 鮮度の維持（打ち消し線ルール）

新しい decision / spec の保存で、現在の workspace.md 本文（目的・方針・メモ・関連ドキュメントの説明）に**古くなった記述**が生じた場合:

1. 古い行は削除せず `~~打ち消し線~~` にし、直後に `→ 最新: {新ファイルの相対パス}（YYYY-MM-DD）` を追記する
2. 対象は新しい decision / spec と**矛盾する行だけ**（無関係な行に触らない）
3. PostToolUse hook の「[Workspace freshness]」通知が来たら、この手順で workspace.md を見直す

## セッションライフサイクル

- **セッション開始時**（SessionStart hook 経由）: 注入された WORKSPACE.md の内容を把握し、以後の作業に反映
- **/ws switch 後**: 新しい WORKSPACE.md を必ず `Read` でコンテキストに取り込む
- **clear/compact 時**: WSの「継続/アーカイブ」を理由付きで推奨

## 禁止

- WORKSPACE.md のフォーマット（`# Workspace: [scope] topic` / `ブランチ:` / `依存:` / `## 関連ドキュメント`）を壊さない
- スコープ外のファイル参照を勝手に追加しない
