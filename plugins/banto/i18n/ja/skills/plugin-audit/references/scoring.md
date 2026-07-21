# 品質評価基準（15 軸）

banto 全資産（skill / agent / rule / hook）の品質評価軸。本書を `plugin-audit` の **single source of truth** とする。

**原則**: 「形式単語の数」を測る表層スコアリングは使わない。キーワード密度を上げると境界ケースの disambiguation が劣化し、実精度を逆相関で悪化させるため。品質は構造妥当性（静的軸）＋実測ルーティング eval（Axis 4）で測る。

---

## 評価軸 一覧

| Axis | 内容 | 種別 | 担当サブコマンド |
|------|------|------|-----------------|
| 1 | YAML 構造妥当性（公式 19 フィールド網羅 + ユースケース整合）| 静的 | `plugin-audit` |
| 2 | 本文構造妥当性（500 行 / 参照妥当性 / 3 層 progressive loading）| 静的 | `plugin-audit` |
| 3 | description ルーティング形式（"Use when..." / ネガティブ例 / ≤50 語）| 静的 | `plugin-audit` |
| 4 | 実精度測定（Precision / Recall / Forbidden、Agent サブ並列）| 動的 | `plugin-audit eval` |
| 5 | HeavySkill 適用妥当性（推奨 / 不要 / 既採用 / 誤適用 / fan-out 候補）| 構造判定 | `plugin-audit` |
| 6 | Cross-skill disambiguation matrix（双方向参照 / 語彙重複 / 領域被り）| 静的 | `plugin-audit` |
| 7 | 汎用性評価（絶対パス / 個人名 / 組織名 / ツール前提 / [global で +言語/文化/ライセンス]）| 静的 + 動的 | 静的 → `plugin-audit` / 意味判定 → `plugin-audit eval` |
| 8 | 汎用化適性 / rule 外部化（rule を動的読み込みか、ハードコードか）| 静的 + Agent | `plugin-audit` + `plugin-audit fix`（refactor 提案）|
| 9 | Layer 3 ハーネスエンジニアリング整合性（path-scoped 化推奨 / hook enforce 候補）| 静的 | `plugin-audit` |
| 10 | ODD (Operational Design Domain) 適用状況（skill ごとの odd.yaml + autonomy_level 妥当性。ODD 採用プラグインのみ — 未採用は N/A）| 静的 | `plugin-audit` |
| 11 | 使用度（commits + 言及 + 最終更新 → active/dormant/likely-trim）| 静的 | `plugin-audit-usage.sh` |
| 12 | 権限スコープ最小性（**12a** 過剰付与=最小性 / **12b** 宣言漏れ=runtime 正当性）| 静的 + Agent | `plugin-audit-permissions.sh` → `plugin-audit` |
| 13 | 封じ込め整合（hook の危険コマンド / secret 生出力）| 設計 | hook 対象 |
| 14 | Content hygiene（固有情報・貼り込み残骸: regex 層 + semantic 層）| 静的 + Agent | `plugin-audit` 常時 + 公開前ゲート |

> サブコマンド（モード）一覧 + `global` 修飾子の定義は SKILL.md（single source）を参照。本書は各 Axis の評価基準を定義する。

---

## 設計原則: Reviewer = Fresh Agent

判定系 skill（`plugin-audit eval` / `plugin-audit fix` / `harness-audit`）は **必ずサブエージェントで判定** する。メインセッションには作業履歴コンテキスト汚染があり、self-evaluation bias が発生する。

judge / reviewer Agent の既定モデルは `model: "opus"`（`templates/model-policy.json` の `audit` 既定、`audit_alt: "fable"` は任意アップグレード）。

| skill | Reviewer | model |
|-------|---------|-------|
| `plugin-audit eval` | Agent (general-purpose) で各ケース独立判定、複数 Agent で投票 | opus |
| `plugin-audit fix` | Agent (general-purpose) が修正提案、メインで対話承認 | opus |
| `harness-audit` | 死蔵判定など主観の入る軸を Agent (general-purpose) に委譲 | opus |

---

## Axis 1: YAML 構造妥当性

公式 SKILL.md frontmatter **全 19 フィールド** を網羅検証。

| カテゴリ | フィールド |
|---------|-----------|
| 識別 | `name`, `description`, `when_to_use` |
| 引数 | `argument-hint`, `arguments` |
| 発火制御 | `disable-model-invocation`, `user-invocable`, `paths` |
| 実行 | `allowed-tools`, `model`, `effort`, `context`, `agent`, `shell`, `hooks` |
| Open Standard | `license`, `compatibility`, `metadata` |

### ユースケース整合チェック（フィールド間矛盾の検出）

| 矛盾パターン | 検出条件 | 重大度 |
|------------|---------|-------|
| 起動手段なし | `disable-model-invocation: true` + `user-invocable: false` | ❌ Critical |
| 自然言語誤発火危険 | 副作用ある skill（commit / deploy 等）+ `disable-model-invocation: false` | ⚠️ Warn |
| スキーマ違反 | `context: fork` + `agent` 未指定 | ❌ Critical |
| 非公式フォーマット | `allowed-tools` カンマ区切り | ⚠️ Warn（公式はスペース区切り or YAML リスト）|
| 過剰スペック | `model: opus` + 本文 trivial（< 30 行 + 単一機能）| ℹ️ Info |
| サブコマンド未 surface | 本文が `` `<skill> <sub>` `` で documented したサブコマンドが `argument-hint` に出ていない | ⚠️ Warn |
| 機能の空宣言 | `argument-hint` の bareword キーワードが本文に裏付けなし | ℹ️ Info（確認）|

### argument-hint ↔ 実 interface 整合（`plugin-audit-interface.sh`）

スラッシュコマンドを入力したとき実際に出る説明 = `argument-hint`。これが skill の実 interface と食い違うと、機能はあるのに到達できない。CONCEPT の「コマンドはその存在を知らないユーザーにも到達可能であること（intent-first）」を deterministic に担保する:

- **未 surface（⚠ Warn）**: 本文が `` `<skill> <sub>` ``（または `` `/<skill> <sub>` ``）でサブコマンドを documented しているのに、`argument-hint` がそれを列挙していない。ユーザーが `/<skill>` と打っても存在に気づけない。例: plugin-audit の `full`/`eval`/`verify`/`fix`、ws の `switch`/`new`/`multi`/`solo`/`archive`/`import`（いずれも 5.44.0 で修正）。
- **空宣言（ℹ Info・確認）**: `argument-hint` の各セグメントが厳密に bareword（`init` / `eval` 等）なのに本文に一度も現れない = 謳うだけで実装/記載なし。位置引数のプレースホルダ（`export-target-dir（省略時は …）` のような説明付きセグメント）は keyword 扱いせず誤検知しない。

抽出は静的・高精度（サブコマンドのアンカーは `` `<skill> <word>` `` コードスパンに限定）。境界ケースは agent パスが確定する。

### description 文字数キャップ（公式仕様）

- **Open Standard**: description 単独 ≤ **1,024 字**
- **Claude Code**: description + when_to_use 合算 ≤ **1,536 字**
- **動的予算**: コンテキストの 1%、フォールバック **8,000 字**（全 skill 合算）

| Status | 条件 |
|--------|------|
| OK | description (+ when_to_use) ≤ 1,024 字 |
| ⚠️ Warn | 1,024 < 合算 ≤ 1,536 |
| ❌ Hard | 合算 > 1,536（公式合算キャップ違反、表示カット発生）|

---

## Axis 2: 本文構造妥当性

| 項目 | 基準 | 重大度 |
|------|------|-------|
| 500 行ルール | 本文 ≤ 500 行 | ⚠️ Warn 超過 |
| トークン予算 | warn=500 token / hard=1000 token（concat：description + 本文）| 超過時 `references/` 分割推奨 |
| 参照ファイル妥当性 | `[ref](references/foo.md)` のリンク先が実在 | ❌ Critical |
| 内部 skill 参照妥当性 | description / 本文で「X skill」と書いた X が実在 | ⚠️ Warn |
| 3 層 progressive loading 構造 | 大規模 skill が `references/` 分割を採用 | ℹ️ Info |

### 3 層 progressive loading（Perplexity 流）

| 層 | 内容 | トークン目安 |
|---|------|------------|
| Index | description + when_to_use（frontmatter）| ≤ 100 token |
| Load | SKILL.md 本文 | ≤ 5,000 token |
| Runtime | `references/*.md`（必要時のみ Read）| 無制限 |

### シェイプアップ・トリガー（`plugin-audit-shapeup.sh` — 閾値はゲートではない）

skill セットが引き締まり続けるための軽量化シグナル。**重要: ここの閾値はすべて「レビューのトリガー」であってゲート（合否）ではない**。超過は ❌ ではなく「ここを軽量化レビュー」。閾値を低くしても誤って失敗にならず、agent が中身を見て正当なら除外するだけなので、**やや広め（拾いすぎ寄り）**に置く。`shapeup` サブコマンドが各トリガーの中身を agent に渡し、具体的な軽量化案（分割 / 抽出 / rule 化 / 統合）または「正当」を返させる。

| トリガー | 条件 | 根拠 |
|---|---|---|
| 本文肥大 | SKILL.md 本文 > 400 行 | Axis 2 の hard 500 の手前で痩せる |
| サブツリー肥大 | skill サブツリー合計 > 50 KB | 実測で重量級だけを拾う（残りは素通り）|
| 重量集中 | 単一 skill が総重量の > 25% | 突出の検知（将来の暴走ガード）|
| 近似重複 | 連続 8 行以上の実質行が 2 つ以上の skill で同一 | コピペ → 共有 reference/rule へ抽出。8 行は見出し・定型短文を除外しつつ手順ブロック・共通前文を拾う下限（閾値 5 では構造行が偶然一致してノイズ、8 でクリーンと実測で確認）|

死蔵（Axis 11 の `dormant` / `likely-trim`）と assets の巨大 reference / orphan / 重複も同じレビューに集約する。

---

## Axis 3: description ルーティング形式

description は **Skill の起動可否を判断するルーティングトリガー** であり、≤50 語の Index 層トークンとして機能する。

### 検出項目

| 項目 | 基準 | 重大度 |
|------|------|-------|
| "Use when..." 形式 | description 先頭が "Use when..." または同等表現（"...のとき / 場合"）| ℹ️ Info（推奨）|
| **ネガティブ例の有無** | 「使ってはいけない場面」「対象外」「で十分」「専用」など、境界付近のロード抑止例が明示されている | ⚠️ Warn（最重要、Perplexity 公式で primary signal）|
| 50 語以内 | description 本体（when_to_use 除く）が概ね 50 語以下 | ⚠️ Warn 超過時 |
| Index 層トークン超過 | description + when_to_use 合算が 300 token 超 | ⚠️ Warn |

### アンチパターン

- ❌ 「INVOKES: ...」を description に書く → "何をするか" 情報、Index 層に入れるべきでない
- ❌ 「単純な 1 ファイル... で十分」を機械的に全 skill に追加 → ネガティブ例の希釈、precision 悪化
- ❌ キーワード密度を上げる → 境界ケース disambiguation の悪化

---

## Axis 4: 実精度測定（Perplexity 流、`plugin-audit eval` で動的）— routing + functional の2層

本軸は **routing**（正しい skill が発火するか）を測る。発火後に skill が claim 通り機能するかの **functional** 層は `plugin-audit verify` サブコマンド（`references/verify.md`・skill ごと `verify-cases.yaml`）が担い、routing→execution を end-to-end でカバーする。routing の **モデル階層 sweep**（haiku/sonnet/opus）は `eval --tiers` で opt-in（下記）。


`eval/skill-routing.yaml`（または `skills/plugin-audit/eval-cases.yaml`）に **positive / negative / boundary** の 3 種ケースを定義し、Agent サブエージェントで以下 3 指標を計算:

| 指標 | 定義 |
|------|------|
| **Precision** | top-1 が正解と一致した割合（誤発火しないか）|
| **Recall** | 正解 skill が top-K に含まれた割合（取りこぼし）|
| **Forbidden** | "ロードしてはいけない" ケースで非ロードを維持した割合 |

### 実装方針

- 各ケースを **複数 Agent サブエージェントで投票**（汚染回避、bias 低減）
- **モデル階層検証（`eval --tiers` 時必須）**: Opus / Sonnet / Haiku の 3 tier で routing を測り tier 別 Precision を報告。安いモデルで劣化する skill を flag（banto は haiku に委譲する設計＝劣化は本番リスク）。tier 別投票 opus V=1 / sonnet V=3 / haiku V=5。Agent tool の model pin（search/kit で実証）で tier 固定。`--tiers` 明示時のみ全 tier、既定は単一 tier（後方互換）
- ケース種別の比率: positive 40% / negative 30% / boundary 30%
- **境界ケースを最重要視**（過去にここで精度退化を検出した）

---

## Axis 5: HeavySkill 適用妥当性

| カテゴリ | 条件 | アクション |
|---------|------|-----------|
| **推奨** | `allowed-tools` に Agent + 本文に並列/比較/トレードオフ/分岐 + Phase 3 以上 | 4-component テンプレ採用を提案 |
| **不要** | 単一機能 / 機械的手順 / tool 1〜2 個 | 採用しない（現状維持）|
| **既採用** | 4-component 揃ってる | 表示のみ |
| **誤適用** | 単純 skill なのに 4-component 採用 | 軽量化提案 |
| **fan-out 候補**（人が指示せず自動分散の観点）| `allowed-tools` に Agent あり + 本文が独立した複数項目を *逐次* 処理（「各 X を順に実行」等）なのに Parallel Protocol 無し | 並列 fan-out（1 メッセージ内で複数 Agent）を提案。逐次依存のあるタスク・単一機能は対象外 — agent が誤検知を除外する（人は呼び出しを考えない＝自走分散の北極星に直結）|

### HeavySkill 4-component 検出（4 ブロックすべて）

1. **Activation Conditions** / 活性化条件
2. **Parallel Protocol** / 並列プロトコル / Parallel Reasoning
3. **Deliberation** / 審議 / Deliberation Prompt
4. **Output Constraints** / 出力制約

出典: https://arxiv.org/abs/2605.02396

判定は **Agent (general-purpose) に委譲**（Reviewer = Fresh Agent 原則）。

### 既存判定例

- （現状、HeavySkill 4-component をフル採用している skill は無し）
- `plugin-dev`: **推奨候補**
- `plugin-audit`: 部分採用候補
- `status`, `save-checkpoint`: **不要**（単一機能 UTILITY）

---

## Axis 6: Cross-skill disambiguation matrix

skill 同士の境界が曖昧だと Claude のルーティング判断がブレる。

| 項目 | 検出方法 | 重大度 |
|------|---------|-------|
| 双方向参照 | A の description が B を、B の description が A を相互参照しているか | ℹ️ Info（適切）|
| 語彙重複度 | description の trigger 単語 bigram の Jaccard 係数 | ⚠️ Warn > 0.4 |
| 領域カテゴリリング | WORKFLOW / UTILITY / ANALYSIS / META の分類タグ衝突 | ⚠️ Warn |
| 境界曖昧さ | Agent (general-purpose) が「どちらでも該当しうる」と判定 | ⚠️ Warn |

判定: 機械的計算 + Agent 補助。

---

## Axis 7: 汎用性評価

### 検査項目

| カテゴリ | 検出パターン | 種別 |
|---------|------------|------|
| 絶対パス依存 | `/Users/[name]/`, `C:\Users\` 等 | 静的 (regex) |
| 個人名依存 | 特定の GitHub ID / 命名規則のハードコード | 静的 (regex) |
| 組織名依存 | 自社名 / 内部 URL / プライベートリポリンク | 静的 (regex) |
| プロジェクト固有名 | 「Adrite」「banto」等の自己参照 | 静的 (regex) |
| 言語依存 | 日本語のみのトリガー語 / 特定言語の正規表現 | 静的 |
| ツール前提 | Mac 専用 `open -a` / 特定 IDE / 特定パッケージマネージャ | 静的 |
| 業務知識依存 | 社内ルール / 契約条件 / 規程参照 | **Agent 判定** |
| ライセンス互換性 | proprietary 参照先 / 内部限定 doc への link | **Agent 判定** |

### `global` 修飾子による分岐

| チェック項目 | デフォルト | `global` 付与時 |
|------------|-----------|----------------|
| 絶対パス | ✓ ON | ✓ ON |
| 個人名 | ✓ ON | ✓ ON |
| 組織名 | ✓ ON | ✓ ON |
| プロジェクト固有名 | ✓ ON | ✓ ON |
| ツール前提（Mac 専用等）| ⚠️ WARN のみ | ✓ ERROR |
| **言語依存（日本語のみ等）** | **✗ OFF** | **✓ ON** |
| **文化的前提（日本商慣習等）** | **✗ OFF** | **✓ ON** |
| **ライセンス互換性** | ⚠️ WARN | ✓ ERROR |

### 汎用性スコア

- **Generic**: 違反 0、すべての環境で動く（公開可能）
- **Light-locked**: 軽微な依存（OS 専用コマンド等）— 警告
- **Locked**: 個人名 / 組織名 / 絶対パス混入 — エラー、修正対象
- **Org-internal**: 組織内利用前提（明示的に template として分離推奨）

---

## Axis 8: 汎用化適性 / rule 外部化

「コーディング規約」「レビュー基準」「仕様書テンプレ」など、**企業 / プロジェクト / チームごとに変わりうる基準** を skill 内に **ハードコードしているか / `.claude/rules/{topic}.md` から動的読み込みしているか** を判定。

### 検出パターン

- skill 本文に「コーディング規約は ... に従う」「レビュー観点は ...」のような **固定基準** が記述されている
- かつ、その基準が `.claude/rules/{topic}.md` から読み込まれていない（参照解決が単一パス）

→ rule 外部化推奨フラグ ON

### 検出される代表 skill

- `spec`: 仕様書テンプレ → `.claude/rules/spec-template-link.md`
- `concept`: 思想・北極星の判断軸 → `.claude/rules/concept-system.md`
- `knowledge`: ナレッジ体系 → `.claude/rules/knowledge-system.md`
- `ai-context`（sort project）: ドキュメント整理基準 → `.claude/rules/doc-system.md`
- `status`: レポート体裁 → `.claude/rules/status-format.md`

> 注: `review` / `audit` は Anthropic 公式 plugin に委譲。

### 統一 refactor パターン（3 段 fallback）

```
[skill 内のロジック、統一]

1. .claude/rules/{topic}.md を Read（harness-setup.sh / プロジェクト側が配置した rule）
2. なければ → search skill（クエリ展開 + grep ランキング）で store の decisions / docs から意味的に近い記述を探す
3. なければ → skill 内蔵の default を使う
```

---

## Axis 9: Layer 3 ハーネスエンジニアリング整合性

### 検出シグナル（rule 側）

| シグナル | 意味 | 推奨アクション |
|---------|------|--------------|
| `rule_should_path_scope = 1` | rule が `paths:` 無し + 本文に拡張子/glob/manifest 言及あり | `paths:` frontmatter を追加して条件注入に切替（常時注入の context 肥大を回避） |
| `rule_hard_constraint = 1` | rule 本文に「必ず」「禁止」「MUST」「NEVER」等の強制表現あり | rule は確率的遵守（AGENTIF: tool constraint 43.2%）。可能なら PreToolUse hook + `permissions.deny` で deterministic enforce 化（AgentSpec: 90-100% 阻止） |

### 検出シグナル（hook 側）

| シグナル | 意味 | 推奨アクション |
|---------|------|--------------|
| `hook_event = unregistered` | hooks/ 配下のスクリプトが hooks.json に未登録 | dead code 削除 OR hooks.json 登録漏れの修正（_ 接頭辞の helper は例外） |
| `hook_event = PreToolUse` + `hook_blocks = 0` | PreToolUse なのに exit 2 等の阻止パターン無し | tool 実行を実際に止めたいのか、ログ目的なのか再判断（後者なら PostToolUse へ移動も検討） |
| `hook_blocks = 1` の hook 一覧 + `rule_hard_constraint = 1` の rule 一覧の突き合わせ | rule の hard_constraint が hook で deterministic enforce されているか | 人間が semantic match を判定 — 未カバーがあれば hook 追加検討 |

### 出力

- **Warning**: path-scoped 化推奨ファイル一覧（rule）
- **Info**: hook enforce 候補ファイル一覧（rule、変換可能性は人間判断）
- **Hook 一覧**: event / matcher / 阻止・警告パターン一覧
- **Critical**: hooks.json 未登録 hook script（dead code 候補）
- **Warn**: 阻止パターン無しの PreToolUse hook（意図不明確）
- **Coverage チェック**: hard_constraint rule × block hook の並列リスト（手動レビュー起点）

### 想定される False Positive

- rule 本文の **例示** で拡張子を書いている場合（例: `evidence-first.md` の中で `*.md` を例として書いている）
- 「禁止事項」セクション見出しを持つ rule（hook 化に向かない概念的禁止）
- `_` 接頭辞の helper script（意図的に hooks.json に未登録、source 共通化用）

これらは推奨で、強制ではない。最終判断は人間が行う。

---

## Axis 10: ODD (Operational Design Domain) 適用状況

### 適用条件（ODD 採用プラグインのみ検査）

ODD は banto 発の任意機構であり、Claude Code 公式プラグイン仕様には存在しない。本軸と schema lint は**採用プラグインのみ**に適用する:

- **採用判定**: 対象プラグインの `skills/*/odd.yaml` が 1 つでも存在すれば「ODD 採用」とみなす
- **採用プラグイン**: 下記の検出シグナル + schema lint を全て実施する（部分採用のドリフト検出が本軸の仕事）
- **未採用プラグイン**: 本軸は N/A（「ODD 未採用 — 任意機構」の 1 行のみ）。未適用 Warning は出さない。提案を出してよいのは下記「リスク駆動推奨」の条件を満たす場合だけ

### 検出シグナル（skill のみ評価・採用プラグイン限定）

| シグナル | 意味 | 推奨アクション |
|---------|------|--------------|
| `has_odd_yaml = 0` | 採用プラグイン内で odd.yaml が無い skill（部分採用ドリフト） | L1-L3 skill では推奨。L0 軽量 utility（search / status 等）は 10 行ルールで適用任意 |
| `odd_autonomy_level = L4 / L5` | autonomy_level が banto 範囲外 | 別 plugin (`banto-autonomy`) に分離するか autonomy_level を見直し |
| `has_odd_yaml = 1` + `odd_autonomy_level = empty` | odd.yaml はあるが autonomy_level 抽出失敗 | フォーマット確認（`autonomy_level: L2  # ...` 形式必須） |

### 出力

- **サマリ**: ODD 適用率 + autonomy_level 分布（採用プラグインのみ）
- **Warning**: ODD 未適用 skill 一覧（採用プラグイン内のみ。L0 含む全件、人間が L0 任意性を判断）
- **Critical**: autonomy_level が L4 / L5 の skill 一覧
- **Info**: autonomy_level 抽出失敗一覧（フォーマットエラー）
- **N/A**: 未採用プラグインは 1 行のみ（`plugin-audit-report.sh` / `plugin-audit-odd.sh` とも）

### リスク駆動推奨（未採用プラグイン向け・このテンプレートが正本）

presence 推奨はしない — 「odd.yaml を置きましょう」という名前だけの指摘は禁止。監査中に次のいずれかの高リスクシグナルを持つ skill を検出した場合に限り、**Info で 1 回だけ**セット採用（odd.yaml + schema lint の CI 配線 + enforcement hook）を提案する:

- 自律ループ（自走実装・反復実行・自動リトライを宣言する skill）
- 破壊的操作（削除・履歴書き換え・本番環境変更）
- 並列 agent fan-out
- 対外操作（push / PR / 外部サービスへの公開・投稿）

推奨文には次の 4 点を必ず含める（名前だけの推奨は不可）:

1. **ODD とは**: skill 単位の運用設計領域宣言（`odd.yaml`）。自律度（autonomy_level L0-L3）・in_scope / out_of_scope・kill-switch 条件を機械可読で固定する
2. **効果**: 宣言単体では何も強制しない。enforcement hooks（kill-switch / parallel-track / cost-gate 等）+ schema lint の CI 配線とセットで初めて、決定論的な安全境界として機能する
3. **メリット**: 自律境界が監査可能になる / kill-switch と連動できる / 採用解釈の許容範囲（spec-fidelity 系ルール）を autonomy_level で機械的に決められる
4. **デメリット**: 宣言の維持費が掛かる（skill の挙動変更のたびに odd.yaml も更新が要る）。構造ドリフトは lint で捕まるが、宣言した autonomy_level と実挙動の意味ドリフトは lint では捕まらず、定期的な監査が要る

維持費が価値を上回る低リスクのユーティリティプラグインには、推奨自体を出さない。

### schema lint（`plugin-audit-odd.sh` — deterministic）

presence / autonomy 抽出だけでなく **odd.yaml の構造妥当性**を `templates/odd/odd.schema.yaml` で検証する。odd.yaml が 1 つも無いプラグインは採用ゲートで N/A 1 行を出して終了する（未採用プラグインに per-skill warn を出さない）。並走セッションの revert や貼り戻しで odd が pre-schema 形（`domain:` ラッパ・`human_oversight` の混入・`.ai-context/` パス等）へ崩れるのは diff 目視では見落とすため、CI / SessionStart で deterministic に弾く:

| 検査 | 重大度 |
|---|---|
| required キー欠落（`schema_version` / `skill` / `autonomy_level` / `in_scope` / `out_of_scope`）| ❌ FAIL |
| 未定義キー（schema `additionalProperties:false`。例: `domain` / `guardrails` / `human_oversight`）| ❌ FAIL |
| `autonomy_level` が L4/L5（banto 範囲外）または非 Lx | ❌ FAIL |
| `skill:` 値がディレクトリ名と不一致 | ❌ FAIL |
| `schema_version` ≠ 1 / `in_scope` が空 | ❌ FAIL |

`--strict` で違反時 exit 1。パス綴りの skill 間ドリフト（`{base}` / `<base>` / `.ai-context`）は Axis 15（`plugin-audit-consistency.sh`）が担当（役割分担）。

### 想定される False Positive

- L0 (Manual) skill は ODD spec が trivial（in_scope / out_of_scope の数行で済む）ため、適用しない判断もあり得る
- 過渡期の skill（odd.yaml 整備前）が一時的に Warn 表示される

これらは Warn として扱い、Critical 扱いしない。L4/L5 のみ Critical（plugin 境界違反）。

---

## Axis 11: 使用度（`plugin-audit-usage.sh`）

過去 N 日（既定 30）の git log 言及 + `{base}/{decisions,docs}` 内言及 + SKILL.md 最終更新日を集計し、各 skill を 4 分類する。

| カテゴリ | 条件 | アクション |
|---|---|---|
| `active` | commits ≥ 3、または commits ≥ 1 かつ mentions ≥ 10 | 維持 |
| `mentioned` | commits ≥ 1、または mentions ≥ 5 | 安定（要観察なし）|
| `dormant` | mentions ≥ 1 のみ | ⚠ 統合 / 削除を検討 |
| `likely-trim` | commits ゼロ・mentions ゼロ | ⚠️ rule 化 / 統合 / 削除を強く推奨 |

実行:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh <plugin_dir> [since_days]
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh --skill <skill_dir> [since_days]  # per-skill
```

## Axis 12: 権限スコープ最小性 — 12a 過剰付与 / 12b 宣言漏れ（static `permissions` + agent 判定）

`allowed-tools` が **必要最小**かを検査。MS Agent Governance Toolkit の「構造的に実行不可能にする」原則。

`plugin-audit-permissions.sh` が静的候補を生成（宣言 `allowed-tools` vs 本文+references の idiom ベース実使用突合）→ Agent が確定。スコープ付き許可（`Bash(git:*)`）は base tool で照合、Agent/Task は同一ツール扱い。

| 検査 | サブ軸 | 重大度 |
|---|---|---|
| 書き込みなし skill が `Write` / `Edit` を持つ | 12a over-grant | ⚠️ Warn（過剰許可）|
| 表示のみ skill（L0）が `Bash` / `Agent` を持つ | 12a over-grant | ⚠️ Warn |
| 宣言したツールの使用 idiom が本文に皆無 | 12a over-grant | ℹ️ Info（drop 候補）|
| 本文が idiom でツールを使うのに `allowed-tools` 未宣言（runtime block）| **12b under-declare** | 🔴 High（runtime で実 block＝実害。over-grant より重い）|
| `Bash(*)` のワイルドカード許可（特定コマンドに絞れる場合）| 12a over-grant | ℹ️ Info |

静的パスは候補生成（prose-noisy な Read/Write/Edit は `?` 付き）。最終判定は Agent（Reviewer = Fresh Agent）が prose 誤検出を解消して確定。

## Axis 13: 封じ込め整合（agent 判定、hook 対象）

hook が含むコマンドの危険度・unsandboxed 操作を検査。Anthropic「How We Contain Claude」の 3 層防御（環境 / モデル / 外部コンテンツ）の environment 層相当。

| 検査 | 重大度 |
|---|---|
| hook が `rm -rf` / `curl \| sh` / `eval` 等の危険パターンを含む | ❌ Critical |
| hook が `.env` / secret を生出力（mask なし）| ❌ Critical |
| hook が外部ネットワークアクセス（想定外の curl/wget）| ⚠️ Warn |
| PreToolUse hook が timeout 未設定で重い処理 | ℹ️ Info |

## Axis 14: Content hygiene（collect 列 47 + registry 駆動の列 34 + assets サブツリー）

skill / agent / rule の文章中に「ドキュメントに居てはいけない内容」が混入していないかを検査する
（公開前の一回きり監査を常設検査に昇格させた位置づけ）。

| 検査 | 検出方法 | 重大度 |
|---|---|---|
| 固有情報（内部メンバー名・client 名） | **registry 駆動**（`~/.claude/banto-name-registry` のリテラルを OR 結合。registry 不在なら no-op = fail-open。**検査 script に名前をハードコードしない**） | ⚠️ Warn（公開物なら ❌ 扱い） |
| 個人の絶対パス / email | 既存 Axis 7（abs_path_count / email_count） | ❌ Locked |
| 貼り込まれた実行結果・セッション残骸 | `HYGIENE_RUNLOG_PAT`: `^exit=N` / ✓✗ 結果行 / "ALL PASS" / subagent_tokens / duration_ms= / tool 一時パス（/private/tmp/claude\*, /var/folders/）/ 秒付き datetime（log 行） | ⚠️ Warn |

- **Warn の扱い**: ヒット = 即 NG ではない。意図的な表示フォーマット仕様（例: あるスキルの「✓ Created...」完了サマリのテンプレ定義）は正当。dogfood 中に貼り込まれた実行結果・task notification 断片は除去する。レポートはファイル + ヒット数を列挙し、人間（または上位 audit）が判定する。

### サブツリー拡張（`plugin-audit-assets.sh`）

`collect.sh` は **SKILL.md のみ**を行として拾うため、`references/*.md` とネストした全ファイルが上記の hygiene 検査から漏れる。index 型 skill ほど中身が reference に寄り（例: ai-context は本体の大半が 9 個の reference 側）、内部名・固有情報の漏れはむしろ reference に溜まりやすい。これを `plugin-audit-assets.sh` が `skills/*/` のサブツリー全体を走査して埋める:

| セクション | 内容 | 軸 | 重大度 |
|---|---|---|---|
| 1 目録 | skill ごとの files / bytes / lines（重い順）— どこに重量が集中するか | Axis 2 | ℹ Info |
| 2 不要ファイル | `.DS_Store` / `Thumbs.db` / `*.bak\|.old\|.tmp\|.orig\|.rej\|.swp` / `*~` / `*.pyc` / `__pycache__` / `*.log` + 空ファイル | Axis 2 | ❌ 除去 |
| 3 orphan reference | SKILL.md からも兄弟 reference からも basename が参照されない = 到達不能な死に荷 | Axis 2 | ⚠ 確認後に除去/リンク |
| 3b dangling 参照 | サブツリーの任意ファイルが指す `references/X.md` の実体が無い（markdown リンク / コードスパン / 散文。orphan の逆向き。クロス参照 `skills/<other>/...` とプレースホルダ名は除外）| Axis 2 | ❌ 壊れたポインタ — 修正/除去 |
| 4 軽量化候補 | 500 行超の reference（Runtime 層は無制限だが、重い順に分割/削減の好標的） | Axis 2 | ℹ Info |
| 5 重複ファイル | cksum 一致 = 内容同一（0 バイトは除外）→ 共通化候補 | Axis 2 | ℹ Info |
| 6 hygiene | 上記 3 パターン（runlog / 絶対パス / email / registry 名）を **非 SKILL.md ファイル**にも適用 | Axis 14 | ⚠ Warn |

パターンは `collect.sh` を source of truth として共有（重複定義はヘッダコメントで明示）。registry 不在なら名前検査は no-op（fail-open）。

### Axis 14 semantic モード（agent 審査 — regex で捕まらない混入）

静的 regex の上に、**ファイル単位の agent 審査**を重ねる
（実行タイミング: 公開前ゲート必須 + `plugin-audit global` 時）。各 skill / agent / template
**および各 skill の `references/` + ネストしたファイル**（`assets.sh` セクション 6 のヒットを優先入力）を
subagent に渡し、次の 3 問で判定させる:

| 問 | 判定基準 | 例 |
|---|---|---|
| **Q1 関連性** | 全セクションがその skill の宣言責務（description）に資するか。他 skill の指示・どの skill にも属さない段落・編集残骸の混入を flag | spec skill の中に research の手順が書いてある 等 |
| **Q2 一般性** | **一般知識の範囲内か**。プロダクト自身の設計参照（banto のアーキテクチャ・store レイアウト等）は正当。**特定組織の業務慣行・社内プロセス・特定客先の業務ルール**が「一般論のように」書かれていたら flag。テンプレは特に厳格（BRD/spec/規範の業界一般形のみ） | テンプレに特定社の稟議フロー・独自契約慣行が混入 等 |
| **Q3 残骸** | regex をすり抜けた貼り込み（会話断片・「〜した結果」型の経緯記述・一時的なメモ） | 「前回のセッションで判明した通り」等 |

- 出力 schema: `{file, quote(短い引用), type: irrelevant|non-general|debris, severity, suggested_fix}`
- 修正は review-then-fix（agent は報告のみ。書き換えは人間 or 上位セッションが判定後に実施）


---

## Axis 15: Cross-skill 参照整合 / 相関（`plugin-audit-consistency.sh`）

**問い**: 全 skill が「同じ場所」を**同じ綴り**で参照しているか。store-map-lint がマニフェスト（`store-layout.json`）対照で「誤ったパス」を検出するのに対し、本軸は**マニフェスト無しで**「同一 store サブパスが複数の接頭辞で綴られている乖離」をクラスタリングで炙り出す。

検査（`plugin-audit-consistency.sh <plugin_dir>`）:
- **Check 1（綴り不一致）**: 全 `*.md` / `odd.yaml` から `(\{base\}|\{BASE\}|<base>|.ai-context)/<subpath>` を抽出。同一 `<subpath>` が 2 つ以上の接頭辞で綴られていれば乖離として file:line 付きで報告（例: `docs/research` が `{base}` と `{BASE}` の両方で参照）。
- **Check 2（接頭辞分布）**: 接頭辞の出現数を集計。正準は `{base}`。`{BASE}` / `<base>` / `.ai-context`（非 legacy 行）は非正準として件数提示。
- **Check 3（命名形式）**: decisions / checkpoint / research の日付形式が複数併存していれば指摘（decisions の `YYYY-MM-DD` ↔ `YYYY-MM-DD-HHMMSS` 併記は grandfather 仕様として info 扱い・是正不要）。

判定:
- 綴り不一致 / 非 legacy の命名不一致があれば Critical 寄り（宣言の腐敗源・revert やコピペで増殖する）。`{base}` への正準化を提案。
- legacy 対比行（「legacy は…」「旧来」）と bare-path のスキャン除外リスト（`.ai-context/sessions,` 等）は意図的として除外済み（誤検知を出さない）。
- 既定監査（static パス）で常時実行。`--strict` は乖離時 exit 1。

> 関連: store の**構造**整合（フォルダ↔skill↔実体）は store-map-lint（harness-audit Axis 3）が、skill 間の**綴り**整合は本軸が担う。両者で「宣言の腐敗」を二面から塞ぐ。

## 参照

- 公式 plugin docs: https://code.claude.com/docs/en/plugins
- Perplexity skill routing: https://research.perplexity.ai/articles/designing-refining-and-maintaining-agent-skills-at-perplexity
- HeavySkill: https://arxiv.org/abs/2605.02396
- 検証データ: `skills/plugin-audit/eval-cases.yaml`（routing eval cases）
