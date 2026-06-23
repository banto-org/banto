---
name: research
description: |
  外部情報源（Web / GitHub / arxiv / X など）を新規に調査し、その結果をドキュメント化する（外部リサーチ / 新しい情報を取りに行く）。既存の .ai-context/ を眺めるだけなら search skill を使うこと。
  トリガー: 「調べて」「最新の〜」「今どうなってる」「ベストプラクティス」「論文」「トレンド」「ライブラリ/技術を比較して」「どっちがいい」「リサーチ」。/research <topic> でも呼び出し可能。
  使わない場面: 既存のローカル AI Context（.ai-context/ の decisions / docs / 過去の会話）を検索するだけの場合 — それは search skill（Web アクセスなし）。プロジェクト自身のコードに関する素の「教えて」は、直接か search skill で答える。外部リサーチではない — research は新しい外部情報を取りに行くこと。
user-invocable: true
argument-hint: "[調査トピック]"
model: opus
allowed-tools: Read Write Glob Agent WebSearch Bash Workflow
compatibility: Claude Code (requires bash, git, jq)
---

# Research — 外部リサーチスキル

> **保存ベース（store-first）**: この skill が保存する `.ai-context/docs/research/...` パスは ai-context ベースを指す。SessionStart/PreCompact hook が「ai-context ベース: &lt;絶対パス&gt;」として注入する絶対パスの配下で Read/Write する — 相対 `.ai-context/` には絶対に書かない（旧来の legacy repo にしか存在しない。不明なときは `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決）。

ユーザーの会話言語で記述する（ユーザーが日本語で会話していれば日本語）: これは応答、報告する発見事項、**そして保存するリサーチドキュメント**にも及ぶ。その言語を起動プロンプトで research-agent に渡すこと（サブエージェントは会話言語を継承しない）。

## search と research

| | `/search` | `/research`（この skill） |
|---|---|---|
| 対象 | **内部**: `.ai-context/`（decisions/ + docs/ + 過去の会話履歴） | **外部**: Web、GitHub、arxiv、X、公式ドキュメント |
| Web アクセス | **なし** | あり |
| 結果 | 既存ファイルの参照 / 要約を返す | `.ai-context/docs/research/` に新規ファイルを保存 |
| 所要時間 | 秒 | 分（research-agent を並列起動） |

**覚え方**: 既に持っているか、いないか？ 持っていないなら `research` を使う。

## 原則

1. **並列実行**: 各調査項目を Agent tool（research-agent）で実行し、**一度に 5〜10 並列**で回す
2. **常に最新を探す**: knowledge cutoff に頼らず、常に WebSearch で最新を取りに行く
3. **適切な媒体を選ぶ**: トピックごとに最適なリサーチツールを選ぶ（下表）
4. **ログイン必要なリサーチは事前確認**: 認証が必要な媒体（X/Twitter など）はユーザーの承認を先に得る
5. **必ず情報源 URL を引用する**: 出典のない情報には価値がない
6. **結果をドキュメント化する**: `.ai-context/docs/research/{YYYY-MM-DD}_{topic}.md` に保存する（会話だけで終わらせない）

## リサーチ媒体の選択

ツールを選ぶ前にトピックを分類する。媒体を誤ると品質が大きく落ちる:

> **URL の中身取得に WebFetch を使わない**（小型モデルがページを要約するため、全文を検証できない）。
> URL を読むには `webread`（`sh "$CLAUDE_PLUGIN_ROOT/scripts/webread.sh" "<URL>"`、trafilatura による全文抽出）を使う。
> WebSearch は URL を *探す* ためのもの（要約問題はない）なので、普段どおり使う。

| トピック種別 | 第一選択 | 第二選択 | 備考 |
|---|---|---|---|
| 公式仕様 / API ドキュメント | `webread`（直接 URL） | `research-agent`（WebSearch） | 静的で安定。URL が分かっていれば最速 |
| GitHub Issues / Releases / PRs | `research-agent`（WebSearch） | `gh` CLI（Bash 経由、許可されていれば） | |
| GitHub コード内容 | `gh` CLI で clone | `webread` raw URL | |
| X / Twitter（コミュニティの反応） | **Claude in Chrome**（ログイン必要） | `WebSearch`（公開情報のみ） | ログインが必要ならユーザーに確認 |
| Slack / Discord / 社内ツール | **Claude in Chrome**（ログイン必要） | — | 常にユーザーに確認 |
| 学術論文 / 査読誌 / プレプリント（分野別） | `research-agent`（分野別の学術 venue） | `webread`（直接論文 URL） | 分野別の参照先・site: フィルタは [`references/academic-sources.md`](references/academic-sources.md)。エンジニア系と混ぜない |
| SPA / 動的サイト / JS レンダリング必須 | **Claude in Chrome** → `webread --html` | — | trafilatura は静的ページのみ対応。レンダリング後の HTML を渡す |
| Stack Overflow / 技術ブログ | `WebSearch` → `webread` | `research-agent` | |
| 日本語ソース（Qiita / Zenn / はてな） | `WebSearch`（ja クエリ） | `research-agent` | |
| **重大 / 論争的 / 主張の反証が必要**（真偽がビジネス/安全の判断を左右する） | **`deep-research`**（高検証パス → 後述） | `research-agent`（WebSearch） | 敵対的 3 票検証。高コスト → 起動前に確認 |

### Claude in Chrome を使うとき

次のいずれかに当てはまると `webread` / `WebSearch` では不十分:
- ログイン必要（X、Slack、社内ツール、ペイウォール付きドキュメント）
- JS 動的レンダリングが必須（SPA、コメント欄、インタラクティブ UI）
- スクロール / クリック / フォーム送信が必要

→ `mcp__claude-in-chrome__*` ツールを使う（先に `ToolSearch` で schema をロードする）。

## 高検証パス: `deep-research`（重大トピックの敵対的検証）

主張の正確さが実際の判断を左右するトピックでは、Claude Code 組み込みの **`deep-research`** Workflow に委譲する — 決定論的な 5 フェーズのハーネス（Scope → Search → Fetch → **3 票敵対的 Verify** → Synthesize）で、各主張を採用前に *反証* する。これは `research-agent`（クロスチェックのみ）に欠けている厳密性の層だ。**banto の仕事は deep-research に欠けているものを足すこと: 永続化 + プロジェクトコンテキスト統合**（deep-research はオブジェクトを返すだけで何も保存しない）。

### ここへルーティングするとき（重大なときだけ yes に傾ける）

- 主張の真偽がビジネス / 安全 / コンプライアンスの判断を左右する
- 分野が論争的、ソースが食い違う、またはマーケ/PR の主張が支配的
- 引用の正確さが重要（deep-research のエージェントは URL を ~10% の確率で幻覚する — 敵対的 Verify パスがそれを潰す）

### ルーティングしないとき（既定は `research-agent`）

- 通常のリサーチ — deep-research は**重い**（1 回あたり ~100 エージェント / ~4M トークン / ~20 分。通常の $2 上限を大きく超える）
- 速度優先 / 軽いファクトチェック（`webread` / `WebSearch` 1 回で十分）
- コンテキスト統合が主目的（`research-agent` + store-first で既にカバー済み）

### 方法（オーケストレーターレベルのみ — この skill はメインループで動く）

1. **コストゲート（必須）**: 起動前にユーザーに確認する — 高コスト（~4M トークン / ~20 分）。これは odd.yaml の `deep-research launch` ゲートであり、$2 予算に対する宣言済みの例外。
2. **まず問いを研ぎ澄ます**: 不明確なら 2〜3 個の明確化質問をする（deep-research 自身の契約）。その回答を args に織り込む。
3. **起動**（メインループから — `research-agent` *サブエージェントは* Workflow を呼べ*ない*）:
   ```
   Workflow({ name: "deep-research", args: "<精緻化した問い>" })
   ```
4. **graceful フォールバック**: 環境に `deep-research` が無い場合（古い Claude Code）、Workflow 呼び出しが名前解決で失敗する → 通常の並列 `research-agent` パスにフォールバックする。決してハードフェイルしない。
5. **永続化ラッパー（これが統合の本体 — 必須）**: deep-research は**何も保存しない**。`{ summary, findings[], caveats, sources, stats }` を返す。そのオブジェクトを標準のリサーチドキュメントに整形し、`{BASE}/docs/research/{YYYY-MM-DD}_{slug}.md` に保存**しなければならない**（deep-research テンプレは [`references/output-format.md`](references/output-format.md)）。finding ごとの確信度 + 投票と、棄却された主張のリストを保持する（透明性）。
6. **store-first 統合**: 保存後、過去の `decisions/` と既存リサーチに対する整合を確認し、報告する（通常パスと同じ）。これが一回限りのレポートを蓄積された知識に変える。

## 事前コンテキストチェック（外部リサーチの前に必ず実行）

### Step 0: 既存コンテキストの確認

外部リサーチを始める前に、以下を**並列で**確認する。既に持っているもので問いに答えられるなら、外部リサーチをスキップまたは縮小する:

1. **WS 関連ドキュメント**: `.ai-context/WORKSPACE.md` の `## 関連ドキュメント` セクションを Read し、リサーチトピックに関連するファイルパスや URL を探す
2. **既存リサーチ**: `.ai-context/docs/research/` を Glob し、トピックに関する過去のリサーチを探す（見つかれば Read して鮮度 / カバレッジを判断）
3. **decision ログ**: `.ai-context/decisions/` を Glob し、トピックに関連する過去の決定を探す
4. **active.md**: `.ai-context/tasks/active.md` を Read し、リサーチトピックが現在のタスクとどう関連するか把握する

**判断ルール**:
- 既存リサーチがあり **14 日以内** → 「既存リサーチが見つかりました（{filename}、{date}）。更新しますか？」と聞く
- 既存リサーチがあるが **14 日より古い** → 古い旨を明記し、差分リサーチに切り替える（全部やり直さない）
- WS 関連ドキュメントに URL が含まれる → Step 1 で該当サブトピックの一次ソースとしてその URL を使う
- 関連する設計決定がある → 最終報告で発見事項と過去の決定との整合に言及する

## 計画開示フロー（自走）

詳細手順: [`references/approval-flow.md`](references/approval-flow.md)

主要ステップ:
1. リサーチを 3〜10 個のサブトピックに分解し、各々の媒体を明記し、**計画をテキストで提示して続行する**（事後開示 — 承認待ちしない。事前確認は odd.yaml 宣言のゲートに限る）
2. ログイン必要項目（❗）は**必ず**ユーザーに確認する（odd.yaml ゲート）
3. リサーチを並列実行する（1 つのメッセージで複数の Agent を起動、`run_in_background=true` 必須。8 並列以上は確認が必要 — odd.yaml ゲート）。Claude in Chrome は親セッションで直接実行する（サブエージェントは Chrome ツールを持たない）。**すべての research-agent 起動プロンプトに `会話言語: {lang}`（ユーザーの会話言語）を含めること** — 保存するドキュメントがそれに揃うように。サブエージェントは会話言語を継承しない。

## 検索ルール

- バージョン番号を含めない（"React 18" → "React latest"）
- 英語ソースを優先する（最新情報はまず英語で出る）
- 検索クエリに現在の年（例 `2026`）を含めて最新を取りに行く
- 複数ソースをクロスチェックする（単一ソースで結論しない）
- 学術トピックはエンジニア系ソースと分け、[`references/academic-sources.md`](references/academic-sources.md) の分野別 venue（AI/CS は arXiv / alphaXiv / OpenReview、生命科学は bioRxiv / medRxiv / PubMed / Nature）を research-agent の起動プロンプトに渡す
- cutoff の知識だけで答えない（`~/.claude/rules/evidence-first.md` に従う）

## 出力フォーマット

詳細テンプレート: [`references/output-format.md`](references/output-format.md)

保存先: `.ai-context/docs/research/{YYYY-MM-DD}_{topic-slug}.md`

要素: TL;DR / 詳細 / Sources / 信頼度（高/中/低）。
保存後、保存先パスと併せて **3〜5 点** の主要な発見事項をユーザーに報告する。
