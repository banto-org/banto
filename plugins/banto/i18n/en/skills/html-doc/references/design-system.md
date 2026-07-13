# Design System — for HTML documents (v2: Claude-style + rich layer)

Numerical basis: empirical survey of Tufte CSS / GOV.UK / Japan Digital Agency Design System / IBM Carbon

Shift from v1 (paper-purist, cards forbidden) to v2: prioritizing **visual absorbability over a conventional document look**,
adopting a Claude-style rich composition — an ivory ground with white cards. Typography/spacing discipline is preserved.

## Core principles

1. **Absorbability first** — the reader should grasp key points by skimming. Visualize key points with KPI cards, timelines, bar charts, and callouts.
2. **Two layers, ground and surface** — place `--surface` (white card) on top of `--bg` (ivory ground). Cards are units of information (tables, summaries, stats, appendices). **Don't card-ify everything meaninglessly** (body paragraphs sit directly on the ground).
3. **Avoid pure-white ground × pure-black text** — the ground is the theme's off-white; body text is `--ink` (a deep-ink black, not pure black).
4. **Light mode only** — assumes print/PDF. Do not build a dark mode.
5. **Self-contained** — zero external requests (no CDN fonts; diagrams are pre-rendered SVG; JS is inline).
6. **Use the rich layer that only HTML can offer** — a reading-progress bar, scroll-linked TOC, copy-enabled code blocks, collapsible appendices. But **never hide body content with scroll-reveal** (the final state must always be visible; use time-based animation only).
7. **Layout signature** — always use each template's signature (below). "Just max-width + auto margin" is the primary cause of a generic look.

## Typography (fixed values)

**Fonts are system fonts only** (web fonts / CDN fonts forbidden). **Headings are serif** (`--serif`); body text is sans-serif.
This contrast is the core of what makes a page feel "typeset."

```css
/* Japanese version */
body {
  font-family: -apple-system, "Helvetica Neue", "Segoe UI",
               "Hiragino Sans", "Yu Gothic", "Noto Sans JP", sans-serif;
  font-size: 1rem;            /* reports 16px / explainers & proposals 16.5px */
  line-height: 1.8;           /* long-form Japanese text (about 1.7 inside cards) */
  letter-spacing: 0.02em;
}
h1, h2, h3 {
  font-family: var(--serif);  /* headings are serif */
  font-weight: 600;           /* never use bold */
  font-feature-settings: "palt";
  text-wrap: balance; word-break: auto-phrase;
}
em, i { font-style: normal; font-weight: 600; }  /* no italics for Japanese (synthetic oblique) */
table, .kpi .n, .stat .value { font-variant-numeric: tabular-nums; }
```

```css
/* English version (templates/html-doc/en/) — separate tuning for Latin text */
body {
  font-family: -apple-system, "Helvetica Neue", "Segoe UI", Roboto, Arial, sans-serif;
  line-height: 1.7;           /* 1.6–1.7 for Latin text */
  /* no letter-spacing */
}
/* Headings use var(--serif) (Georgia-family). Italics are allowed. Small labels: text-transform:uppercase + letter-spacing:.06em */
.sec p { max-width: 46em; }   /* ideal line length for Latin text, roughly 60–70 characters */
```

- **Type scale**: 12 / 13 / 14 / 16 / 17 / 18 / 24 / 36 / 46px equivalents (specified in rem/clamp). Don't invent intermediate values.
- **Headings are serif and large**: h1 is `clamp(2rem, 4.5vw, 2.875rem)`. Numbers use `--serif` small caps (`0 counter()` / ghost numerals).
- **Jump ratio**: h1 ÷ body text = 2.2–2.8x. Beyond 3x reads as too magazine-like.
- **Line length**: body text `max-width: 40–46em`. Body text inside a card can be unconstrained (the card width itself is the constraint).

## Spacing (8px-based scale)

Only `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 88 / 96px`. **Mixing in intermediate values (e.g. 17px) is the single biggest cause of a cheap look.**
- Between sections: 80–96px / heading to body: 16–28px / inside a card: `padding: 22–36px` / table cells: `13px 20px`
- Card corner radius: `12–14px` (small chips: `999px`). Don't let corner-radius values proliferate either.

## Layout signature (one per template — this is what makes it feel "designed")

Every template is a two-column shell: **body column + right rail (scroll-linked TOC)** (`grid-template-columns: minmax(0,1fr) 200–216px`), collapsing to a single column at narrow widths / in print.

| Template | Signature | Implementation |
|---|---|---|
| report | **Serif-numbered sections + KPI cards** | Stat cards in the hero; each h2 gets a `0 counter()` serif number + hairline. Timelines/bar charts visualize progression and volume. |
| guide | **Large STEP cards + confirmation checks** | Each procedure is a white card with a `STEP N` pill. A localStorage-persisted checkpoint list at the end. Progress count in the TOC. |
| explainer | **Large ghost numerals** | `position:absolute; font-size:6.5rem; opacity:.08` chapter numbers behind headings. Term tooltips, before/after cards. |
| proposal | **Accent-bar cover + stats** | Vertical-bar cover using `grid-template-columns: 6px 1fr`. Problem cards, effect stat cards, cost table. |

## Cards / shadows

- Card = `--surface` ground + `1px var(--hairline)` border + `--shadow` + 12–14px corner radius.
- `--shadow` is a subtle two-layer shadow (`0 1px 2px` for proximity + `0 4px 16px` for diffusion). **Don't darken the drop shadow.**
- Emphasis cards: left `4px solid var(--accent)` (summary) / top `3px solid var(--accent)` (stat, hot KPI).
- A dark card (next actions) uses `--ink` ground + `#F5F1E8` text, used just once as a closer.

## Tables

- **Horizontal rules only** (vertical rules read as "pasted from Excel"). Wrap in `.tablewrap` to enclose in a white card with rounded corners and a shadow.
- thead: `background: var(--wash)` + a hairline below. Cell `padding: 13px 20px`. `th` uses small caps.
- Numeric columns are right-aligned with `tabular-nums`. Row hover uses `--wash`. In print, `thead { display: table-header-group }`.

## Role of color (palettes switch by theme → color-themes.md)

| Token | Role |
|---|---|
| `--bg` / `--surface` | Page ground / card surface |
| `--ink` / `--sub` | Body text / secondary text |
| `--accent` | Shapes, fills, bars, KPI numerals, timeline dots |
| `--accent-deep` | The deeper accent for text — heading numbers, kickers, links, labels |
| `--accent-soft` | An extremely light fill — badges, STEP pills, selection ranges |
| `--wash` | A light fill — table headers, callout background, bar background, inline code |
| `--hairline` / `--shadow` | Rule lines / card borders / shadows |
| `--ok/--warn/--bad`(+ `-bg`) | Status colors (badges/callouts only — theme-independent) |

## Animation (time-based only)

```css
@media (prefers-reduced-motion:no-preference) {
  @keyframes fadeUp { from { opacity:0; transform:translateY(12px); } to { opacity:1; transform:none; } }
  .hero > * { animation:fadeUp .5s ease backwards; }  /* stagger the fade-in with delay */
}
@media print { * { animation:none !important; } }
```

**Forbidden**: the pattern of setting `.reveal{opacity:0}` via `IntersectionObserver` and adding `.in` on scroll.
This leaves **body content blank** under headless screenshots, PDF export, and JS-disabled environments. Animation must always be time-based and complete within 1 second.

## Print CSS (required in every template)

```css
@media print {
  @page { size: A4 portrait; margin: 16mm 14mm 18mm 16mm; }
  html { font-size: 10.5pt; }
  body { background: #fff; }
  .toc, #progress, #top-btn, .copybtn { display: none !important; }   /* remove the decorative layer */
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

## Verification (recommended: confirm the actual render headlessly before delivering)

```sh
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$C" --headless=new --disable-gpu --screenshot=/tmp/shot.png --window-size=1440,2400 file.html   # screen
"$C" --headless=new --disable-gpu --print-to-pdf=/tmp/out.pdf file.html                           # print
```

## Prohibited (causes of a generic/AI-generated look)

- No line-length control / all headings the same weight and sans-serif (headings should be serif) / uniform 1.5 line-height / letter-spacing over 0.05em on Japanese text.
- Headings missing `palt` / mixed spacing or corner-radius values / tables with vertical rules / underlines or brackets on headings.
- Pure white and pure black / system blue (`#007bff`-family) / emoji / heavy drop shadows / multi-color gradients.
- Leaving Japanese text to the OS via a Latin-only font-family / italicizing Japanese text.
- **Hiding body content with scroll-reveal** (an implementation where the final state is invisible).
- A document with no "so what do you want me to do" (no next action / decision request).
