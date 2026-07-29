---
name: spec
description: |
  実装の前に、業界標準の仕様書（spec）を対話的に生成する。思想は上流（concept skill）、実装は下流（concept → spec → 実装、自走）。
  トリガー: 「spec」「仕様書作って」「まず設計だけして」「設計だけ見せて」「plan」「実装しないで設計だけ」「仕様整理」「要件整理」。設計だけを求められたときに発火する。
  使わない場面: 思想/コンセプトから始める場合（concept を使う）、設計と実装の両方を求められた場合（spec を回してからそのまま実装へ進む、自走）。
user-invocable: true
argument-hint: "[実装したい機能や課題 / スペック種別]"
model: opus
allowed-tools: Read Grep Glob Bash(git:*) Agent Write Edit
compatibility: Claude Code (requires bash, git, jq)
---

# Spec — 対話的スペック駆動設計（仕様書生成）

> **パイプライン上の位置**: `concept（思想） → **spec（この skill、設計書）** → 実装（自走）`。思想がまだ無ければ、先に `/concept` を回す。CONCEPT.md があれば、その「アンチゴール」と「北極星」を spec の判断軸として引き継ぐ。画面や UI が絡む場合は、先に design-brief skill でデザインブリーフを作ってから進む。

> **保存ベース（store-first）**: 保存先は `{base}/docs/specs/...`（ADR のみ `{base}/decisions/`）。`{base}` は SessionStart/PreCompact hook が注入する ai-context ベースの絶対パス（不明なときは `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決）。

コードを書く前に、対話を通じて**業界標準の仕様書**を生成する。`spec-fidelity` ルールに従い、「ゴール分岐」のときだけ事前確認し、それ以外は採用解釈で進める。

生成するドキュメントはユーザーの会話言語で書く（ユーザーが日本語で会話していれば日本語）。テンプレートのラベルは例示である。

## 前提: 6 種のテンプレート

`${CLAUDE_PLUGIN_ROOT}/templates/specs/` が業界標準 6 種（Spec Kit / PRD / Design Doc / RFC / ADR / Scope Doc）を提供する。各フォーマットの用途・工数・対応 Tier は Step 2 の選択肢文言、および `${CLAUDE_PLUGIN_ROOT}/templates/specs/README.md` が正本。Claude が**対話を通じてどれを使うか決める**。

## 対話フロー（標準）

### Step 1: 引数を解析

- `$ARGUMENTS` が `spec-kit` / `prd` / `design-doc` / `rfc` / `adr` / `scope` で始まる → そのフォーマットを直接採用し、Step 3 へ
- それ以外（トピック名のみ / 空） → Step 2 の対話へ

### Step 2: フォーマット選択の対話（**必須**）

以下をプレーンテキストで提示する（ユーザーの会話言語で）:

```
Which spec format should we use?

1. Spec Kit (3-file set) — recommended for AI coding, TDD-based, Tier 1-4
2. PRD — business requirements doc, PM-driven, Tier 2-4
3. Design Doc — detailed technical design, Google style, Tier 2-4
4. RFC — change proposal, team consensus, alternatives included, Tier 3-4
5. ADR — short post-decision record, Tier 1-4
6. Scope Doc — scope boundary agreement, rework prevention, Tier 3-4

If unsure, "1. Spec Kit" is the recommendation (the standard of the AI-coding era).
Combinations are fine too: you can specify "1 + 5", "2 + 3", etc.
```

回答を得てから Step 3 へ進む。

### Step 3: 要件分析（コードを読むだけ、何も書かない）

関連コードを読んで整理する:

```
## Requirements
- What to achieve
- Who uses it
- Where it impacts the existing code

## Constraints
- What must not change (public APIs, DB schema, etc.)
- Technical constraints
- Time constraints

## Adopted interpretations (items the request did not specify)
- Confirm in advance, in plain text, only the items that are goal forks (where option A/B changes the acceptance criteria)
- For everything else, decide an adopted interpretation, proceed, and disclose it in the Step 7 final report
```

**重い分析は `architect` subagent に委譲する**（親コンテキストの肥大化を避ける）:

```
Agent(
  subagent_type="architect",
  description="Design impact analysis",
  prompt="ai-context base: {resolved absolute base path}. First Grep {base}/decisions/ for prior decisions conflicting with this theme. Then investigate the existing-code impact surface, constraints, and trade-offs for implementing {feature name}. Do not change any code; return a list of related files + impact assessment + pros/cons of candidate options A/B/C."
)
```

**ai-context ベースは必ず解決してプロンプトに渡す**（subagent は SessionStart の注入を受け取らない。ベースが無いと architect は `decisions/` を確認できない）。

判断基準: **関連ファイルが 5 個超** / 複数モジュールに跨る / 既存の設計判断と衝突しうる → architect に委譲。1-2 ファイルに収まる小さな spec なら、メインセッションで直接読む。

### Step 4: UI を含む場合は Claude Design ハンドオフ

詳細手順: [`references/claude-design-handoff.md`](references/claude-design-handoff.md)

対象が UI を含む場合の最小手順:
1. Claude Design（claude.ai/design、Pro/Max 限定・Research Preview）の使用可否をテキストで確認する
2. Yes → Goal / Layout / Content / Audience の 4 要素をユーザーに入力させ、Claude Design でプロトタイプを作る
3. プロトタイプ完成後 "Hand off to Claude Code" でバンドル ZIP（README.md + prototype.html + assets/）を生成 → `docs/specs/designs/{topic}/` に保存
4. バンドルの README.md を Read し、既存コードベース規約に沿って実装する
5. No / Pro 未満 → フォールバック（v0.dev / Figma + Figma MCP / Design Doc 内のテキスト UI）へ

### Step 5: テンプレートを適用

選択したフォーマットのテンプレートを `templates/specs/` から読み、`{{variables}}` を埋め、`docs/specs/` 配下に spec を生成する:

- 保存先: `docs/specs/{YYYY-MM-DD}_{topic-slug}_{type}.md`
  - 例 `docs/specs/2026-04-20_auth-redesign_spec.md`
  - 例 `docs/specs/2026-04-20_auth-redesign_plan.md`
  - 例 `docs/specs/2026-04-20_auth-redesign_tasks.md`
- ADR だけは `decisions/ADR-{NNNN}_{topic}_{user}.md` へ（連番）

Spec Kit を選んだ場合は、**3 ファイルを順番に生成する**（spec → plan → tasks）。

> **台帳の役割分担**: `_tasks.md` は**計画台帳**（Phase 構成・依存・受け入れ条件）。実行のライブ台帳は
> WS の `tasks.md`（`workspaces/<author>/<topic>/tasks.md`）であり、`_tasks.md` は節目（Phase 完了・
> 設計変更）にのみ同期する。この一文を生成する `_tasks.md` の冒頭にも必ず含める（二重台帳ドリフト防止）。

### Step 6: AI の境界を明示（**必須**）

生成するすべての spec に、3 段階の ✅ Always / ⚠️ Ask first / 🚫 Never セクションを含める:

```
## Scope boundaries

### ✅ Always (always do this)
- ...

### ⚠️ Ask first (confirm with the user before judging)
- ...

### 🚫 Never (absolutely never)
- ...
```

これが無いと、AI が推測で穴を埋めてしまう（`spec-fidelity` ルール）。

### Step 7: 採用解釈レポート（最終報告、承認待ちなし）

spec 生成が完了したら、以下を提示する:

```
## Adopted-interpretation report: {topic}

- Saved to: docs/specs/{filename}
- Format: {selected format}
- Key decisions (3-5 line summary):
  - ...

### Adopted interpretations (items the request did not specify)
- Ambiguity N: {what was ambiguous}
  - Adopted: {how it was interpreted}
  - Alternative: {the option not taken, and why}

### Verification
- Spec consistency check results

→ "The spec was created with adopted interpretations. If you dislike any, we can roll back."
```

**設計だけを求められた場合は、ここで止める。** 実装の指示が出るまでコードは書かない。

### Step 8: 次ステップの案内

ユーザーが「実装して進めて」/「続けて」と言ったら、**別の skill を起動せずにそのまま自走実装へ進む**（Claude が設計 → 実装 → テスト → レビューを駆動する）:
- `/ai-context next` → tasks.md の最初の未完了タスクから順に実装する
- 独立したタスクが複数あれば、1 メッセージで複数の Agent を起動する（自走 fan-out。モデル選定はメイン AI の判断 — quality.md の粒度・並列度規範に従う）

## 組み合わせフォーマット

ユーザーが複数選んだ場合（例: 「1 + 5」 = Spec Kit + ADR）:

- Spec Kit の 3 ファイルセットを生成 + 重要な技術判断を ADR に抽出する
- PRD + Design Doc は大規模プロジェクトでよく組み合わせる
- RFC + ADR は「提案 → 決定」の流れを記録する

## ティアごとの推奨

Tier 別の推奨組み合わせ（個人〜エンタープライズ）は `${CLAUDE_PLUGIN_ROOT}/templates/specs/README.md` が正本。ティアが指定されなければ、Spec Kit を推奨してユーザーの判断を仰ぐ。

## Status ライフサイクル（spec を閉じる）

spec の front-matter / Status 行は生き物として扱う（decision 2026-07-17。監査で「Draft のまま出荷済み」が常態化し誤答源になっていた）:

- 生成時: `status: draft` を YAML front-matter に書く（`date` / `topic` も。prefix-check hook が欠落を警告する）
- 実装完了・出荷時: **Status を `shipped`（+ 版数・日付）へ更新して閉じる**。実装した本人（dev-loop / 自走セッション）の完了報告に含める
- 設計が覆ったとき: 覆した decision を書いたその場で、旧 spec の Status を `superseded` にし冒頭へ「→ 最新: {decision パス}」注記を追記する（検索 v3.2 が status を見て自動降格する）

## 禁止事項

- ❌ spec を書いている間に実装コードに触れる（設計と実装は厳密に分離）
- ❌ テンプレート変数 `{{...}}` を「あとで」と未記入のまま残す（採用解釈で埋め、Step 7 で開示する）
- ❌ ゴール分岐レベルの曖昧さを採用解釈で進める（事前確認が必須）
- ❌ 設計だけを求められたのに実装まで進む（設計で止まる）
- ❌ 実装完了後に spec の Status を Draft のまま放置する（上記ライフサイクルで閉じる）

## 関連

- テンプレートインデックス: `${CLAUDE_PLUGIN_ROOT}/templates/specs/README.md`
- `spec-fidelity` ルール: `~/.claude/rules/spec-fidelity.md`
