---
name: memo
description: |
  **UTILITY SKILL** — 会話内容を [Memo] ドキュメントとして .ai-context/docs/ 配下に保存する。
  トリガー: 「メモして」「メモに残して」「メモにまとめて」「書き留めて」「この会話を要約して保存」。/memo でも起動可。
  使わない場面: 設計判断の記録（ai-context skill の decisions/）、セッション状態の保存（save-checkpoint）、ナレッジ下書きの昇格（knowledge）、外部リサーチ（research）、ステータス報告（status）。「決定」「採用」「保存」「チェックポイント」「進捗」では発火しない（それぞれ ai-context / save-checkpoint / status の担当）。一行メモなら直接 `echo > file` で十分。
user-invocable: true
argument-hint: "[メモしたい内容（省略時は会話要約）]"
allowed-tools: Read Write Glob
compatibility: Claude Code (requires bash, git, jq)
---

# [Memo] メモを作成

> **保存ベース（store-first）**: この skill 内の `.ai-context/...` パスはすべて ai-context ベース — SessionStart で「ai-context ベース: &lt;絶対パス&gt;」として注入される絶対パス — を指す。相対 `.ai-context/` には絶対に書かない（不明なときは `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決）。

**パターン**: B（穴埋めテンプレート）— 共通スケルトンは `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` を参照
**ファイル名プレフィックス**: `[Memo]`

メモの*本文*はユーザーの会話言語で書く（ユーザーが日本語で会話していれば日本語）。セクション見出しは下のテンプレート通り（例: `## Content`, `## Topics discussed`）に厳密に保つ — これらは固定の構造マーカーであり、翻訳しない。

## Step 1: モードを判定

### Mode 1: 引数なし（会話の要約）

現在の会話を要約してメモにする。抽出する項目:
- 議論したトピック
- 下した決定
- 未解決の論点
- 主要な発見 / 知見

保存先: `.ai-context/docs/[Memo] session-summary-{YYYY-MM-DD}.md`

### Mode 2: 引数あり（指定内容をメモ化）

`$ARGUMENTS` の内容をメモとして記録する。
保存先: `.ai-context/docs/[Memo] {slugified argument}-{YYYY-MM-DD}.md`

## Step 2: skill 固有テンプレート（穴を埋めてから Write）

### Mode 1 用

```markdown
# [Memo] Session Summary

- **Date**: {today's date}
- **Author**: AI

## Topics discussed
- {topic 1}
- {topic 2}

## Decisions made
-

## Open issues
-

## Key findings / insights
-
```

### Mode 2 用

```markdown
# [Memo] {title from the argument}

- **Date**: {today's date}
- **Author**: AI

## Content

{structured write-up of $ARGUMENTS}
```

## Step 3/4: 保存 + 報告

共通パターン（`_common-pattern.md` §2 パターン B / §3 命名規則 / §4 報告フォーマット / **§1.6 文体規約**）に従う。日本語のメモ本文は `~/.claude/rules/writing-ja.md` に従う（体言止め / 文末の だ・である・です・ます 不使用 / カタカナ英語を減らす / 英数字前後に半角スペース / 数字を丸めない）。
Mode 1 では**要約をテキストで提示してから保存**する（事後開示 — .ai-context への保存は safety.md の「自由に実行してよい」非破壊操作。ユーザーは後から修正を依頼できる）。

