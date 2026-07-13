# PowerPoint 生成の実務

既存 html-doc skill はブラウザ表示・印刷 PDF 前提の単一 HTML 資料を扱い、PowerPoint 形式は対象外。本ガイドは python-pptx による .pptx 生成に特化し、HTML との使い分け判断も本ガイドが担う。

## HTML 資料（html-doc skill）との使い分け

相手が資料をそのまま編集する前提（営業担当がスライドを差し替える、社内テンプレートに合わせる）なら PPTX を選ぶ。ブラウザ表示・印刷 PDF が主目的で、読了プログレスバーや折りたたみ付録のようなインタラクティブ層を活かしたいなら html-doc skill の HTML を選ぶ。対面プレゼンで投影する資料は PPTX、後で読み返す報告書は HTML、が判断の基本線。両方が要る場合は内容を先に HTML かテキストで固め、確定した骨子を PPTX に流し込む順で作業する。

## テンプレート .potx の活用

クライアントのブランドテンプレート（`.potx`）がある場合は、それを起点にする。ゼロから作った資料はレイアウトが一貫せず、社内資料に混ぜたときに浮く。テンプレートがない場合のみ新規プレゼンテーションから作る。

```python
from pptx import Presentation

prs = Presentation("company_template.potx")   # テンプレートがある場合
# prs = Presentation()                         # ない場合は空のプレゼンテーションから開始

# レイアウト名と index はテンプレートごとに異なるため、使う前に必ず列挙する
for i, layout in enumerate(prs.slide_layouts):
    print(i, layout.name)
```

## マスター / レイアウト指定

スライドはテンプレートの `slide_layouts` から選んで追加する。レイアウトの中身（タイトル・本文プレースホルダの有無）はテンプレート依存のため、上記の列挙結果を見てから index を選ぶ。

```python
slide_layout = prs.slide_layouts[1]     # 例: 「タイトルとコンテンツ」レイアウト
slide = prs.slides.add_slide(slide_layout)
slide.shapes.title.text = "在庫確認の待ち時間を 5 分 → 30 秒に短縮する"
```

## 日本語フォント指定（Noto Sans JP / 游ゴシック）

`run.font.name` は欧文書体（`a:latin`）だけを設定し、日本語の字形を決める東アジア書体（`a:ea`）は別属性のため、そのままでは日本語がテンプレート既定のフォントのまま変わらない。東アジア書体は XML を直接操作して設定する必要があり、その関数は後述の生成スクリプト雛形の `set_ja_font` にまとめた。游ゴシックを使う場合は関数の `name` 引数を `"游ゴシック"` に差し替える。社外配布資料で受け手の環境にフォントがない懸念がある場合は Noto Sans JP（Google 提供・多くの環境に入っている）を優先する。

## 16:9 指定

テンプレートを使わない場合、既定のスライドサイズが 4:3 になっていることがあるため、明示的に 16:9（13.333 インチ × 7.5 インチ）を指定する。

```python
from pptx.util import Emu
prs.slide_width = Emu(12192000)   # 13.333in
prs.slide_height = Emu(6858000)   # 7.5in
```

テンプレートから開始した場合は、テンプレート側のサイズを尊重し、上書きしない。

## 図の貼り込み

html-doc / diagram-svg / diagram-mermaid の各ガイドで作った図は PNG に変換してから貼り込む（PowerPoint は SVG のネイティブ編集に対応しない環境が多いため、埋め込みは PNG が安全）。

```python
from pptx.util import Inches
slide.shapes.add_picture("flow-approval.png", Inches(1.0), Inches(1.8), width=Inches(6.5))
```

図の解像度は貼り込み後の表示幅に対して 150dpi 相当以上を確保する。低解像度の PNG をスライド幅いっぱいに拡大すると、投影時にぼやける。

## 生成スクリプトの雛形

```python
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.oxml.ns import qn

def set_ja_font(run, name="Noto Sans JP", size_pt=None):
    run.font.name = name
    rPr = run._r.get_or_add_rPr()
    ea = rPr.find(qn("a:ea"))
    if ea is None:
        ea = rPr.makeelement(qn("a:ea"), {})
        rPr.append(ea)
    ea.set("typeface", name)
    if size_pt:
        run.font.size = Pt(size_pt)

def build_deck(template_path, output_path, slides_data):
    prs = Presentation(template_path) if template_path else Presentation()
    if not template_path:
        prs.slide_width, prs.slide_height = Emu(12192000), Emu(6858000)

    for item in slides_data:
        layout = prs.slide_layouts[item["layout_index"]]
        slide = prs.slides.add_slide(layout)
        slide.shapes.title.text = item["title"]
        for run in slide.shapes.title.text_frame.paragraphs[0].runs:
            set_ja_font(run, size_pt=28)

        if item.get("body"):
            body = slide.placeholders[1].text_frame
            body.text = item["body"][0]
            for line in item["body"][1:]:
                p = body.add_paragraph()
                p.text = line
            for para in body.paragraphs:
                for run in para.runs:
                    set_ja_font(run, size_pt=16)

        if item.get("image"):
            slide.shapes.add_picture(item["image"], Inches(1.0), Inches(2.0), width=Inches(6.5))

    prs.save(output_path)

if __name__ == "__main__":
    slides = [
        {"layout_index": 1, "title": "在庫確認の待ち時間を 5 分 → 30 秒に短縮する", "body": ["現状: 1 件あたり 5 分", "導入後: 30 秒"]},
    ]
    build_deck("company_template.potx", "proposal.pptx", slides)
```

## セルフチェック

- テンプレート `.potx` がある案件で、それを使わずゼロから組んでいないか
- `slide_layouts` を事前に列挙し、index を当てずっぽうで指定していないか
- 日本語テキストの `a:ea` を設定し、テンプレート既定フォントのまま放置していないか
- 貼り込む画像が SVG のままでなく PNG に変換済みか、解像度が十分か
- 16:9 指定がテンプレート由来か明示指定かのどちらかで確定しているか（4:3 のまま出していないか）
- 生成後にファイルを開いて崩れを確認したか（`open proposal.pptx`）
