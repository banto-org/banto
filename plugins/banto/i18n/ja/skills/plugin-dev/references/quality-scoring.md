# skill / agent / rule の品質スコアリング基準

品質スコアリングの正本は `skills/plugin-audit/references/scoring.md`（15 軸）。plugin-dev は scaffold 時にそこを参照する。15 軸スコアリング・description 文字数キャップ（1,024 / 1,536 字）・トークン予算（warn 500 / hard 1,000）はそちらが唯一の正本であり、本ファイルでは重複させない。

本ファイルが持つのは、plugin-dev 自身の仕事である **authoring 補助** のみ：検出語彙の二言語対応表と、description テンプレ（日本語版 / 英語版）。

## 検出語彙の二言語対応表

スキル description / 本文に書く 4 ブロックの対応:

| 要素 | 日本語キーワード | 英語キーワード|
|------|-----------------|--------------------------|
| **トリガー** | `トリガー：`、`使うべき場面：` | `USE FOR:`、`Use when:`、`USE PROACTIVELY` |
| **除外条件** | `使ってはいけない場面：`、`〜なら別`、`〜だけなら〜で十分` | `DO NOT USE FOR:`、`DO NOT USE` |
| **INVOKES** | `依存：`、`呼び出す：`、`〜に誘導` | `INVOKES:` |
| **単純操作切り分け** | `単純な〜なら〜で十分`、`軽微なら直接 Edit` | `FOR SINGLE OPERATIONS:` |

英語キーワードは microsoft/skills が標準採用。日本語キーワードは banto 固有。
プロジェクトに合わせてどちらかを統一して使う。

## 推奨 description テンプレ（日本語版）

```yaml
description: |
  **WORKFLOW SKILL** — {何をするか、三人称、簡潔に}。
  トリガー：「{典型ユーザー発話 A}」「{B}」「{C}」
  使ってはいけない場面：{除外条件 / 別 skill との切り分け}
  依存：{INVOKES} search skill、Bash、research-agent
  単純な {小規模ケース} なら {代替手段} で十分。
```

## 推奨 description テンプレ（英語版 / Open Standard 互換）

```yaml
description: |
  **WORKFLOW SKILL** — {What this skill does, 3rd person}.
  USE FOR: {trigger phrases A}, {B}, {C}.
  DO NOT USE FOR: {exclusion / other skill boundary}.
  INVOKES: {dependencies, e.g. Read, Grep, Agent(researcher)}.
  FOR SINGLE OPERATIONS: {fallback for trivial cases}.
```

description は 100〜500 字程度の簡潔さを推奨（自動発火判定の精度向上）。文字数キャップの正確な値は `references/skill-md.md` の「description 文字数」を参照。

## skill 分類プレフィックス

正本は `references/skill-md.md` の「skill 分類プレフィックス」。description / 本文の冒頭に `**WORKFLOW SKILL**` / `**UTILITY SKILL**` / `**ANALYSIS SKILL**` を付ける。

## 関連

- HeavySkill 4-component → `references/heavyskill-template.md`
- skill 設計パターン → `references/skill-design-patterns.md`
- 既存 SKILL.md テンプレ → `references/skill-md.md`
