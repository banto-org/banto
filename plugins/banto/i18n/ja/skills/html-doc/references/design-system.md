# Design System — HTML資料用（v2: Claude系 + リッチ層）

数値の根拠: Tufte CSS / GOV.UK / デジタル庁デザインシステム / IBM Carbon の実測調査

v1（紙の純化・カード禁止）から v2 へ転換: **通常ドキュメントより視覚的に吸収しやすいこと**を最優先し、
アイボリー地に白カードを置く Claude 系のリッチな構成にする。ただしタイポ/スペーシングの規律は維持する。

## 大原則

1. **吸収しやすさ優先** — 読み手が拾い読みで要点を掴める。KPIカード・タイムライン・バーチャート・callout で要点を視覚化する
2. **地と面の二層** — `--bg`（アイボリー地）の上に `--surface`（白カード）を置く。カードは情報の単位（表・summary・stat・付録）。**意味なく全部をカード化しない**（本文段落は地の上に直接置く）
3. **純白地×純黒文字を避ける** — 地はテーマのオフホワイト、本文は `--ink`（純黒でない濃墨）
4. **ライトモード限定** — 印刷/PDF前提。ダークモードは作らない
5. **自己完結** — 外部リクエストゼロ（CDNフォント禁止・図は事前レンダSVG・JSはインライン）
6. **HTMLならではのリッチ層を使う** — 読了プログレス / スクロール連動TOC / コピー付きコード / 折りたたみ付録 / ロードアニメ。ただし **scroll-reveal で本文を隠さない**（最終状態は常に可視・時間ベースのアニメのみ）
7. **レイアウト署名** — 雛形ごとの署名（下記）を必ず使う。「max-width+auto margin だけ」が generic の主因

## タイポグラフィ（数値固定）

**フォントは標準システムフォントのみ**（Webフォント・CDNフォント禁止）。**見出しはセリフ**（`--serif`）、本文はサンセリフ。
このコントラストが「組まれている感」の核。

```css
/* 日本語版 */
body {
  font-family: -apple-system, "Helvetica Neue", "Segoe UI",
               "Hiragino Sans", "Yu Gothic", "Noto Sans JP", sans-serif;
  font-size: 1rem;            /* 報告書16px / 説明・提案16.5px */
  line-height: 1.8;           /* 日本語長文（カード内は1.7前後） */
  letter-spacing: 0.02em;
}
h1, h2, h3 {
  font-family: var(--serif);  /* 見出しはセリフ */
  font-weight: 600;           /* boldは使わない */
  font-feature-settings: "palt";
  text-wrap: balance; word-break: auto-phrase;
}
em, i { font-style: normal; font-weight: 600; }  /* 日本語にイタリック禁止（合成斜体） */
table, .kpi .n, .stat .value { font-variant-numeric: tabular-nums; }
```

```css
/* 英語版（templates/html-doc/en/）— 欧文は別調整 */
body {
  font-family: -apple-system, "Helvetica Neue", "Segoe UI", Roboto, Arial, sans-serif;
  line-height: 1.7;           /* 欧文は 1.6〜1.7 */
  /* letter-spacing なし */
}
/* 見出しは var(--serif)（Georgia系）。イタリック可。小ラベルは text-transform:uppercase + letter-spacing:.06em */
.sec p { max-width: 46em; }   /* 欧文の理想行長 60〜70字相当 */
```

- **型スケール**: 12 / 13 / 14 / 16 / 17 / 18 / 24 / 36 / 46px 相当（rem・clamp指定）。中間値を発明しない
- **見出しはセリフ + 大型**: h1 は `clamp(2rem, 4.5vw, 2.875rem)`。番号は `--serif` の小キャップス（`0 counter` / ゴースト数字）
- **ジャンプ率**: h1÷本文 = 2.2〜2.8倍。3倍超はマガジン的になりすぎ
- **行長**: 本文 `max-width: 40〜46em`。カード内本文は無制限可（カード幅が制約になる）

## スペーシング（8px基準スケール）

`4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 88 / 96px` のみ。**中間値（17px等）の混在が「安っぽさ」の最大要因**。
- セクション間: 80〜96px / 見出し→本文: 16〜28px / カード内: `padding: 22〜36px` / 表セル: `13px 20px`
- カードの角丸: `12〜14px`（small chip は `999px`）。角丸の値も乱立させない

## レイアウト署名（雛形ごとに1つ。これが「デザインされてる感」の正体）

全雛形は **本文カラム + 右レール（スクロール連動TOC）** の2カラムシェル（`grid-template-columns: minmax(0,1fr) 200〜216px`）。狭幅/印刷で1カラムに畳む。

| 雛形 | 署名 | 実装 |
|---|---|---|
| report | **セリフ番号セクション + KPIカード** | ヒーローに統計カード、各 h2 に `0 counter()` のセリフ番号 + ヘアライン。タイムライン/バーチャートで経緯と量を可視化 |
| guide | **大型STEPカード + 確認チェック** | 各手順を白カード化し `STEP N` ピル。末尾に localStorage 永続のチェックポイント。TOC に進捗カウント |
| explainer | **大型ゴースト数字** | `position:absolute; font-size:6.5rem; opacity:.08` の章番号を見出し背後に。用語ツールチップ・before/after カード |
| proposal | **アクセントバー表紙 + stat** | `grid-template-columns: 6px 1fr` の縦バー表紙。課題カード・効果statカード・費用テーブル |

## カード / 影

- カード = `--surface` 地 + `1px var(--hairline)` 境界 + `--shadow` + 角丸12〜14px
- `--shadow` は2段（`0 1px 2px` 近接 + `0 4px 16px` 拡散）の繊細な影。**ドロップシャドウを濃くしない**
- 強調カード: 左 `4px solid var(--accent)`（summary）/ 上 `3px solid var(--accent)`（stat・hot KPI）
- 暗色カード（next actions）は `--ink` 地 + `#F5F1E8` 文字で締めに1枚だけ

## テーブル

- **水平罫線のみ**（縦線は「エクセル貼り付け」に見える）。`.tablewrap` で白カードに内包し角丸+影
- thead: `background: var(--wash)` + 下にヘアライン。セル `padding: 13px 20px`。`th` は小キャップス
- 数値列は右寄せ + `tabular-nums`。行 hover で `--wash`。印刷で `thead { display: table-header-group }`

## 色の役割（配色はテーマで切替 → color-themes.md）

| トークン | 役割 |
|---|---|
| `--bg` / `--surface` | ページ地 / カード面 |
| `--ink` / `--sub` | 本文 / 補足 |
| `--accent` | 図形・面・バー・KPI数字・タイムラインの点 |
| `--accent-deep` | 文字側の濃アクセント。見出し番号・kicker・リンク・ラベル |
| `--accent-soft` | 極淡面。バッジ・STEPピル・選択範囲 |
| `--wash` | 淡面。表ヘッダ・callout地・バー地・inlineコード |
| `--hairline` / `--shadow` | 罫線・カード境界 / 影 |
| `--ok/--warn/--bad`(+ `-bg`) | ステータス（バッジ/callout のみ・テーマ非依存） |

## アニメーション（時間ベースのみ）

```css
@media (prefers-reduced-motion:no-preference) {
  @keyframes fadeUp { from { opacity:0; transform:translateY(12px); } to { opacity:1; transform:none; } }
  .hero > * { animation:fadeUp .5s ease backwards; }  /* delay で順次フェードイン */
}
@media print { * { animation:none !important; } }
```

**禁止**: `IntersectionObserver` で `.reveal{opacity:0}` を付け、スクロールで `.in` を足す方式。
headless スクショ・PDF・JS無効環境で**本文が空白になる**。アニメは必ず時間ベース・1秒以内に完了。

## 印刷CSS（全テンプレ必須）

```css
@media print {
  @page { size: A4 portrait; margin: 16mm 14mm 18mm 16mm; }
  html { font-size: 10.5pt; }
  body { background: #fff; }
  .toc, #progress, #top-btn, .copybtn { display: none !important; }   /* 装飾層を消す */
  .kpi, .card, .summary, .tablewrap, .next, details { box-shadow: none; }
  * { animation: none !important; }
  h2, h3 { break-after: avoid; }
  table, figure, .callout, .summary, .kpi, .card, .next { break-inside: avoid; }
  thead { display: table-header-group; }
  p { orphans: 3; widows: 3; }
  .wash-bg, thead th, .badge, .kpi, .summary { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  a { color: inherit; text-decoration: none; }
}
```

## 検証（出す前に headless で実レンダ確認・推奨）

```sh
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$C" --headless=new --disable-gpu --screenshot=/tmp/shot.png --window-size=1440,2400 file.html   # 画面
"$C" --headless=new --disable-gpu --print-to-pdf=/tmp/out.pdf file.html                           # 印刷
```

## 禁則（generic/AIっぽさの原因）

- 行長制御なし / 全見出し同一ウェイト・サンセリフ（見出しはセリフに）/ 行高一律1.5 / letter-spacing 0.05em超の日本語
- palt未設定の見出し / スペーシング・角丸値の混在 / 縦罫線テーブル / 見出しの下線・角括弧
- 純白純黒 / システムブルー（#007bff系）/ 絵文字 / 濃いドロップシャドウ / 多色グラデ
- 欧文専用font-familyで日本語をOS任せにする / 日本語イタリック
- **scroll-reveal で本文を隠す**（最終状態が不可視になる実装）
- 「で、どうしてほしいか」（next action / 判断依頼）の無い資料
