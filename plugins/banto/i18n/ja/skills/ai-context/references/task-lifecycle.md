# タスクのライフサイクル（next / phase-done / 自動アーカイブ / split）

## 都度更新の義務（task mirror）

tasks.md（store の正本）と組み込みタスク UI（TaskCreate / TaskUpdate）は**作業のたびに両方を更新する**。SessionStart が tasks.md を注入した時点で、今セッションで扱う未完了項目が UI に無ければ TaskCreate で立てる。運用は 3 点:

1. **着手時**: tasks.md の該当項目を確認し、UI 側を in_progress にする
2. **完了時**: tasks.md をチェック（`- [x]`）し、UI 側を completed にする — どちらか片方で終えない
3. **新しい依頼（実装系・調査系のいずれも対象。「また」「とか」「これも」「後で」等の後回し・追加指示を含む）**: tasks.md に無い作業を頼まれたら、まず tasks.md へ `- [ ] {簡潔なタスク}` として追記してから着手する（記録の場所は現在 WS の tasks.md。話題が WS のスコープ外なら先に /ws switch / new を提案する）。質問・雑談・その場で完結する些末な編集はタスク化しない。UserPromptSubmit の `task-router.sh` がこの投入を per-prompt で促す（nudge のみ・強制しない）


<!-- merged from next.md -->
## next — タスクナビゲーター（旧 sdd-core skill を統合）

実効タスクファイル（`workspaces/<author>/<topic>/tasks.md`）から次の未完了タスクを特定し、コンテキストを収集して実装・検証まで完遂する。

呼び出し: `/ai-context next`、または「続き」「次」「次のタスク」「進めて」等の自然言語でも ai-context が発火してこの手順に入る。

## タスクファイルの探索

探索順・プロジェクト本筋ファイル尊重ルール・新規作成判断は SKILL.md「タスク管理ルール」に準ずる（single source of truth）。要約:

1. プロジェクト既存の `tasks.md` / `TODO.md` / `ROADMAP.md` があれば尊重
2. なければ現在 WS の `tasks.md`（`workspaces/<author>/<topic>/tasks.md`）を使用・新規作成（legacy `{base}/tasks/active.md` は読取フォールバックのみ — 新規作成しない）

## ナビゲーションフロー

### 1. タスク特定

タスクファイルを読み、最初の未完了 `- [ ]` を見つける。依存タスク（`deps:`）が完了済みか確認。

### 2. コンテキスト収集（並列実行）

以下を **Agent tool で並列に** 実行:

- search skill（`/search <query>`）で関連する過去の設計判断を検索（Claude がクエリ展開 → grep 採点 → Read 検証）
- 関連する設計ドキュメントがあれば確認
- 対象コードの現状を把握（symbol overview / find symbol 等）

### 3. タスク情報を提示

```markdown
## 次のタスク: T{X.Y} — {タスク名}

**Phase**: Phase {X}: {Phase名}
**依存**: {依存タスクの状態}

### 関連コンテキスト
- 過去の判断: {search skill の検索結果のサマリー}

### 実装対象
- {対象ファイル、関連コンポーネント}
```

### 4. 実装

- 既存コード修正 → シンボル単位編集（Serena 等）
- 新規ファイル作成 → Write tool
- テストがあれば実行して確認

### 5. 完了処理

- タスクファイルを `- [x]` に更新
- Phase 進捗カウンタ `[完了数/総数]` を更新

### 6. Phase 完了時のアーカイブ

命名規則・退避手順は SKILL.md「全タスク完了時の自動アーカイブ」+ 本書「全タスク完了時の自動アーカイブ」節に準拠。`/ai-context phase-done` は本書「phase-done」節が検証込みで実施する。

## タスク形式

```markdown
## Phase 1: 環境構築 [2/5]

- [x] T1.1: Next.js初期化 | deps: none
- [x] T1.2: パッケージインストール | deps: T1.1
- [ ] T1.3: Tailwind設定 | deps: T1.2  ← 次はここ
- [ ] T1.4: Supabase設定 | deps: T1.2
- [ ] T1.5: 環境変数設定 | deps: T1.3, T1.4
```

## コミット規約

```
<type>(<scope>): <subject>
type: feat, fix, docs, style, refactor, test, chore
scope: 機能名や Phase 番号
subject: Task ID を含める
```

例: `feat(diagnosis): Task 4.2 QuestionCard 実装`

<!-- merged from phase-done.md -->
## phase-done — Phase 完了チェック（旧 phase-done skill を統合）

現在の Phase が完了したか確認し、検証して次 Phase へ進む準備を整える。

呼び出し: `/ai-context phase-done [Phase番号]`（明示）。省略時は実効タスクファイル（tasks.md）の最新 Phase。

## 実行手順

### 1. 完了確認

現在 Phase の全タスクが `- [x]` か確認。タスクファイルの場所:
- 新 layout: `{base}/workspaces/<author>/<topic>/tasks.md`（SessionStart の「進行中タスク」見出しのパス）
- legacy: `{base}/tasks/active.md`（`{base}` は central/legacy で解決）
- `tasks.md` / `TODO.md` / `ROADMAP.md`（プロジェクト固有）

未完了タスクがあれば一覧表示してユーザーに確認。

### 2. ビルド・テスト検証

```bash
npm run build && npm run lint && npm test   # ← 一例。実際の PM はプロジェクト依存
```

`dependencies` rule に従い、プロジェクトのマニフェスト / lockfile が示す PM に置換（Node=lockfile が示す PM / Flutter=flutter test / Rust=cargo test 等）。

### 3. E2E テスト

qa-tester agent（`Agent(subagent_type="qa-tester", ...)` で直接起動）で E2E テスト実行。動作確認すべき UI / API がある場合のみ。

### 4. 結果判定

- 全パス → 「Phase X 完了。Phase X+1 へ進む準備 OK」
- 失敗あり → エラー内容を報告し、修正を提案

### 5. 完了 Phase のアーカイブ（実効 tasks ファイル使用時）

完了 Phase を `YYYY-MM-DD_phase{N}-{name}.md` として退避（新 layout → 同 WS の `tasks-old/`、legacy → `{base}/tasks/old/`）:

1. 完了した Phase 部分を抽出
2. 退避先ディレクトリに保存
3. tasks ファイルから該当 Phase 部分を削除

（本書「全タスク完了時の自動アーカイブ」節の命名規則に準拠。hook が全完了を検知してこの手順を誘導する場合もある）

なお検索層は hook が自動再生成（手動不要）。

## 関連

- 次タスクの実行は `/ai-context next`（本書「next」節）
- 通常の完了マークは単に `- [x]` をマーク（このサブコマンド不要）
- E2E テストは qa-tester agent（直接起動）

<!-- merged from auto-archive.md -->
## 全タスク完了時の自動アーカイブ

実効 tasks ファイル（新 layout `workspaces/<author>/<topic>/tasks.md`、legacy は `tasks/active.md`）の全タスクが完了（`- [ ]` が 0 件 かつ `- [x]` が 1 件以上）したら、hook が自動検知してアーカイブを促す。**hook 通知に退避先パスが含まれる**のでそれに従う。

## アーカイブ手順（hook 通知を受けて AI が実行）

1. Phase 名を tasks ファイルの先頭 `## Phase:` または `# Phase:` から抽出
2. 退避先ファイル名: `YYYY-MM-DD_{phase-name}.md`
   - 退避先 dir: 新 layout → 同 WS の `tasks-old/`、legacy → `tasks/old/`（hook 通知のパスを使う）
   - `{phase-name}` = Phase 名（スペース → ハイフン、最大 40 文字）
   - 例: `2026-04-08_plugin-ベスプラ準拠化.md`
3. tasks ファイルを退避先に `git mv`（store 内なら `mv`）で退避
4. 新しい tasks ファイルを作成するか、次 Phase 用の雛形に置き換え
5. ユーザーに完了報告 + 次の作業を確認

## 命名ルールの厳守

- 日付プレフィックス必須（時系列ソートのため）
- Phase 名は tasks ファイル内のヘッダーから抽出（手動命名しない）
- 拡張子は `.md`

既存プロジェクトファイル（`tasks.md`, `TODO.md` 等）使用時はアーカイブしない（プロジェクト管理ルールを尊重）。

<!-- merged from tasks-split.md -->
## tasks split サブコマンド

実効 tasks ファイルを Phase 単位で分割し、完了済み Phase を退避する。
対象は新 layout なら `workspaces/<author>/<topic>/tasks.md`（退避先 `tasks-old/`）、
legacy なら `tasks/active.md`（退避先 `tasks/old/`）。SessionStart の「進行中タスク」見出しのパスが実効ファイル。

## 実行手順

1. 実効 tasks ファイルを Read
2. `## Phase:` または `# Phase:` 行で Phase を分割
3. 各 Phase について:
   - 全タスクが `- [x]` 完了 → 退避先 dir の `YYYY-MM-DD_{phase-slug}.md` に退避候補
   - 一部完了 → 「進行中、退避するか？」とテキストで確認
   - 未着手 → そのまま tasks ファイルに残す
4. ユーザー承認後に `git mv` または `mv` で退避
5. tasks ファイルを再構築（残った Phase のみ）

## 引数

- 引数なし → 対話的に各 Phase 確認
- `--auto` → 完了 Phase のみ自動退避（未完は触らない）
- `--phase <name>` → 特定 Phase のみ操作

