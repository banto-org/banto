---
name: b2b-docs
description: |
  提案書・営業資料・パワポ・pptx・B2B 資料の構成と作成手段を扱う。章立て（結論 → 課題 → 効果 → 根拠 → 費用 → 手順 → リスク）と、HTML / PowerPoint のどちらで作るかの判断に特化する。
  トリガー：「提案書作って」「営業資料」「パワポで」「pptx で」「B2B の資料」「導入提案」「顧客向け資料」。
  使わない場面：ブラウザ表示・印刷 PDF 前提の単一 HTML 資料そのものの生成（html-doc skill）。受け手レベル別の文体調整（ja-writing skill の audience-levels.md）。
allowed-tools: Read
user-invocable: true
compatibility: Claude Code (pptx 生成には python-pptx が必要)
---

# b2b-docs — B2B 提案・営業資料の構成と作成手段

html-doc skill はブラウザ表示・印刷 PDF 前提の単一 HTML 資料を扱う。本 skill は B2B の提案・営業
資料に特有の**章立てそのもの**と、PowerPoint 形式が要る場合の作成手段に特化する。

## いつ使うか

顧客・見込み客向けの提案書や営業資料を作るとき、または HTML と PowerPoint のどちらの形式で
作るか判断したいとき。

## references の選び方

- 資料全体の章立て（表紙 1 メッセージ → 課題 → 効果 → 根拠 → 費用 → 導入手順 → リスク）を
  組み立てる → `references/structure.md`
- PowerPoint（.pptx）形式で作る、または HTML との使い分けを判断する → `references/pptx.md`

受け手レベル別の文体調整は ja-writing skill の `skills/ja-writing/references/audience-levels.md` を直接参照する
（本 skill では再掲しない）。

## 共通原則

- 表紙には製品名でなく相手が得る結果を 1 文で書く。
- 効果は必ず before → after の実数の対で示し、出典を根拠の章に明示する。
- 1 枚（1 セクション）には主張を 1 つだけ置く。
- 自社語り・機能の網羅列挙・数字なし効果表現を避ける。
