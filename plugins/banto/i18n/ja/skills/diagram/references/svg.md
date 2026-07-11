# 手描き SVG 図解の作法

既存 html-doc skill の diagrams.md は mermaid / draw.io 経由でレンダリングした SVG の埋め込みを扱う。本ガイドはそれでは表現しづらいレイアウト（自由配置の吹き出し・強調枠・独自アイコン配置）を SVG コードで直接書く場合に特化する。

## いつ手描き SVG を選ぶか

mermaid のノード配置アルゴリズムでは崩れる図（対角に配置した強調ボックス、円環状のプロセス、地図の上に注釈を重ねる図）だけを対象にする。フローチャート・シーケンス図・ガントチャートは mermaid が勝るため、本ガイドの対象外。迷ったら mermaid を先に試し、レイアウトが崩れたときだけ手描きに切り替える。

## viewBox 設計

座標系は `viewBox="0 0 W H"` で固定し、`width` / `height` 属性は付けない（CSS 側で `max-width:100%; height:auto` を当てて可変にする）。単位は px 相当の整数のみを使い、小数点座標（`123.456`）を書かない。

```xml
<svg viewBox="0 0 800 420" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="申請フローの概要図">
  ...
</svg>
```

余白は外周 24px、要素間 32〜48px を基準にする。詰め込みすぎた図はノード数を削るか 2 枚に分割する。

## レイアウトグリッド

座標は 8px 刻みのグリッドに揃える（html-doc の design-system.md と同じスペーシング尺度: 8 / 16 / 24 / 32 / 48）。箱の高さは 48px か 64px に統一し、幅だけを内容に応じて変える。グリッドを外れた座標が 1 つでもあると、要素の間隔がバラついて見える。

```xml
<rect x="24" y="24" width="200" height="64" rx="12" />
<rect x="272" y="24" width="200" height="64" rx="12" />   <!-- 24+200+48 = 272 -->
```

## テキストの折返し対策

SVG の `<text>` は自動改行しない。短いラベル（10 文字前後まで）は `tspan` で手動改行する。

```xml
<text x="124" y="50" text-anchor="middle" font-size="14">
  <tspan x="124" dy="-4">申請内容の</tspan>
  <tspan x="124" dy="18">一次確認</tspan>
</text>
```

説明文のように長い文字列は `foreignObject` に HTML の `div` を入れ、CSS の折返しに任せる。ブラウザ表示・Chrome headless の印刷には対応するが、単純なラスタ変換ツールでは `foreignObject` が無視される場合があるため、資料の最終出力先がブラウザ表示か PDF（headless Chrome 経由）であることを確認してから使う。

```xml
<foreignObject x="24" y="120" width="200" height="80">
  <div xmlns="http://www.w3.org/1999/xhtml" style="font:14px 'Hiragino Sans', sans-serif; line-height:1.6;">
    承認者が内容を確認し、差戻しの要否を判断する。
  </div>
</foreignObject>
```

## 配色（ライトモード基調・アクセント 1 色）

html-doc の color-themes.md にある選択テーマのトークンをそのまま転記する。新しい色を発明しない。下は `claude` テーマ（テラコッタ）の例。

```xml
<rect fill="#e8ddd3" stroke="#d9c4b0" stroke-width="1" />  <!-- wash / hairline -->
<rect fill="#D97757" />                                     <!-- accent（強調要素のみ） -->
<text fill="#1F1E1D" />                                      <!-- ink（本文文字） -->
```

面の塗りは wash 1 色に統一し、accent は強調したい 1 要素だけに使う。ステータス表現が要る場合のみ html-doc の `--ok` / `--warn` / `--bad` を流用する。

## 矢印マーカー定義

矢印は `<defs>` 内で 1 種類だけ定義し、全ての矢印で使い回す。線ごとに矢頭の形やサイズを変えない。

```xml
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M0,0 L10,5 L0,10 z" fill="#4a5568" />
  </marker>
</defs>
<line x1="224" y1="56" x2="272" y2="56" stroke="#4a5568" stroke-width="1.5" marker-end="url(#arrow)" />
```

## 良い例・悪い例

良い例は、8px グリッドに整列した箱・1 種類の矢印マーカー・ラベルが箱の中に収まる図。悪い例は、次の 3 つのいずれかを含む図であり、レビュー前に必ず潰す。

- 要素の重なり: 矢印がテキストラベルを貫通している、箱同士が数 px 重なっている
- 極小フォント: `font-size` が 11px 未満（印刷時にさらに縮み判読不能になる）
- 埋め込みラスタ: `<image>` タグで PNG / JPG をベース 64 埋め込みしている（ファイルが肥大化し、拡大でぼやける。アイコンは `<path>` のベクタで描く）

## セルフチェック

- viewBox の余白・グリッドが 8px 単位で揃っているか
- ラベルが箱からはみ出していない、または `foreignObject` で折返し済みか
- 矢印マーカーが 1 種類に統一されているか
- 配色が html-doc の選択テーマ 1 色 + wash + ink のみで、新色を発明していないか
- 埋め込みラスタ（PNG/JPG の base64）がゼロか
- `font-size` が 11px 以上か（印刷時の縮小を見込んで 12px 以上を推奨）
