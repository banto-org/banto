# Diagrams — mermaid / draw.io paths

Diagrams aren't "decoration" — add one only when it communicates faster than prose. The first choice is mermaid (text-managed, regenerable); reach for draw.io only when free-form placement is required.

## When to use which

| What you want to draw | Route | mermaid syntax |
|---|---|---|
| Process flow / decision | mermaid | `flowchart LR` (horizontal by default; use TD only for deep branching) |
| Interaction / API calls | mermaid | `sequenceDiagram` |
| Schedule | mermaid | `gantt` |
| Data model | mermaid | `erDiagram` |
| State transition | mermaid | `stateDiagram-v2` |
| System architecture (hierarchical) | mermaid | `flowchart` + `subgraph` |
| Free-form architecture / network diagrams / revising an existing drawio asset | **draw.io** | — |
| Pie charts / mindmaps | **Don't build these** (a table or list works better) | — |

## Mermaid route (first choice)

### 1. Write the .mmd — always add the shared theme header

Match it to the document's **selected theme**. Add this at the top of each .mmd (the example below is the docs skill's default theme; copy `primaryColor` = accent-soft, `primaryBorderColor` = line, `primaryTextColor` = ink, and `lineColor` = ink-soft from the docs skill's theme-default.md — or theme-custom.md when present):

```
%%{init: {'theme':'neutral','themeVariables':{
  'fontFamily':'Hiragino Sans, Noto Sans JP, sans-serif',
  'primaryColor':'#E8EDF5','primaryBorderColor':'#DDE1E6',
  'primaryTextColor':'#000000','lineColor':'#404040'
}}}%%
```

For English-language documents, label the diagram in English too, and set `fontFamily` to `'Segoe UI, Helvetica Neue, sans-serif'`.

- Match node labels to the audience level (L1: plain nouns only / L3: component names as-is)
- For L1, **write the conclusion directly into the diagram** (annotations like `-->|this is the bottleneck|`)
- Node-count guideline per diagram: L1 = 5 or fewer / L2 = 10 / L3 = no limit (but consider splitting into two)

### 2. Render to SVG

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/render-diagram.sh" flow.mmd   # → flow.svg
```

- Tries `mmdc` directly → falls back automatically to `npx -y @mermaid-js/mermaid-cli` if unavailable
- **The first npx run takes a few minutes** downloading Chromium for puppeteer (cached after that). Wait it out even if it's slow
- Background is already set to transparent (blends into a tinted-background box)

### 3. Inline embedding

Paste the SVG file's contents (`<svg …>…</svg>`) straight into the document's figure slot (docs skill's template.html family):

```html
<figure>
  <svg …>…</svg>
  <figcaption>Overall process flow</figcaption>
</figure>
```

- The template (docs skill's template.html) already implements `svg { max-width: 100%; height: auto; }`
- The script automatically handles id collisions (it attaches a `--svgId` derived from the output filename). Just make sure **not to reuse the same output filename**
- Keep the `.mmd` source alongside the document (so it can be regenerated/revised later)

### CDN runtime fallback (last resort)

Only when rendering isn't possible (no npx, etc.). Always tell the user explicitly that **this makes an external request, and the diagram won't render offline or in print**:

```html
<pre class="mermaid">
flowchart LR
  A[Input] --> B[Processing] --> C[Output]
</pre>
<script type="module">
  import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
  mermaid.initialize({ startOnLoad: true, theme: "neutral" });
</script>
```

## draw.io route

For diagrams that need free-form placement (layered architecture, network diagrams, physical layout), or when the client wants to edit it themselves.

### 1. Write the .drawio XML

Minimal skeleton (generate this with Write, then add shapes as `mxCell`):

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Architecture" id="d1">
    <mxGraphModel dx="800" dy="600" grid="1" gridSize="10" page="1" pageWidth="827" pageHeight="1169">
      <root>
        <mxCell id="0"/><mxCell id="1" parent="0"/>
        <mxCell id="n1" value="Web Server" style="rounded=1;whiteSpace=wrap;fillColor=#E8EDF5;strokeColor=#DDE1E6;" vertex="1" parent="1">
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

Match colors to the selected theme's tokens (fill = accent-soft / stroke = line / lines = ink-soft / accent only for emphasis — see the docs skill's theme-default.md; the example above is the default theme).

### 2. Convert to SVG (if a CLI is available)

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/render-diagram.sh" arch.drawio   # → arch.svg → inline embed
```

In environments without the draw.io CLI / desktop app installed (this Mac currently doesn't have it):

1. **Ship the .drawio alongside the document** and note that "this can be opened at app.diagrams.net" (this alone delivers the value of client-editability)
2. If SVG is required, suggest `brew install --cask drawio` (with the user's confirmation)
3. Avoid embedding via viewer.diagrams.net as a rule, since it makes an external request

## Diagram self-check

- [ ] Does this diagram communicate faster than prose or a table? (If not, remove it)
- [ ] Do the node count and terminology match the audience level?
- [ ] Does the theme header match the document's tone? (Don't ship mermaid's default purple)
- [ ] Did you keep the `.mmd` / `.drawio` source alongside the document?
- [ ] Does the diagram get cut off in print preview?
