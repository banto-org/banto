---
name: html-doc
description: |
  モダンで自己完結な HTML 資料を雛形から生成する（用途別: 報告書 / 手順書 / 説明資料 / 提案書 × 日本語 / 英語 × カラーテーマ 7 種）。Claude 系ライトモード（アイボリー地 + 白カード + アクセント 1 色）が既定。HTML ならではのリッチ層（読了プログレスバー / スクロール連動 TOC / KPI 統計カード / タイムライン / CSS バーチャート / コピー付きコード / 折りたたみ付録 / ロードアニメ）を全雛形に内蔵。図は mermaid（.mmd → インライン SVG）/ draw.io（編集可能な .drawio 併納）経由。相手のレベル（L1 非技術 / L2 半技術 / L3 技術）は書き方の調整軸として全雛形に適用。ライトモード限定・標準システムフォントのみ。
  トリガー：「HTML 資料」「HTML で出して」「報告書作って」「手順書」「説明資料」「提案書」「HTML レポート」「資料にまとめて」"report" "runbook" "proposal" "explainer"。
  使わない場面：アプリ / 画面の UI 実装（ui-design skill があればそちら）、内部メモや decision 記録（Markdown で十分）、B2B 提案の章立て・pptx 判断（b2b-docs skill）。
user-invocable: true
argument-hint: "[用途（report/guide/explainer/proposal）や題材の説明（省略可）]"
allowed-tools: Read Write Edit Bash Glob
compatibility: Claude Code
---

# HTML Doc — モダン HTML 資料作成スキル

自己完結（外部リクエストゼロ）の単一 HTML ファイルとして資料を生成する。
NDA 案件の成果物でも安全（CDN フォント・外部 CSS・トラッキングなし。フォントは標準システムフォントのみ。図は事前レンダのインライン SVG）。**ライトモード限定**（印刷 / PDF 前提、ダークモードは作らない）。

## デザイン方針（Claude 系 + HTML リッチ）

通常のドキュメントより**視覚的に吸収しやすい**ことを最優先する。紙の PDF の劣化コピーにしない。

- **配色**: 既定テーマ `claude`（アイボリー地 `#F0EEE6` + 白カード `#FFFFFF` + テラコッタのアクセント `#D97757`）。落ち着いた暖色ベースで、業種により他 6 テーマへ差し替え。
- **タイポ**: 見出しはセリフ（`Iowan Old Style` / `Georgia` 系）、本文はシステムサンセリフ。見出しと本文のコントラストで階層を作る。
- **HTML ならではのリッチ層**（全雛形に内蔵・部品は削除可）:
  - 上部の**読了プログレスバー**／右レールの**スクロール連動 TOC**（現在地ハイライト）／**Back to top**
  - **KPI 統計カード**（数字を主役にする）／**タイムライン**（経緯）／**CSS バーチャート**（量の比較）
  - **コピーボタン付きコードブロック**／**折りたたみ付録 `<details>`**／カード化した表・callout
  - **ロードアニメ**（時間ベース・約 1 秒で完了。ヒーローが順にフェードイン）
- **印刷**: `@media print` で装飾層（バー / TOC / ボタン / アニメ / 影）が自動で消え、A4 縦に最適化される。
- **禁止**: `IntersectionObserver` による **scroll-reveal で本文を隠す実装は禁止**（headless スクショ / PDF / JS 無効環境で内容が消える）。アニメは必ず時間ベースで、最終状態が常に可視であること。

## ワークフロー

```
1. 要件把握   → 用途（下表）/ 言語（日本語 or 英語）/ 相手レベル(L1-L3) / テーマ を特定
               不明なら依頼文から推定し、採用解釈として開示
2. 雛形選択   → ${CLAUDE_PLUGIN_ROOT}/templates/html-doc/{report,guide,explainer,proposal}.html（日本語）
               ${CLAUDE_PLUGIN_ROOT}/templates/html-doc/en/*.html（英語）から 1 つ Read
3. テーマ選択 → <html data-theme="..."> を 7 種から設定（既定 claude。references/color-themes.md）
4. 設計確認   → references/design-system.md（数値・禁則）+ audience-levels.md（相手レベル調整）
               日本語資料は ~/.claude/rules/writing-ja.md（文末スタイル・カタカナ削減・半角スペース・数字非丸め）も適用
5. 図表作成   → 記法の選択と作法（mermaid/draw.io/手描きSVGのどれで・どう書くか）は diagram skill を先に参照
               → レンダは references/diagrams.md に従い .mmd → render-diagram.sh → SVG インライン
6. 組み立て   → {{PLACEHOLDER}} を全置換し単一 HTML で保存 → open で確認
7. セルフチェック → 下のチェックリスト
```

## 雛形（用途縛り・各 日本語 / 英語 両対応）

雛形の場所: `${CLAUDE_PLUGIN_ROOT}/templates/html-doc/`（以下、相対で表記）

| 用途 | 日本語 | 英語 | レイアウト署名 |
|---|---|---|---|
| 報告書（状況・調査・障害） | `report.html` | `en/report.html` | 左マージンラベル列 |
| 手順書（セットアップ・運用） | `guide.html` | `en/guide.html` | 大型 STEP 番号 + 確認チェックポイント |
| 説明資料（概念・仕組み・オンボーディング） | `explainer.html` | `en/explainer.html` | ゴースト章番号 |
| 提案書・企画書 | `proposal.html` | `en/proposal.html` | アクセントバー表紙 |

- 言語は**読み手の言語**で決める（依頼が日本語でも、宛先が英語圏なら en/ を使い、採用解釈を開示）
- 相手レベル（L1 非技術 / L2 半技術 / L3 技術）は雛形に縛られない**書き方の調整軸** → `references/audience-levels.md`

## カラーテーマ（全雛形共通・data-theme で切替）

`claude`（**既定**・汎用 / 温かみ）/ `navy`（報告・金融系）/ `forest`（環境・医療）/ `burgundy`（伝統・文化）/ `sumi`（仕様書・ミニマル）/ `copper`（クリエイティブ）/ `slate`（IT・SaaS）
クライアントブランド色からのカスタム導出 → `references/color-themes.md`

## 図表の経路（詳細: references/diagrams.md）

- **第一選択 mermaid**: `.mmd` を書き `sh "$CLAUDE_PLUGIN_ROOT/scripts/render-diagram.sh" x.mmd` → SVG をインライン化（オフライン・印刷 OK・id 衝突は自動回避）
- **draw.io**: 自由配置の構成図 → `.drawio` XML を資料に併納（クライアント編集可能）。CLI 導入時のみ SVG 化
- レンダ不能時のみ CDN ランタイムにフォールバック（外部リクエスト発生を必ず明示）

## 保存と確認

- 保存先: 指示があればそこへ。なければプロジェクトの `docs/`、内部報告は ai-context store の `docs/`
- `.mmd` / `.drawio` ソースは資料と同じ場所に併納（再生成・改訂可能に）
- 生成後 `open <file>` で確認。印刷前提なら印刷プレビューも

## セルフチェック（出す前に必ず）

- [ ] `{{` が残っていない（プレースホルダ置換漏れ）
- [ ] 外部リクエストゼロ: `grep -oE 'https?://[^"'"'"' >]+' file.html | grep -v w3.org` が空（SVG の `xmlns` は通信しない識別子なので除外）
- [ ] 言語が読み手と一致（日本語資料に英語ラベル混在なし・逆も）。日本語にイタリックなし（英語はイタリック可）
- [ ] **日本語の本文は `~/.claude/rules/writing-ja.md` に従う**（文末の だ・である・です・ます 不使用＝体言止め / 終止形 / カタカナ英語を減らす / 英数字前後に半角スペース / 報告で数字を丸めない）。英語出力には適用しない
- [ ] クライアント向け→内部名・他社名・PII をマスク済み（pii-protection ルール準拠）
- [ ] 相手レベルと文体が一致（L1 に専門語を出していないか）
- [ ] テーマが 1 つだけ適用され、アクセント 1 色（ステータス 3 色は例外）・絵文字ゼロ
- [ ] 図の SVG が `max-width:100%` で崩れず、印刷プレビューでページ割れしない
- [ ] **scroll-reveal で本文を隠していない**（アニメは時間ベース・最終状態が常に可視）
- [ ] **headless で実レンダ検証**（推奨）: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --screenshot=/tmp/shot.png --window-size=1440,2400 file.html` で画面を、`--print-to-pdf=/tmp/out.pdf` で印刷を確認
- [ ] TOC が h2 を正しく拾い、`id` がユニーク（リッチ層を使う場合）

## 詳細リファレンス

- `references/design-system.md` — 数値ベースの文書デザインシステム（型スケール・行長・スペーシング・印刷・禁則）
- `references/color-themes.md` — カラーテーマ 7 種（既定 claude）+ ブランド色カスタム導出
- `references/audience-levels.md` — L1/L2/L3 別の文体・構成・図の粒度
- `references/diagrams.md` — mermaid / draw.io の作図・レンダ・埋め込み手順
