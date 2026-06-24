# skill 設計パターン

skill / agent を作成する時の設計パターン集。

## 1. 呼出制御パターン（公式 Skills ページの表より）

| フロントマター | ユーザー呼出 | Claude 呼出 | コンテキスト読込 |
|---|:---:|:---:|---|
| (デフォルト) | ✓ | ✓ | description は常時、フルは呼出時 |
| `disable-model-invocation: true` | ✓ | ✗ | description はコンテキストに含まれず、呼出時にフル |
| `user-invocable: false` | ✗ | ✓ | description は常時、呼出時にフル |

### 双方向（デフォルト）

```yaml
---
name: search-codebase
description: |
  **ANALYSIS SKILL** — Search the codebase semantically.
  USE FOR: codebase exploration, finding similar implementations.
  INVOKES: Read, Grep, Glob.
---
```

ユーザーが `/search-codebase` で呼べる。Claude も自動発火可能。
**用途**: 一般的な情報取得、検索、解析。

### ユーザーのみ（副作用ワークフロー）

```yaml
---
name: deploy
description: |
  **WORKFLOW SKILL** — Deploy the application to production.
  /deploy で明示呼び出し専用。
  INVOKES: Bash(gcloud:*), Bash(kubectl:*).
disable-model-invocation: true
allowed-tools: Read Bash(gcloud:*) Bash(kubectl:*)
---
```

ユーザーが `/deploy` で呼んだ時のみ動作。Claude が会話中に勝手に発火しない。
**用途**: commit / deploy / send 等の副作用ワークフロー。

### Claude のみ（バックグラウンド知識）

```yaml
---
name: legacy-system-info
description: |
  **ANALYSIS SKILL** — Background knowledge about the legacy XYZ system.
  use proactively when: discussing legacy XYZ behavior or migration.
user-invocable: false
---
```

`/` メニューに表示されない。Claude が会話の文脈で必要と判断した時に自動参照。
**用途**: ドメイン知識、レガシーシステム情報、規約集。

## 2. スキル種別（公式 Skills ページ）

### リファレンスコンテンツ

公式定義:
> 「Claude が現在の作業に適用する知識。規約、パターン、スタイルガイド、ドメイン知識。会話コンテキストと一緒に使用」

```yaml
---
name: api-conventions
description: API design patterns for this codebase
---

When writing API endpoints:
- Use RESTful naming conventions
- Return consistent error formats
```

特徴:
- `context: fork` を**つけない**（公式 Warning：実行可能なプロンプトがないため意味なし）
- 通常はデフォルト呼出設定 or `user-invocable: false`
- 会話の通常文脈で参照される

### タスクコンテンツ

公式定義:
> 「特定のアクション (デプロイ、コミット等) のステップバイステップ指示。`/skill-name` で直接呼び出し」

```yaml
---
name: deploy
description: Deploy the application to production
context: fork
disable-model-invocation: true
allowed-tools: Bash(gcloud:*) Bash(kubectl:*)
---

## Steps
1. Run pre-deploy checks
2. Build the artifact
...
```

特徴:
- `disable-model-invocation: true` は**例外運用**（intent-first 優先）: 真に不可逆・外向きな副作用、または高頻度語彙と不可分に衝突する場合のみ。非破壊ワークフロー（read-only / `--refresh` 必須 / 人間ゲート内蔵 / 承認制）は**狭い固有 NL トリガー + 安全境界で公開**し、DMI は付けない（北極星「全機能は自然文到達可能」/ decision `2026-06-10-114006`）。残す場合は明文理由を description に記す
- `context: fork` でサブエージェント分離可能
- 明確なステップを持つ

## 3. ループ設計（Glaser Elastic Loop 由来）

Glaser の Elastic Loop 概念を skill 設計に応用:

### Tight Loop（同期コドライビング）

特徴: ユーザーと Claude が交互に動作確認しながら進める
- 1 ステップごとにユーザー確認
- 高コントロール、認知負荷も高い
- 複雑な仕様分岐、初めての試み、不確実な要求に向く

```yaml
---
name: spec
description: |
  **WORKFLOW SKILL** — 業界標準フォーマットで仕様書を対話生成する。
  トリガー：「設計だけ見せて」「仕様書作って」「spec」
  使ってはいけない場面：実装まで一気にやる場合は spec 後そのまま自走実装
  依存：テキスト対話で要件確認
---
```

### Loose Loop（非同期委任、Dark Factory）

特徴: intent を渡して loose loop で委任、backpressure で軌道修正、結果を評価
- サブエージェント委任が中心（`context: fork` + `Agent` ツール）
- 親セッションのトークン消費を抑える
- 確立されたパターン、定型タスク、調査・分析に向く

```yaml
---
name: research
description: |
  **WORKFLOW SKILL** — 外部情報を新たに調査してドキュメント化する。
  トリガー：「調べて」「最新の〜」「リサーチ」
  使ってはいけない場面：内部検索だけなら search を使う
  依存：research-agent を Agent(subagent_type=research-agent) で並列起動。
  単純な事実確認なら webread 1 回で十分。
context: fork
agent: general-purpose
---
```

設計上の問い（Glaser）:
- このスキルはどのループサイズで使うべきか？
- どこに backpressure（評価・軌道修正点）が必要か？
- どのアーティファクトをループから残すべきか？
- 学習はどう組織に伝播するか？

## 4. サブエージェント実行パターン

### context: fork + agent 指定

```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:
1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

組み込みエージェントタイプ:
- **Explore**: 読み取り専用、コードベース探索用
- **Plan**: プランモード用の調査エージェント
- **general-purpose**: 探索と変更の両方が必要な複雑タスク

### Dark Factory 化された委任（Glaser）

```
intent (skill description で明確化)
  ↓
loose loop (research-agent を background で起動)
  ↓
backpressure (`{base}/docs/research/` に保存先指定)
  ↓
evaluate (返却結果を strong scenarios で評価)
```

`run_in_background=true` を活用して親セッションのトークン消費を抑える。

## 5. 動的コンテキスト注入

`` !`command` `` 構文で skill ロード前にシェルコマンド実行:

```yaml
---
name: pr-summary
description: PR の変更を要約
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---

## PR コンテキスト
- PR diff: !`gh pr diff`
- 変更ファイル: !`gh pr diff --name-only`

上記を踏まえて要約してください。
```

複数行は ``` ```! ``` ブロック。
無効化: `"disableSkillShellExecution": true`

## 6. パーミッション制御例

```
# 特定スキルのみ許可
Skill(commit)
Skill(review-pr *)

# 特定スキルを拒否
Skill(deploy *)

# 全スキルを拒否
Skill
```

## 7. HeavySkill 4-component（複雑な workflow skill 用）

複雑な推論を含む skill は HeavySkill 4-component（Activation Conditions / Parallel Protocol / Deliberation / Output Constraints）を採用。正本テンプレと適用基準（complex / 判断 / 分析 / 設計 / 議論 / 比較 / トレードオフ等を含む skill）は `references/heavyskill-template.md` を参照。

## 8. インテント・ファースト（コマンド設計の原則）

**「どのコマンドを使うか」をユーザーに判断させない。** skill にコマンド体系（`/skill sub <args>`）を持たせる場合:

1. **設計はインテント検出から始める** — 「ユーザーがどんな自然文を発した時にどの操作が発動するか」の表を SKILL.md の最上部に置く。コマンド表はその後（エイリアス一覧として）
2. **到達可能性ルール** — すべてのコマンドには、ユーザーがその存在を知らなくても自然文で到達できる経路を必ず用意する。description のトリガー語に発話例を含める
3. **自律度はインテント種別で分ける** — 帳簿系（同期・掃除・状態更新）= 黙って自動（L3）/ 構造を作る系（ブランチ・ファイル群の新設）= 採用解釈つき提案（L2）→ telemetry で誤発火率を見て昇格 / 不可逆・外向き（PR・公開・送信）= 人間ゲート
4. **誤発火ガードを書く** — 「この発話では発動しない」境界（官僚化防止）を SKILL.md に明記する
5. コマンドは残す — deterministic・routine/CI から叩ける・パワーユーザー向け。悪いのは「主インターフェースにすること」であって存在ではない

実例: `skills/ws/SKILL.md`（インテント検出表 + epic/task/done/ship エイリアス）。

## 9. 設計判断のフローチャート

```
新しい skill を作る
    │
    ▼
副作用がある？ (commit / deploy / send / write)
    ├─ Yes → disable-model-invocation: true
    └─ No
        │
        ▼
    バックグラウンド知識？（参照のみ）
        ├─ Yes → user-invocable: false
        └─ No → デフォルト（双方向）
            │
            ▼
        複雑な推論を含む？
            ├─ Yes → HeavySkill 4-component
            └─ No → 通常テンプレ
                │
                ▼
            tight loop or loose loop？
                ├─ Tight → ユーザー対話・段階確認
                └─ Loose → サブエージェント委任 (context: fork)
```

## 10. バイリンガル・トリガー（EN canonical + 日本語トリガー併記）

skill の自動発火は description 内のキーワードと自然文のマッチングに依存する。
日英ユーザーの両方で発火させるため、description は次の規約で書く
（出典: banto-public-release spec T2.1。日本語トリガー語は実運用でチューニング済みのため**改変せず温存**する）:

```yaml
description: |
  <English prose, canonical: what this skill does and when it should fire. 1-3 sentences.>
  Triggers: "research", "investigate", "what's the latest", 「調べて」「最新の〜」「リサーチ」「比較して」
  Do not use when: <exclusions, EN. e.g. searching local context only (use `search`).>
```

ルール:
- **本文は英語が正**（Claude は EN 指示でも利用者の言語で応答するため、JP ユーザーの体験は劣化しない）
- **`Triggers:` 行に EN と JP のトリガー語を併記**。JP 語は既存 description から逐語で移す（言い換えない）
- 除外条件（responsibility 境界）も英語で明示し、誤発火を防ぐ
- コマンドエイリアス（`/xxx`）がある場合は §8 インテント・ファーストに従い「自然文で同じ場所に到達できる」ことを保つ

## 関連

- 品質スコアリング → `references/quality-scoring.md`
- HeavySkill 4-component → `references/heavyskill-template.md`
- frontmatter 全フィールド → `references/skill-md.md`
