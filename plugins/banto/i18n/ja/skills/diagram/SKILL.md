---
name: diagram
description: |
  図解・シーケンス図・構成図・SVG・mermaid・draw.io で資料用の図を作るときの実務パターン集。html-doc skill のレンダ手順（テーマヘッダ・render-diagram.sh・SVG 埋め込み）を前提に、記法そのものの選び方と作法に特化する。
  トリガー：「図解して」「シーケンス図」「構成図」「AWS 構成図」「mermaid で」「draw.io で」「SVG で図を描いて」「フローチャート」。
  使わない場面：HTML 資料全体の生成・レンダ手順そのもの（html-doc skill の diagrams.md）。Figma 上での図表作成（figma-generate-diagram skill）。
allowed-tools: Read
user-invocable: true
compatibility: Claude Code
---

# diagram — 図解の記法選択と実務パターン

html-doc skill の `diagrams.md` はレンダ手順（mermaid / draw.io 経由の SVG 化・テーマ・埋め込み）を
持つ。本 skill はその手前、**どの記法を選び、どう書くか**に特化する。手順の再掲はしない。

## いつ使うか

資料に図を入れる前、どの記法（mermaid / draw.io / 手描き SVG）を選ぶか迷ったとき、または
選んだ記法で崩れずに書きたいとき。

## references の選び方

- フローチャート・シーケンス図・ガントチャートなど mermaid で描ける図 → `references/mermaid.md`
- AWS 構成図（VPC / サブネット / AZ の入れ子・アイコンセット） → `references/drawio-aws.md`
- mermaid のノード配置では崩れる自由レイアウトの図（対角配置・円環・地図注釈） → `references/svg.md`

迷ったら mermaid を先に試し、レイアウトが崩れたときだけ手描き SVG に切り替える
（`references/svg.md` の「いつ手描き SVG を選ぶか」を参照）。

## 共通原則

- レンダ手順・テーマトークンは html-doc skill の diagrams.md / color-themes.md / design-system.md
  を正本とし、ここでは再掲・新色の発明をしない。
- 8px グリッドへの整列、矢印マーカーの統一など、視覚的な整合性を崩さない。
- フローチャート・シーケンス図・ガントチャートは mermaid が勝る。手描き SVG は mermaid で表現
  できないレイアウトに限定する。
