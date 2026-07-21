# format-html ― HTML資料（最リッチ版）

情報量を最大化できる形式。ツールチップ・右側折りたたみ目次・Markdownダウンロードを標準装備する。
`assets/template.html` を複製し、構造とスクリプトを保って本文を差し替える。

## 標準装備（すべて必須）

| 機能 | 実装 |
|---|---|
| 読了プログレスバー | `.progress` + スクロール連動JS |
| 冒頭の凡例 | `.legend`（点線=用語説明、↗=出典、右端バー=目次、MD↓=保存、を必ず説明） |
| 用語ツールチップ | `<span class="t" tabindex="0">用語<span class="tip">説明</span></span>`。tabindex必須 |
| 出典ピル | `<a class="src" href="URL" target="_blank" rel="noopener">著者/媒体↗</a>`（外部情報のみ） |
| Notion風右側目次 | 右端バー→ホバー/クリックで展開、現在地ハイライト、モバイルは☰。JSが見出しから自動生成 |
| MDダウンロード | 全文ボタン＋各セクション右上のMD↓。DOM→MD変換器（template内蔵） |
| 巻末用語集 | `.gl`（dl/dt/dd）。ツールチップと同内容＋参照URL。見出し語に英語原語を併記（`<span class="en">working memory</span>`） |

## コンポーネント

`.keybox`(冒頭の結論) / `.note.good`・`.note.warn`(補足・注意) / `.caveat`(反証・限界の但し書き) /
`.ba`(✗/✓比較2カラム) / `.check`(チェックリスト) / `.promptbox`(コピペ用コード) / `figure`+SVG(図)

## 図

SVGをそのままインラインで埋め込む（変換不要）。`role="img"` + `aria-label` 必須。
パターンは diagram skill。色はテーマファイルのトークンを使う。

## MD変換器の保守

新しい表示専用要素（装飾・ボタン類）を追加したら、変換器のスキップリスト（.tip/.mdbtn/.num/nav/svg/button）に加える。
変換対応: h2-h4→#見出し / .t→用語テキストのみ / .src→[名](URL) / table→パイプ表 / figure→「>【図】キャプション」 / .promptbox→コードフェンス / .note・.caveat→引用 / .gl→**用語**+定義。

## 検証

1. タグ整合・id重複: `python3 scripts/verify-html.py 生成物.html`（PASS/FAILを返す）
2. JS構文: `node --check /tmp/_verify_extracted.js`（nodeが無ければJSを目視レビューし、その旨を報告に明記）
3. 動作: ブラウザかjsdomで (a)目次バー→パネル開閉 (b)全文MD↓ (c)セクションMD↓ (d)ツールチップ表示。どちらも無い環境では verify-html.py の静的検査 + node --check で代替し、動作確認未実施の旨を報告に明記する
4. MD出力の質: ツールチップ本文の混入・表崩れ・リンク欠落がないか
5. 出典URLの到達性（学術系の403はbot遮断なので許容）
