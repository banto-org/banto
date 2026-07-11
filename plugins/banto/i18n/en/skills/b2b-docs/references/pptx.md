# PowerPoint generation in practice

The existing html-doc skill handles a single HTML document built for browser viewing and
print-to-PDF; PowerPoint format is out of its scope. This guide specializes in generating `.pptx`
with python-pptx, and also owns the decision of when to choose it over HTML.

## Choosing between this and the HTML document (html-doc skill)

Choose PPTX when the recipient is expected to edit the document directly — a salesperson swapping
slides, or fitting it into an internal template. Choose the html-doc skill's HTML when browser
viewing and print-to-PDF are the primary goal, and you want to use interactive layers like a
read-progress bar or collapsible appendix. The baseline rule of thumb: PPTX for a document projected
in a face-to-face presentation, HTML for a report read back later. When both are needed, lock the
content down first in HTML or plain text, then pour the finalized outline into PPTX.

## Using a .potx template

If the client has a brand template (`.potx`), start from it. A deck built from scratch has
inconsistent layout and stands out when mixed into internal materials. Build a fresh presentation
only when no template exists.

```python
from pptx import Presentation

prs = Presentation("company_template.potx")   # when a template exists
# prs = Presentation()                         # otherwise, start from a blank presentation

# Layout names and indices differ per template — always enumerate before using one
for i, layout in enumerate(prs.slide_layouts):
    print(i, layout.name)
```

## Specifying master / layout

Add slides by picking from the template's `slide_layouts`. What each layout actually contains
(whether it has title/body placeholders) is template-dependent, so choose the index only after
looking at the enumeration above.

```python
slide_layout = prs.slide_layouts[1]     # e.g. a "Title and Content" layout
slide = prs.slides.add_slide(slide_layout)
slide.shapes.title.text = "Cut inventory-check wait time from 5 minutes to 30 seconds"
```

## Specifying Japanese fonts (Noto Sans JP / Yu Gothic)

`run.font.name` only sets the Latin typeface (`a:latin`) — the East Asian typeface (`a:ea`) that
governs Japanese glyphs is a separate attribute, so Japanese text stays on the template's default
font unless it's set explicitly. Setting the East Asian typeface requires manipulating the XML
directly; that function is bundled as `set_ja_font` in the generation-script skeleton below. To use
Yu Gothic, swap the function's `name` argument to `"游ゴシック"`. For a document shared externally
where the recipient's environment might lack the font, prefer Noto Sans JP (from Google, present in
most environments).

## Specifying 16:9

When not starting from a template, the default slide size is sometimes 4:3, so specify 16:9
(13.333in × 7.5in) explicitly.

```python
from pptx.util import Emu
prs.slide_width = Emu(12192000)   # 13.333in
prs.slide_height = Emu(6858000)   # 7.5in
```

When starting from a template, respect the template's size and don't override it.

## Embedding diagrams

Convert diagrams built with the html-doc / diagram-svg / diagram-mermaid guides to PNG before
embedding (many PowerPoint environments don't support native SVG editing, so PNG is the safe format
for embedding).

```python
from pptx.util import Inches
slide.shapes.add_picture("flow-approval.png", Inches(1.0), Inches(1.8), width=Inches(6.5))
```

Ensure the diagram's resolution is at least the equivalent of 150dpi relative to its displayed
width after embedding. A low-resolution PNG stretched to fill the slide width blurs when projected.

## Generation-script skeleton

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
        {"layout_index": 1, "title": "Cut inventory-check wait time from 5 minutes to 30 seconds", "body": ["Now: 5 min per case", "After: 30 sec"]},
    ]
    build_deck("company_template.potx", "proposal.pptx", slides)
```

## Self-check

- For an engagement with a `.potx` template, did you actually use it instead of building from scratch?
- Did you enumerate `slide_layouts` first, rather than guessing at an index?
- Is `a:ea` set for Japanese text, or is it still sitting on the template's default font?
- Are embedded images converted to PNG (not left as SVG), with sufficient resolution?
- Is the 16:9 setting either inherited from the template or explicitly specified (not left at 4:3)?
- Did you open the generated file to check for layout breakage (`open proposal.pptx`)?
