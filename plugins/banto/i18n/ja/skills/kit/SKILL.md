---
name: kit
description: |
  **UTILITY SKILL** — banto プラグインが提供する全ての skill / agent / hook / rule を整形済みカタログとして表示する。自然言語による発見ハブ：ユーザーはコマンドの存在を知らなくてよい（intent-first）。
  トリガー: /kit、「banto で何ができる」「機能一覧」「コマンド一覧」「どんなスキルがある」「〜ってどうやるの（banto の機能を探している時）」。
  使わない場面: 個別スキルの詳細確認（その SKILL.md を直接 Read）、プラグインの監査（plugin-audit）、新規プラグインの作成（plugin-dev）。
user-invocable: true
compatibility: Claude Code (requires bash, git, jq)
---

# Banto Kit — 全機能カタログ

以下を**そのまま**（編集せず）表示する。ユーザーが英語で会話している場合は、同じカタログを英語で表示してよい（コマンドとトリガー語はそのまま保持）。

## コマンド（deterministic エイリアス — いずれも自然言語からも到達できる）

> コマンドはパワーユーザー / ルーチン / CI 向けの脱出口。コマンドの存在を知る必要はない：各スキルは自然言語から自動発火する（例フレーズは次セクション参照）。Intent-first。

### 検索・リサーチ
| Command | 内容 |
|---------|------|
| `/search {query}` | **内部検索**。search スキル（クエリ展開 + grep ランキング）が `{base}/`（+ config.json の `extra_docs_dirs` で追加したディレクトリ）を横断検索する。Web には一切触れない |
| `/research {topic}` | **外部リサーチ**。Web / GitHub / arxiv / X / 公式ドキュメントを並列で調査し `docs/research/` に保存する。媒体に応じて Claude in Chrome を適宜使用 |

### コンテキスト管理
| Command | 内容 |
|---------|------|
| `/save-checkpoint` | セッション状態をチェックポイントとして保存。compact/clear を推奨 |
| `/ai-context [bootstrap/local/doctor/sort/ignore/migrate/memo/knowledge]` | `{base}/` の管理コマンド（store 作成・登録 / ローカル固定 / 健診 / 整理 / 抑制 / 移行 / メモ / ナレッジを内包。`init`・`status` は旧名エイリアス・1 リリース後方互換） |

### ドキュメント作成
ドキュメント作成系スキル共通のパターン: `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md`（パターン A: agent 起動型 / パターン B: 穴埋めテンプレート）

| Command | 内容 | パターン |
|---------|------|----------|
| `/ai-context memo [content]` | 引数なし: 会話要約を保存。引数あり: 指定内容をメモ化（旧 `/memo` は 1 リリース後方互換） | B |
| `/ai-context knowledge [list/promote]` | ナレッジ下書きのレビュー / 昇格 / 作成（旧 `/knowledge` は 1 リリース後方互換）| B（例外: プレフィックスなし） |

> コードレビューとセキュリティ監査は**公式 Anthropic プラグインに委譲**（`code-review` / `security-guidance` / `/security-review`）。

### 開発フロー
| Command | 内容 |
|---------|------|
| `/ai-context next` | 次の未完了タスクを実行 |
| `/ai-context phase-done [N]` | Phase 完了チェック + アーカイブ |
| `/ws [switch/new/ship/...]` | 3 階層ブランチモデル（main ← epic ← task worktree）の Workspace + git-town オーケストレータ。切替・並走・スコープ切り出し・完了マージ・main への ship をインテント検出で駆動 |

### ツール群
| Command | 内容 |
|---------|------|
| `/init` + `harness-setup.sh` | CLAUDE.md（ネイティブ /init）+ rules / 設定 / store の初回セットアップ（決定論スクリプト） |
| `/plugin-dev {description}` | 新規プラグインの scaffold / 既存スキルのリファクタ |
| `/plugin-audit [path]` | 既存プラグイン / 単一スキルを公式ベストプラクティスと突き合わせて監査 |
| `/set-language [ja/en]` | Banto の言語を日英で切替。選択は永続（プラグイン更新をまたいで保持）。反映には Claude Code の再起動が必要 |
| `/ai-context sort project` | プロジェクト全体に散らかったドキュメントを整理 |
| `/kit` | このカタログを表示 |

> セキュリティ監査とコードレビューは公式 Anthropic プラグインに委譲（`security-guidance` / `code-review` / `/security-review`）。

## 自然言語から自動発火するスキル

| Skill | 例トリガー |
|-------|-----------|
| `ai-context` | 「決定」「採用」「設計判断」「保存」「compact」「clear」「タスク」「TODO」「Phase」 |
| `search` | 「前に話した」「思い出して」「recall」「履歴」「経緯」「探して」（内部検索。`/search` でも可） |
| `research` | 「調べて」「最新の〜」「ベストプラクティス」「比較して」「論文」「リサーチ」（外部リサーチ。`/research` でも可） |
| `ai-context` (next) | 「続き」「次は何」「次のタスク」「進めて」「やって」 |
| `concept` | 「思想」「コンセプト」「世界観」「ビジョン」「哲学」「北極星」「なぜ作る」 |
| `spec` | 「spec」「仕様書作って」「設計だけして」「plan」「実装しないで」 |
| `dev-loop` | 「自走で開発」「大玉を分解して回して」「ループで開発」「dev loop」「学習ループ」（単発実装は self-driving で直接） |
| `ai-build` | 「RAG を作りたい」「エージェント作る」「eval 組む」「プロンプト改善」「どのモデルがいい」（AI 機能構築フロー。dev-loop の AI 特化版・eval まで） |
| `model-lab` | 「モデルを学習」「事前学習」「fine-tune して」「蒸留」「pruning」「ablation 回す」「論文書く」「HF に公開」（モデル作成・学習の研究フロー。検証中心・論文/HF/GitHub 公開まで。ai-build がアプリ層なのに対し研究層） |
| `ai-context` (memo) | 「メモして」「書き留めて」「会話を要約して保存」（ai-context に内包。旧 `memo` は後方互換） |
| `ai-context` (knowledge) | 「ナレッジにして」「昇格して」「教訓として残して」（ai-context に内包） |
| `plugin-audit` | 「この skill の品質チェック」「14軸で見て」「SKILL.md を best practice と突き合わせ」 |
| `ws` | 「ワークスペース」「作業切り替え」「並走」「ブランチ分けて」「worktree」「epic」「この作業終わった」「マージして」「リリースして」 |
| `set-language` | 「言語を日本語にして」「英語に切り替えて」「言語設定」「make banto japanese/english」（永続。再起動で反映） |

> **intent-first 全面適用**: 上記の skill は旧 `disable-model-invocation` を解除し、自然文で発見・起動できるようにした（北極星「人間は呼び出しを考えない」）。コマンドは deterministic エイリアスとして維持。

> **Self-driving harness principle**: 「実装して」「開発して」「並行で」「深く考えて」などの**単発依頼には専用スキルを置かず** Claude が self-driving で処理する：concept→spec→**self-driven implementation**（設計→実装→テスト→レビューを駆動）/ 独立タスクは**1 メッセージ内で複数 Agent を並列**実行 / 難しい判断はオンデマンドで深い推論。**大玉を小型タスクへ分解し実装→検証→修正を緑まで自走ループで回す**ときだけ、その self-driving を `dev-loop` skill が orchestrate する。起動の主体は人間のスキル呼び出しではなく、Claude の self-driving。

## カスタムエージェント

| Agent | 目的 | 起動経路 |
|------------|------|------|
| `architect` | 設計 / アーキテクチャ分析（コード変更なし） | `spec` から `Agent(subagent_type="architect", ...)` で、あるいは直接 |
| `debugger` | エラー / テスト失敗のデバッグ | エラー発生時に AI が自律的に `Agent(subagent_type="debugger", ...)` を起動 |
| `qa-tester` | web/desktop/mobile の E2E テスト | `Agent(subagent_type="qa-tester", ...)` で直接 |
| `research-agent` | Web リサーチ（並列起動） | `/research` / research スキルから並列起動 |
| `search-agent` | 内部検索の機械的実行（haiku、軽量） | search スキルの deep path から: 3〜5 並列 `Agent(subagent_type="search-agent", model="haiku", ...)` |
| `context-keeper` | 検索テキスト層（full-combined.txt / sessions-cache）の整合チェック / 再生成 | full-combined.txt の鮮度疑い時のフォールバック、あるいは直接 |

> コードレビューとセキュリティ監査は公式 Anthropic プラグインに委譲（`code-review` / `security-guidance`）。

## Subagent 委譲ルーブリック — いつ委譲するか

「探索 / 監査 / 評価を隔離する」という Layer-3 のハーネス工学原則。親コンテキストを圧迫しないよう、以下のいずれかに当てはまるときは subagent に委譲する：

| 状況 | 委譲先 | 理由 |
|------|--------|------|
| 5 ファイル以上に渡るファイル探索 / 単純な「X はどこ？」 | ビルトイン `Explore` | 抜粋が親コンテキストを汚染するのを防ぐ |
| 複数ステップの内部調査 / オープンエンドな分析 | ビルトイン `general-purpose` | Explore は抜粋しか返さず、オープンエンドな作業に不向き |
| 外部 Web / GitHub / arxiv リサーチ | `research-agent` | 大規模 WebSearch を親で直接回さない / WebFetch は禁止（webread を使う。evidence-first ルール） |
| 設計 / アーキテクチャ分析 | `architect` | コード変更なし。提案のみ返す |
| エラー / テスト失敗の根本原因 | `debugger` | reproduce → fix → rerun ループを隔離 |
| コード品質レビュー | Anthropic `code-review` プラグイン | 自己レビューバイアスを回避（Reviewer = Fresh Agent 原則）。Anthropic に委譲 |
| セキュリティ監査 | Anthropic `security-guidance` / `/security-review` | 自動 3 層 + 明示レビュー。Anthropic に委譲 |
| E2E / UI 検証 | `qa-tester` | ブラウザツールのコンテキスト重量を隔離 |

**委譲しない場面**:
- 軽微な単一ファイル修正 / タイポ（直接 Edit）
- 既知パスを開くだけ（直接 Read）
- 単純な確認質問 / 採用解釈で進めてよいもの
- 全スキル / 全エージェントを一度に回せという要求（main で逐次処理。独立タスクなら並列 Agent / Workflow を検討）

**並列起動の原則**: K 個の独立タスクには、**1 メッセージ内で K 回の Agent ツール呼び出し**を発行する。逐次起動より速い。`run_in_background=true` が必要でない限り親は待機する。`research` スキルが代表例。

## ユーザーグローバルルール

| Rule | 内容 |
|-------|------|
| `evidence-first` | 情報系の質問への回答時は、順に検証: search スキル → docs → research-agent |
| `dependencies` | バージョン選定（最新かつ安定・既知の脆弱性なしを選ぶ）+ PM 選定（プロジェクトの manifest / lockfile に従い、既存 PM を尊重・エコシステムをまたがない）|
| `quality` | コード品質（不要な抽象化なし、スコープ内に留まる） |
| `safety` | 安全性（force-push なし、シークレット保護、`.env` の生出力なし、デバッグトレースなし） |
| `spec-fidelity` | 仕様にない挙動を推測しない — 質問する（Ambiguity Questionnaire） |
| `testing` | テスト規約（1 テスト 1 アサーション、モック最小） |
| `code-editing` | コード編集の制約（lockfile / 特定ファイルタイプの編集ガード、パススコープ適用） |
| `pii-protection` | PII / 内部名の保護（クライアント成果物への内部名・他社名・個人情報の書き込みを禁止。egress-guard で決定論的に強制） |
| `writing-ja` | 日本語ライティング規約（重点先行・一文一義・文末の だ/である/です/ます を使わない・カタカナ英語を減らす） |
