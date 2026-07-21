# Diagrams — mermaid / draw.io 経路

図は「飾り」ではなく「文章より速く伝わる時だけ」入れる。第一選択は mermaid（テキスト管理・再生成可能）、自由配置が必要な時だけ draw.io。

## 使い分け

| 描きたいもの | 経路 | mermaid記法 |
|---|---|---|
| 処理フロー・意思決定 | mermaid | `flowchart LR`（横が基本。深い分岐のみTD） |
| やり取り・API呼び出し | mermaid | `sequenceDiagram` |
| スケジュール | mermaid | `gantt` |
| データモデル | mermaid | `erDiagram` |
| 状態遷移 | mermaid | `stateDiagram-v2` |
| システム構成（階層的） | mermaid | `flowchart` + `subgraph` |
| 自由配置の構成図・NW図・既存drawio資産の改訂 | **draw.io** | — |
| 円グラフ・mindmap | **作らない**（表か箇条書きが勝る） | — |

## mermaid 経路（第一選択）

### 1. .mmd を書く — 必ず共通テーマヘッダを付ける

資料の**選択テーマと揃える**。各 .mmd の先頭に（下例は docs skill の既定テーマ。`primaryColor`=accent-soft、`primaryBorderColor`=line、`primaryTextColor`=ink、`lineColor`=ink-soft を docs skill の theme-default.md — theme-custom.md があればそちら — から転記）:

```
%%{init: {'theme':'neutral','themeVariables':{
  'fontFamily':'Hiragino Sans, Noto Sans JP, sans-serif',
  'primaryColor':'#E8EDF5','primaryBorderColor':'#DDE1E6',
  'primaryTextColor':'#000000','lineColor':'#404040'
}}}%%
```

英語資料の図はラベルも英語にし、`fontFamily` を `'Segoe UI, Helvetica Neue, sans-serif'` に。

- ノードのラベルは相手レベルに合わせる（L1: 平易な名詞のみ / L3: コンポーネント名そのまま）
- L1向けは**図に注釈を書き込む**（`-->|ここがボトルネック|` 等）
- 1図のノード数目安: L1=5個以下 / L2=10個 / L3=制限なし（ただし2分割を検討）

### 2. SVG にレンダする

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/render-diagram.sh" flow.mmd   # → flow.svg
```

- `mmdc` 直 → なければ `npx -y @mermaid-js/mermaid-cli` に自動フォールバック
- **初回の npx 実行は puppeteer の Chromium DL で数分かかる**（2回目以降はキャッシュ）。時間がかかっても待つ
- 背景は transparent 指定済み（wash背景のbox内でも馴染む）

### 3. インライン埋め込み

SVGファイルの中身（`<svg …>…</svg>`）を資料（docs skill の template.html 系）の figure スロットへそのまま貼る:

```html
<figure>
  <svg …>…</svg>
  <figcaption>処理フロー全体像</figcaption>
</figure>
```

- 雛形（docs skill の template.html）側に `svg { max-width: 100%; height: auto; }` 実装済み
- id 衝突対策はスクリプトが自動処理（出力ファイル名由来の `--svgId` を付与）。**同名の出力ファイルを使い回さない**ことだけ守る
- `.mmd` ソースは資料と同じ場所に併納する（後から再生成・改訂できるように）

### CDNランタイム・フォールバック（最終手段）

レンダ不能（npx もない等）時のみ。**外部リクエストが発生し、オフライン・印刷で図が出ない**ことをユーザーに必ず明示:

```html
<pre class="mermaid">
flowchart LR
  A[入力] --> B[処理] --> C[出力]
</pre>
<script type="module">
  import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
  mermaid.initialize({ startOnLoad: true, theme: "neutral" });
</script>
```

## draw.io 経路

自由配置が要る図（レイヤ構成・ネットワーク・物理配置）や、クライアントが自分で編集したい場合。

### 1. .drawio XML を書く

最小スケルトン（これをWriteで生成し、図形を `mxCell` で追加）:

```xml
<mxfile host="app.diagrams.net">
  <diagram name="構成図" id="d1">
    <mxGraphModel dx="800" dy="600" grid="1" gridSize="10" page="1" pageWidth="827" pageHeight="1169">
      <root>
        <mxCell id="0"/><mxCell id="1" parent="0"/>
        <mxCell id="n1" value="Webサーバ" style="rounded=1;whiteSpace=wrap;fillColor=#E8EDF5;strokeColor=#DDE1E6;" vertex="1" parent="1">
          <mxGeometry x="120" y="120" width="160" height="60" as="geometry"/>
        </mxCell>
        <mxCell id="n2" value="DB" style="shape=cylinder3;whiteSpace=wrap;fillColor=#E8EDF5;strokeColor=#DDE1E6;" vertex="1" parent="1">
          <mxGeometry x="400" y="110" width="100" height="80" as="geometry"/>
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=1;strokeColor=#404040;" edge="1" parent="1" source="n1" target="n2">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

色は選択テーマのトークン（fill=accent-soft / stroke=line / 線=ink-soft / 強調のみ accent — docs skill の theme-default.md 参照。上例は既定テーマ）に揃える。

### 2. SVG化（CLIがあれば）

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/render-diagram.sh" arch.drawio   # → arch.svg → インライン埋め込み
```

draw.io CLI / デスクトップアプリ未導入の環境（現状この Mac は未導入）では:

1. **.drawio を資料に併納**して「app.diagrams.net で開けます」と案内（クライアント編集可能の価値はこれだけで成立）
2. SVGが必須なら `brew install --cask drawio` を提案（ユーザー確認の上）
3. viewer.diagrams.net の埋め込みは外部リクエストが発生するため原則使わない

## 図のセルフチェック

- [ ] その図は文章・表より速く伝わるか（伝わらないなら削除）
- [ ] 相手レベルにノード数・用語が合っているか
- [ ] テーマヘッダで資料とトーンが揃っているか（mermaidデフォルト紫のまま出さない）
- [ ] `.mmd` / `.drawio` ソースを併納したか
- [ ] 印刷プレビューで図が切れていないか
