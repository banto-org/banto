---
name: ja-writing
description: |
  日本語の資料・報告書・Excel・受け手に合わせた文章を書くときの実務パターン集。`writing-ja` ルールの型を、文書種別・受け手レベル別に具体例で運用する。
  トリガー：「報告書書いて」「日本語の資料」「Excel に書いて」「PR 説明」「commit メッセージ」「相手に合わせて書き分けて」「経営層向けに」「非技術の人にもわかるように」。
  使わない場面：HTML 資料そのものの生成（html-doc skill）。ルールの正本参照（`~/.claude/rules/writing-ja.md` を直接 Read）。単純な会話応答の文体調整（writing-ja ルールの範囲内で足りる）。
allowed-tools: Read
user-invocable: true
compatibility: Claude Code
---

# ja-writing — 日本語ライティング実務パターン

`writing-ja` ルール（構成 / 文 / 文末 / 表記の原則）を土台に、**文書種別と受け手レベルごとの
具体的な書き分け**を持つ。ルールが「何を守るか」、本 skill は「どう書き分けるか」を担う。

## いつ使うか

日本語で報告書・提案書・手順書・Excel セル・チャット応答・PR 説明・commit メッセージのいずれかを
書く前、または受け手（経営層 / PM / エンジニアなど）に応じて書き分けが必要なとき。

## references の選び方

- 受け手レベル（L1 非技術 / L2 半技術 / L3 技術）で書き分けたい → `references/audience-levels.md`
- 報告書・提案書・手順書などの文書型資料を書く → `references/patterns-documents.md`
- Excel のセルに日本語を書く（ラベル / 値 / 注記） → `references/patterns-excel.md`
- チャット応答・PR 説明・commit メッセージを書く → `references/patterns-chat-pr.md`

該当する reference を Read してから書く。複数の観点が絡む場合（例: 経営層向けの提案書）は
audience-levels.md と patterns-documents.md の両方を Read する。

## 共通原則

- 結論を最初の 1 文に置き、根拠・経緯は後に置く。
- 数字は実数で書き、丸めない。
- 文末に だ・である・です・ます を使わない（体言止め / 終止形）。
- 経緯メタ情報（「（最新）」「新規追加」「従来は〜」）を成果物に書かない。経緯は git log と
  decisions が持つ。
- 受け手レベルを文書全体で固定し、混ぜない。
