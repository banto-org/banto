---
name: ws
description: |
  3 階層ブランチモデル（main ← epic ← task worktree）のための Workspace + git-town オーケストレータ。切替・並走・スコープ切り出し・完了マージ・main への ship をインテント検出で駆動する（worktree 分離 → git worktree / `claude -w`；ブランチ階層 + drift → git-town）。
  トリガー: 「ワークスペース」「作業切り替え」「並走」「ブランチ分けて」「worktree」「epic」「この作業終わった」「マージして」「リリースして」「出して」
  使わない場面: 現在ブランチ上の小さな単発編集（普通に編集してコミットするだけ）。「同時に」/「並行で」だけでいま並列にタスクを走らせたい場合は、新しい workspace/worktree ではなく自走の並列 Agent（1 メッセージに複数 Agent 呼び出し）を意味する。active.md/tasks.md の次の作業項目を進めるのは本 skill ではなく `ai-context`。
allowed-tools: Read Write Edit Glob Grep Bash
user-invocable: true
argument-hint: "[switch|new|multi|solo|archive|import|epic|task|done|ship|list]（省略時は会話から意図を自動判定）"
compatibility: Claude Code (requires bash, git, jq; git-town 推奨)
---

# Workspace Manager

> **保存ベース（store-first）**: `workspaces/...` を含む保存先はすべて `{base}` 配下。`{base}` は SessionStart/PreCompact hook が注入する ai-context ベースの絶対パス（不明なら `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`）。

トピックベースの workspace 管理 + 3 階層ブランチ運用: **main ← epic（大枠スコープ）← task（小枠 worktree）**。

## 設計方針: intent-first（最重要）

**ユーザーにどのコマンドを使うか決めさせない**（CONCEPT の anti-goal）。
下表のインテントをユーザーの自然文から検出し、Claude に操作を駆動させる。コマンド（`/ws ...`）は
deterministic なエイリアスとして残るが、ユーザーがそれらを暗記している前提は置かない。

| ユーザー発話（例） | インテント | 操作 | 自律度 |
|---|---|---|---|
| 「決済のリデザインを始める」「大きめの作業」 / "start the payment redesign", "a bigger piece of work" | 大枠スコープ開始 | **epic**: `git town hack` + WS 作成 | **L2: 提案して進める**（採用解釈を開示） |
| 「API は並行で」「これは別 worktree で」「同時に進めて」 / "do the API in parallel", "put this in a separate worktree", "run these at the same time" | 並列小枠スコープ | **task**: epic 上で `git town append` + worktree | L2 → 軽い確認（epic 確立後は自走） |
| 「この作業終わった」「task 完了」「epic に戻して」 / "this work is done", "task complete", "merge it back into the epic" | 小枠スコープ完了 | **done**: test → `git town merge` → sync → cleanup | **L3: 自動実行**（結果報告のみ） |
| 「main に入れて」「リリース」「これで出して」 / "put it into main", "release", "ship it" | 大枠スコープ完了 | **ship**: `git town propose` → **PR** | **人間ゲート**（PR 作成前に確認；safety rule） |
| 「別の作業に切り替え」「〜の続きやる」 / "switch to other work", "continue working on ..." | コンテキスト切替 | switch（従来どおり） | L1 |
| 「研究テーマ A と B を見比べたい」 / "compare research topics A and B side by side" | 並列参照 | multi（従来どおり） | L1 |

判断の分担: **帳簿系（sync, cleanup, done 検出）は黙って自動 / 構造を作る操作（epic 新設）は採用解釈つきの提案 / 不可逆で外向きの操作（PR, main）のみ人間を通す**。
epic に値しない単発作業に epic を提案しない（誤発火の官僚化を避ける；迷ったら通常の feature ブランチを使う）。

## 並列の自発提案（fan-out Agent vs worktree）

ユーザーが「並行で」と言わなくても、独立した複数サブタスク（**同一ファイル非接触・直列依存なし**）に分割できると判断したら、直列実行せず並列化を**自発提案**する（intent-first の延長）。fan-out Agent（読み取り/独立編集・短命・最 lean）と task worktree（並走ブランチ・競合・長時間）の判断基準＋分割可能性テスト 3 条件: [`references/parallel-proposal.md`](references/parallel-proposal.md)。既定は banto 自身による fan-out Agent 実行であり、worktree 上での別セッション手動起動は真に独立した長時間並走が要るときだけの明示オプトインとする。

## 使い方（エイリアス一覧 — どのコマンドも自然文で到達可能）

```
/ws                       → show the current workspace
/ws list                  → list all workspaces
/ws new                   → create a new one (interactive)
/ws switch <name>         → switch (branch auto-switches too; aborts on uncommitted changes)
/ws multi <ws1> <ws2> ... → reference multiple WS in parallel (primary is the write target, others read-only)
/ws solo                  → leave multi and return to a single primary
/ws archive               → archive the current WS
/ws import <name>         → pull another WS's related files into the current WS
/ws epic <name>           → create a large-scope branch (git town hack + WS creation)
/ws task <name>           → carve out a small-scope worktree (child of the epic + physical separation)
/ws done                  → finish a small scope (test → merge into parent epic → sync → worktree cleanup)
/ws ship                  → PR from epic → main (human gate; runs after confirmation)
```

## 3 階層ブランチ運用（epic / task / done / ship）

詳細手順・fallback・安全チェック: [`references/git-town-flow.md`](references/git-town-flow.md)

要点（git-town 23.x で検証済み）:
- **epic**: `git town hack <epic>`（main から分岐、parent を追跡）。同時に WS（`[feat] <epic>`）を作成
- **task**: **必ず epic checkout 上で** `git town append <task>` を実行（current の子になる）→ `git worktree add ../<repo>-wt-<task> <task>` で物理分離 → 既定は banto が実行を駆動する（独立・非競合サブタスクは fan-out Agent、それ以外はオーケストレーション側セッションがそのまま worktree の作業を進める）。真に独立した長時間の並走セッションが必要な場合に限り、そのディレクトリで素の `claude` を手動起動する（明示オプトイン。`claude -w` は別の worktree を新規作成する banto 非管理の臨時分離であり、3 階層の親子追跡から外れるためここでは使わない）
- **drift 伝播**: `git town sync`（epic 更新 → 全 task へ連鎖；worktree 内からも動作する）。task セッション開始時と done 前に自動実行
- **done**: テスト PASS 確認 → task ブランチ上で `git town merge`（親 epic へマージ + ブランチ自動削除）→ `git town sync` → worktree remove。**`git town ship` は決して使わない**（main 専用；stacked 子では拒否されることが実証済み）
- **ship**: `git town propose`（PR 作成；gh fallback あり）。**PR/main は人間ゲート** — 「これで出して」 / "ship it" のような発話で発火し、作成前に 1 度だけ確認する
- **git-town 未導入**: graceful degrade（plain git 手順で代替 + `brew install git-town` を 1 度だけ案内）

## 3 層の分離 / ディレクトリ構成

詳細: [`references/architecture.md`](references/architecture.md)

要点:
- `/ws switch` = 作業文脈の完全切替（自動ブランチ切替）/ `/ws multi` = 同一ブランチ内の並列参照 / `claude -w` = 物理分離（公式 worktree）
- ディレクトリ（新 layout）: `workspaces/<author>/[scope] topic/{workspace.md, tasks.md, tasks-old/}`（実体）+ **軽量ポインタ**（per-checkout）+ `WORKSPACE-refs.md`（multi モードのみ）
- **ポインタの実在場所 = git-dir**（`<git-dir>/banto-ws-pointer.md`；worktree ごとに独立 = 並走で current-WS が衝突しない）。書き込み先は `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --ws-pointer-target`、読み取りは `--ws-pointer`（git-dir を優先 → store の WORKSPACE.md にフォールバック）で取得
- author の導出は `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --author`（再実装しない）
- **ポインタはファイル（symlink ではない）** — 軽量なプレーンテキストのポインタ；Windows fallback 不要
- legacy（`workspaces/*.md` 直下 / 未移行案件）は読取互換で扱う（hook がフォールバックする）

## スコープタイプ

| Type | 切替基準 | 推奨操作 |
|---|---|---|
| `[branch]` | git ブランチが変わるとき | `/ws switch` で 1:1 マッピング、ブランチ自動切替 |
| `[feat]` `[task]` | feature/task が変わるとき | `/ws switch` でブランチ分割推奨（コミット粒度） |
| `[research]` `[experiment]` `[model]` | research/experiment トピックが変わるとき | `/ws multi` で並列が OK（多くは未コミットのドラフト） |
| `[test]` `[training]` | test/training の実行が変わるとき | 用途次第；主に `/ws switch` |

自由形式の type も許容（infra, data, paper など）。

## 手順

ユーザー向け出力（メッセージや一覧）: ユーザーが日本語で話していれば日本語で応答する。

### /ws（引数なし）/ /ws list: 表示系

`/ws` は実効ポインタ（`<git-dir>/banto-ws-pointer.md`、非 git は WORKSPACE.md）を Read して現在の WS を表示、`/ws list` は workspaces/ を Glob して active / archived を一覧表示。Read/Glob の具体手順・表示形式: [`references/basic-commands.md`](references/basic-commands.md)。

### /ws new / /ws archive / /ws import: 作成 / 退避 / インポート

詳細手順: [`references/new-and-archive.md`](references/new-and-archive.md)

要点:
- `/ws new`: config.json を Read → スコープ + トピックを確認 → **実装 WS か確認**（既定 = 実装。実装 WS の並走起動は `claude --model sonnet`、設計 WS はフラグなし＝セッション既定） → 実体 `workspaces/<author>/[scope] name/{workspace.md, tasks.md(scaffold), tasks-old/}` を作成 → 軽量ポインタ（`<git-dir>/banto-ws-pointer.md`、非 git は WORKSPACE.md）を書く
- `/ws archive`: 実体 dir を `workspaces/<author>/old/` へ移動、実効ポインタを削除
- `/ws import`: 別 WS の関連ドキュメントを引き込んで 「依存:」 欄に追加

### /ws switch <name>: 切替（ブランチ自動切替付き）

詳細手順: [`references/switch-procedure.md`](references/switch-procedure.md)

主なステップ:
1. 未コミット変更をチェック（あれば中止；破壊的操作を回避）
2. 軽量ポインタ（`<git-dir>/banto-ws-pointer.md`）を新 WS へ書き換え（WORKSPACE-refs.md を削除。旧 WORKSPACE.md を書くのは legacy 構成のみ）
3. 実体 `workspace.md` の 「ブランチ:」 行を使ってブランチを自動切替（git checkout / -b）
4. ポインタ + 実体 `workspace.md` + `tasks.md` を Read して文脈を注入
5. 依存 WS を確認

### /ws multi / /ws solo: 並列マルチ WS 参照モード

同一ブランチ上で複数の研究テーマや実験を同時に参照するためのモード。詳細手順: [`references/multi-mode.md`](references/multi-mode.md)

要点:
- `/ws multi <ws1> <ws2> ...` は primary（書き込み対象）+ references（読み取り専用）を分離する
- 参照情報を記録するため `{base}/WORKSPACE-refs.md` を作成
- `/ws solo` は single モードに戻す（refs.md を削除）


## 形式仕様（軽量ポインタ / workspace.md / multi hook 連携）

軽量ポインタ（**git-dir 内**・WS 名 + ブランチ + 実体パスのみ・worktree ごとに独立）と workspace.md（実体・「ブランチ:」行が `/ws switch` の自動切替を駆動・「## 関連ドキュメント」は hook が未登録を通知し AI が更新・タスクは同 dir の `tasks.md`）の形式、および multi モードの hook 連携: [`references/formats.md`](references/formats.md)。
