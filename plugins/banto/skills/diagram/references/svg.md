# Hand-drawn SVG diagram conventions

The existing html-doc skill's diagrams.md covers SVG rendered and embedded via mermaid / draw.io.
This guide specializes in the case those can't express well — writing SVG code directly for
free-form layouts (floating callouts, emphasis frames, custom icon placement).

## When to choose hand-drawn SVG

Scope this to diagrams that break mermaid's node-placement algorithm: diagonally placed emphasis
boxes, circular processes, annotations layered over a map. Flowcharts, sequence diagrams, and Gantt
charts are out of scope here — mermaid wins for those. When unsure, try mermaid first and switch to
hand-drawn only once the layout breaks.

## viewBox design

Fix the coordinate system with `viewBox="0 0 W H"` and don't set `width` / `height` attributes
(apply `max-width:100%; height:auto` via CSS to make it responsive). Use integer, px-equivalent
units only — never decimal coordinates (`123.456`).

```xml
<svg viewBox="0 0 800 420" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Overview of the application flow">
  ...
</svg>
```

Baseline margins: 24px outer, 32–48px between elements. If a diagram is too dense, cut nodes or
split it into two.

## Layout grid

Align coordinates to an 8px grid (the same spacing scale as html-doc's design-system.md: 8 / 16 /
24 / 32 / 48). Standardize box height at 48px or 64px, and vary only the width by content. Even one
off-grid coordinate makes element spacing look inconsistent.

```xml
<rect x="24" y="24" width="200" height="64" rx="12" />
<rect x="272" y="24" width="200" height="64" rx="12" />   <!-- 24+200+48 = 272 -->
```

## Handling text wrap

SVG `<text>` doesn't auto-wrap. For short labels (around 10 characters), wrap manually with `tspan`.

```xml
<text x="124" y="50" text-anchor="middle" font-size="14">
  <tspan x="124" dy="-4">First-pass review</tspan>
  <tspan x="124" dy="18">of the request</tspan>
</text>
```

For prose-length strings, put an HTML `div` inside a `foreignObject` and let CSS handle the wrap.
This works for browser display and headless-Chrome printing, but a plain raster-conversion tool may
ignore `foreignObject` — confirm the final output target is browser display or PDF (via headless
Chrome) before using it.

```xml
<foreignObject x="24" y="120" width="200" height="80">
  <div xmlns="http://www.w3.org/1999/xhtml" style="font:14px 'Hiragino Sans', sans-serif; line-height:1.6;">
    The approver reviews the content and decides whether it needs to be sent back.
  </div>
</foreignObject>
```

## Color (light-mode base, one accent color)

Copy the tokens from html-doc's color-themes.md for the chosen theme verbatim — never invent a new
color. Below is the `claude` theme (terracotta) example.

```xml
<rect fill="#e8ddd3" stroke="#d9c4b0" stroke-width="1" />  <!-- wash / hairline -->
<rect fill="#D97757" />                                     <!-- accent (emphasis elements only) -->
<text fill="#1F1E1D" />                                      <!-- ink (body text) -->
```

Fill surfaces with a single wash color, and reserve the accent for the one element you want to
emphasize. Only borrow html-doc's `--ok` / `--warn` / `--bad` when a status indicator is actually needed.

## Arrow marker definition

Define exactly one arrow marker inside `<defs>` and reuse it for every arrow. Never vary the
arrowhead shape or size line by line.

```xml
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M0,0 L10,5 L0,10 z" fill="#4a5568" />
  </marker>
</defs>
<line x1="224" y1="56" x2="272" y2="56" stroke="#4a5568" stroke-width="1.5" marker-end="url(#arrow)" />
```

## Good and bad examples

A good diagram has boxes aligned to the 8px grid, one arrow-marker style, and labels that fit
inside their boxes. A bad diagram has any of these three — always eliminate them before review:

- Overlapping elements: an arrow piercing a text label, boxes overlapping by a few pixels
- Tiny fonts: `font-size` under 11px (shrinks further on print and becomes unreadable)
- Embedded raster images: a PNG/JPG base64-embedded via `<image>` (bloats the file and blurs on
  zoom — draw icons as `<path>` vectors instead)

## Self-check

- Are the viewBox margins and grid aligned to 8px units?
- Do labels stay inside their boxes, or are they wrapped via `foreignObject`?
- Is the arrow marker unified to a single style?
- Does the color scheme use only the html-doc theme's one accent + wash + ink, with no invented colors?
- Zero embedded raster images (base64 PNG/JPG)?
- Is `font-size` 11px or larger (12px+ recommended to allow for print shrinkage)?
