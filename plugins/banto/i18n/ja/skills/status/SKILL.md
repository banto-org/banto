---
name: status
description: "ステータス報告を [Status] ドキュメントとして保存。引数なしで tasks.md + 直近の作業から自動生成、引数ありで指定期間の報告を作成（進捗率は SessionStart が自動注入するため手動サブは廃止）。トリガー：「進捗」「進捗どう」「状況」「ステータス」「報告」「進捗報告」「どこまで進んだ」。/status でも呼び出し可能。Do not use when: 設計判断の記録（ai-context の decisions/）、会話のメモ保存（memo）、セッション状態の保存（save-checkpoint）、外部リサーチ（research）には使わない。"
user-invocable: true
argument-hint: "[期間（省略時は自動生成）]"
allowed-tools: Read Write Glob Bash
compatibility: Claude Code (requires bash, git, jq)
---

# [Status] ステータス報告

Output language: write the report in the user's conversation language; the template labels are illustrative — translate them to match.

> **保存先ベース（store-first）**: 本 skill 内の `.ai-context/...` は ai-context ベースを指す。SessionStart/PreCompact hook が注入する「ai-context ベース: &lt;絶対パス&gt;」配下を Read/Write し、相対 `.ai-context/` には書かないこと（相対が実在するのは grandfather な legacy repo のみ）（不明なら `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`）。

**パターン**: B（テンプレ埋め型）— 共通骨格は `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` を参照
**保存プレフィックス**: `[Status]`

## Step 1: モード判定

- **引数なし** → 自動生成モード（保存あり）
- **期間指定**（例: 「今週」「3 月」「Sprint 5」） → 指定期間の報告（保存あり）

## Step 2: モード別処理

### 2a. 引数なし（自動生成）

1. 実効 tasks ファイル（SessionStart の「進行中タスク」見出しのパス。新 layout=`workspaces/<author>/<topic>/tasks.md`、legacy=`tasks/active.md`）を読んでタスク状況を確認
2. `git log --oneline -10` で直近コミット確認
3. `.ai-context/decisions/` の直近ファイル確認
4. 上記から「完了した作業」「進行中」「次のアクション」を生成

### 2b. 期間指定

`$ARGUMENTS` の期間に基づいた報告を生成して Step 3 へ。

## Step 3/4: 保存 + 報告（2a / 2b のみ）

固有テンプレート:

```markdown
# [Status] {期間}

- **日付**: YYYY-MM-DD
- **作成者**: AI

## 期間
{対象期間}

## 完了した作業
-

## 進行中の作業
-

## ブロッカー・課題
-

## 次のアクション
-
```

共通パターンに従う（`_common-pattern.md` §2 パターン B / §3 命名ルール / §4 報告フォーマット / **§1.6 文体規約**）。日本語の報告本文は `~/.claude/rules/writing-ja.md` に従う（体言止め / 文末の だ・である・です・ます 不使用 / カタカナ英語を減らす / 英数字前後に半角スペース / 数字を丸めない）。
