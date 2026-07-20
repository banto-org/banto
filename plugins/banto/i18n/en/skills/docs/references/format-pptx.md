# format-pptx — Slide Decks

First confirm the intended use. Design differs between **presented live** (spoken to an audience) and **handout** (a read-through document, consulting-style).

## Common Rules

1. **One message per slide**. Split the slide if there's too much to fit
2. **Make headings the message itself** (writing-core rule 18, shared across all formats — mandatory for slides): treat the body and figures as evidence supporting that heading
3. Order: cover → executive summary (one slide, the conclusion) → body → wrap-up. Add chapter-divider slides beyond 10 slides
4. Font follows the theme (default: Noto Sans JP family). **Body text 18pt or larger**, titles 28pt or larger, margin notes 12pt
5. Contrast of 4.5:1 or higher (go darker than that baseline, assuming colors will look 20-30% lighter when projected)

## Presented vs. Handout

| | Presented live | Handout (read-through document) |
|---|---|---|
| Amount of text | Minimal (the speaker fills in the rest) | Self-contained (understandable on its own) |
| Information per slide | Low (one figure + a message) | High (heading statement + evidence + notes) |
| Margin notes / sourcing | Minimal | Attached thoroughly |

## Diagrams (SVG → PNG conversion, a required step)

Since pptx can't reliably handle SVG, **always convert to PNG before inserting**:

1. Build the SVG (diagram skill patterns, theme colors)
2. Convert to PNG: `rsvg-convert -w 2400 -b none figure.svg -o figure.png` (width 2400px ≈ 300dpi equivalent; `-b none` for transparency). If rsvg-convert isn't available, use `inkscape --export-type=png --export-width=2400`; failing that, take a screenshot via playwright/chromium
3. Insert with python-pptx, specifying a size appropriate to the slide width

## Visual Check (required — never skip)

Always render the generated pptx and check it visually:

1. Convert to PDF with `libreoffice --headless --convert-to pdf <output>.pptx`, then rasterize each page to PNG with something like pdftoppm
2. Open and check every slide image: (a) text overflow or broken line wrapping (b) missing, blurred, or distorted-aspect-ratio figures (c) overlapping labels (d) breakage from font substitution
3. If anything is broken, fix it and re-convert and re-check. Never deliver without checking
4. Fallback when tools aren't available: if libreoffice isn't available, read the file back with python-pptx to numerically check figure sizes and text overflow, and visually check the pre-conversion PNGs on their own. Always note in the report that rendering couldn't be verified

## Terminology Annotation

A margin note (12pt, ink-soft color) at the bottom of the slide where a term first appears. For frequently used terms, add a single "Glossary" slide at the end.

## Sourcing

Cite external information in small text at the bottom of the slide. You may collect all sources onto a closing slide, but keep the source for any number on the slide that number appears on.
