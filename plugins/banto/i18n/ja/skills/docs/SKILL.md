---
name: docs
description: 日本語の説明資料を「引っ掛かりゼロ」標準で作る統合skill。HTML（ツールチップ・目次・MD出力つきの最リッチ版）／Excel（xlsx）／スライド（pptx）／Word（docx）／表、の形式を資料の目的に応じて切り替え、文章の基本形は全形式で一貫させる。カラー・デザインは差し替え可能なテーマファイルで管理。ユーザーが「資料を作って」「〜をまとめて」「レポート」「説明資料」「提案書」「報告書」「スライドで」「Excelで」「Wordで」と言ったら、形式の明示がなくても必ずこのskillを使い、形式選択表で最適な形式を決める。図の生成には diagram skill（banto）を併用する。
user-invocable: true
compatibility: Claude Code (requires bash, python3)
---

# docs ― 日本語資料の統合作成skill

どの形式（HTML/xlsx/pptx/docx）で作っても、文章の基本形と「引っ掛かりゼロ」の品質は同じ。
形式ごとの器の作り方だけを切り替える。

**実行環境の前提**: bashとpython3が使えるClaude系環境を想定。形式別の外部ツール（rsvg-convert、libreoffice等）は各formatリファレンスに可用性チェックの分岐がある。

## 手順（この順番を守る）

1. **読者・目的・形式を決める** — 下の形式選択表で決める。ユーザー指定があればそれに従う。**読者が未指定なら「最も専門知識のない一般読者」を既定とする**
2. **`references/shared-rules.md` を読む** — 引用・用語スイープ・テーマ・図・検証の横断ルール。全形式で必須
3. **`references/writing-core.md` を読む** — 全形式共通の文章基本形（認知=読みやすさ / 説得=訴求力 / 場面=文書種別の 3 層。語彙の言い換えは `references/wording-swaps.md`）
4. **形式別リファレンスを読む** — `references/format-html.md` / `references/format-xlsx.md` / `references/format-pptx.md` / `references/format-docx.md` のうち該当するもの。表を使うなら `references/format-tables.md` も
5. **執筆・作図・検証する** — shared-rules.md の手順に従う。`scripts/` のチェッカー
   （term-sweep=用語 / style-sweep=表現 / verify-html=HTML）を必ず実行する
6. **保存する** — 保存先・命名は ai-context の `docs/` 正典（`skills/ai-context/references/directory-structure.md`）に従い、自己流の命名をしない。`{base}/docs/[Prefix] {YYYY-MM-DD}_{slug}[_{variant}].ext`:
   - **プレフィックスは意図で選ぶ**: 解説・手順・概説 → `[Guide]` / 提案・計画・設計 → `[Design]` / 進捗・報告 → `[Status]` / 監査・分析 → `[Audit]`
   - **日付は先頭・`_` 区切り**。日時は `date +%Y-%m-%d` を実行して得た値を使う（記憶で書かない）。`_variant` はモデル比較等の任意接尾辞（例 `_fable`）
   - **slug の言語**: 既定は英語。**配布用オフィス文書（docx / xlsx / pptx）のみ日本語 slug** にして本文と平仄を揃える。HTML・md は英語 slug（URL 可搬性・構造物のため）

## 形式選択表

| 読者がすること | 形式 | 理由 |
|---|---|---|
| じっくり読んで理解する（社内共有・解説・調査報告） | **HTML** | 情報量が最大。ツールチップ・目次・MD出力を全部載せられる |
| 数値を確認・再利用・並べ替える | **xlsx** | 表計算そのものが目的のとき。読む資料をExcelで作らない |
| 会議で投影して聞く／めくって読む／相手がスライドを編集・差し替える | **pptx** | 投影用と配布用で設計が違う。format-pptx.mdで分岐。相手が自社テンプレートに合わせて編集する前提ならpptx |
| 印刷・回覧・押印・正式文書として保存 | **docx** | 稟議・報告書・契約系。長文の通読に最適 |
| 3件以上の項目×2属性以上の比較 | **表**（各形式内） | 文章で数値を並べない。format-tables.mdに従う |

迷ったらHTML。ユーザーの環境で最も情報を落とさず読めるため。
HTMLとpptxの両方が要る場合は、骨子を先にHTMLかテキストで確定してからpptxへ流し込む。

場面（提案書/報告書/依頼/お詫び/リリースノート）ごとの構成・文体・禁止事項は writing-core.md
第 3 層の定石表に従う（例: 報告・依頼は結論前置、提案書だけ結論後置）。
