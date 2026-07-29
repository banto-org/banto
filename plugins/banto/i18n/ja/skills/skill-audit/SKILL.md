---
name: skill-audit
description: |
  **分析スキル** — skill 単体をコンテキストエンジニアリング視点で監査する（vs plugin-audit は plugin 全体を 15 軸で見る）。7 軸: 情報の最小性 / 人間専用情報の混入 / 構成の分担 / 実行モデル指定の適切さ / コンテキスト効率 / 想定 AI の明示と整合 / 決定論との分担。
  トリガー: 「skill 監査」「スキル監査」「この skill を監査」「コンテキストエンジニアリング監査」「skill の品質チェック」。/skill-audit でも呼び出し可能。
  使わない場面: plugin 全体の構造監査（plugin-audit）、ハーネス全体のシステム監査（harness-audit）、skill の生成・改修（plugin-dev）。
user-invocable: true
argument-hint: "[skill パス（省略時はカレントディレクトリの skill を推定）]"
allowed-tools: Read Grep Glob Bash Agent
compatibility: Claude Code (requires bash, jq)
---

# Skill Audit — skill 単体のコンテキストエンジニアリング監査

出力言語: 応答は会話言語で書く（日本語なら `writing-ja.md` 準拠）。

**plugin-audit との役割分担**: plugin-audit は plugin 全体（または `skills/<name>` 引数で単一 skill）を公式準拠 + 15 軸で品質スコアリングする。skill-audit は 1 skill に絞り、実行に必要な情報だけを渡せているかという**コンテキストエンジニアリング**だけを見る、より狭く深い監査。plugin-audit の判定材料が公式フィールド網羅・使用度・権限中心なのに対し、skill-audit は情報密度・人間専用情報の混入・実行モデル整合・想定 AI 整合に絞る。

対象: `$ARGUMENTS`（省略時はカレントディレクトリが `skills/<name>/` ならそれ、そうでなければユーザーに確認する）。以降 `TARGET` と呼ぶ。

想定 AI: skill 本文に「汎用」「ChatGPT」「他の AI」等の明示が無ければ Claude（Claude Code）前提で監査する（詳細は [`references/axes.md`](references/axes.md) の A6）。

## 実行

1. [`references/procedure.md`](references/procedure.md) の手順で `scripts/skill-audit-metrics.sh` を実行し、機械計測を得る
2. [`references/axes.md`](references/axes.md) の 7 軸それぞれを、機械計測 + Read した TARGET の内容（SKILL.md と references/ 全ファイル。scripts/ があれば docstring も）で判定する
3. 想定 AI との整合判定（A6）等、主観の入る軸は Agent（general-purpose、model: opus）に委譲する（Reviewer = Fresh Agent 原則。plugin-audit / harness-audit と同一原則）
4. 軸ごとに PASS / WARN / FAIL + 根拠行番号 + 修正案 1 文で報告する（レポート形式は procedure.md）

修正の適用はユーザー承認後（監査自体は read-only）。

## 禁止事項

- ユーザー承認なしの自動修正禁止
- plugin 全体の監査（plugin-audit の役割）を代替しない

## 参照

- Skills（公式）: https://code.claude.com/docs/en/skills
