# Color Themes — 7テーマ（ライトモード限定・WCAG AA準拠）

全雛形に7テーマを同梱済み。`<html data-theme="...">` を書き換えるだけで切替わる。
既定は `claude`（アイボリー地 + 白カード + テラコッタのアクセント）。コントラスト比は本文色 対 白カード／淡面で WCAG AA を満たすよう設計。

## 切替方法

```html
<html lang="ja" data-theme="claude">     <!-- ここを変えるだけ -->
```

## 変数モデル（v2）

各テーマは以下のCSS変数で構成される（雛形の `:root, html[data-theme="..."]` ブロックに定義済み）:

| 変数 | 役割 |
|---|---|
| `--bg` | ページ地（オフホワイト〜淡い色味） |
| `--surface` | カード/表/付録の面色（基本は純白 `#fff`） |
| `--wash` | 淡面（callout 地・表ヘッダ・コードinline・バー地） |
| `--ink` / `--sub` | 本文 / 補足文字 |
| `--accent` / `--accent-deep` | アクセント / 濃アクセント（リンク・見出し番号・強調） |
| `--accent-soft` | アクセントの極淡面（バッジ・STEPピル・選択範囲） |
| `--hairline` | 罫線・カード境界 |
| `--shadow` | カードの影（印刷時は消える） |
| `--serif` | 見出し用セリフフォントスタック |

ステータス色は全テーマ共通（テーマ非依存・バッジ/callout のみ）:
`--ok #1A7F4B` / `--ok-bg #E5F3EB` ・ `--warn #955F00` / `--warn-bg #FAF0D9` ・ `--bad #B3261E` / `--bad-bg #F9E8E7`。

## テーマ一覧

| theme | accent | accent-deep | bg | surface | 向く資料 |
|---|---|---|---|---|---|
| `claude` テラコッタ（**既定**） | `#D97757` | `#AE5630` | `#F0EEE6` | `#FFFFFF` | 汎用・温かみ・社内/社外問わず |
| `navy` 紺 | `#2D5986` | `#1A3A5C` | `#F2F4F7` | `#FFFFFF` | 報告書・金融・コンサル |
| `forest` 深緑 | `#2D7A4A` | `#1A4D2E` | `#F1F5F1` | `#FFFFFF` | 環境・医療・サステナ報告 |
| `burgundy` えんじ | `#9B2D45` | `#6B1A2E` | `#F6F1F1` | `#FFFFFF` | 伝統産業・文化・法律 |
| `sumi` 墨 | `#444` | `#2B2B2B` | `#F4F4F2` | `#FFFFFF` | 仕様書・学術・ミニマル年報 |
| `copper` 銅 | `#A85230` | `#7A3B1E` | `#F7F3EE` | `#FFFFFF` | クリエイティブ・建築・工芸 |
| `slate` スレート | `#4A6278` | `#2C3E50` | `#F2F4F6` | `#FFFFFF` | IT・SaaS・技術提案 |

## 選び方

1. ユーザー指定があればそれ
2. クライアントのブランド色がある → カスタム（下記）
3. 指定なし → 資料の性格で上表から選び、採用解釈として開示（**迷ったら既定 `claude`**）

## カスタムテーマ（クライアントブランド色）

ブランド色1色から導出する。雛形の `:root` ブロックに `html[data-theme="custom"]` を追記して `data-theme="custom"` を指定:

```css
html[data-theme="custom"] {
  --bg:#…;          /* accent をごく僅かに含むオフホワイト（明度97%前後） */
  --surface:#fff;   /* 基本は純白のまま */
  --wash:#…;        /* accent を白で約90%希釈（淡面） */
  --ink:#1F1E1D; --sub:#63605A;   /* 本文系は据え置きでよい */
  --accent:#…;      /* ブランド色。白地コントラスト 3:1 以上（面・図形用） */
  --accent-deep:#…; /* 同系を暗く。白地 4.5:1 以上（文字・リンク用） */
  --accent-soft:#…; /* accent を白で約85%希釈（バッジ地） */
  --hairline:#…;    /* accent を白で約78%希釈（罫線） */
  --shadow:0 1px 2px rgba(0,0,0,.05), 0 4px 16px rgba(0,0,0,.07);
  --serif:Georgia,"Hiragino Mincho ProN",serif;
}
```

検証: 本文 `--ink` 対 `--surface`／`--bg`、`--accent-deep` 対 白地が WCAG AA (4.5:1) を満たすこと。

## 禁止

- アクセント2色目の追加（ステータス3色は例外）
- システムブルー（`#007bff` / `#0d6efd` 系）— Bootstrap/AIテンプレ感の象徴
- ダークモード対応（このスキルはライトモード限定）
- mermaid 図のデフォルト紫のまま埋め込み（diagrams.md のテーマヘッダで wash/hairline に揃える）
