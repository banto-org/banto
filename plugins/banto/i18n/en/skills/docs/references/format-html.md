# format-html — HTML Documents (Richest Version)

The format that maximizes information density. Ships with tooltips, a collapsible right-side table of contents, and Markdown download as standard equipment.
Duplicate `assets/template.html`, keep its structure and scripts intact, and replace the body content.

## Standard Equipment (all required)

| Feature | Implementation |
|---|---|
| Reading-progress bar | `.progress` + scroll-synced JS |
| Opening legend | `.legend` (must explain: dotted underline = term definition, ↗ = source, right-edge bar = table of contents, MD↓ = save) |
| Term tooltip | `<span class="t" tabindex="0">term<span class="tip">explanation</span></span>`. tabindex is required |
| Source pill | `<a class="src" href="URL" target="_blank" rel="noopener">author/outlet↗</a>` (external information only) |
| Notion-style right-side TOC | Right-edge bar → expands on hover/click, highlights the current position, ☰ on mobile. JS auto-generates it from headings |
| MD download | A full-document button plus a per-section MD↓ in the top-right corner of each section. A DOM→MD converter (built into the template) |
| End-of-document glossary | `.gl` (dl/dt/dd). Same content as the tooltips plus a reference URL. Pair each headword with its original English term (`<span class="en">working memory</span>`) |

## Components

`.keybox` (opening conclusion) / `.note.good` and `.note.warn` (supplementary notes / warnings) / `.caveat` (counterpoint / limitation disclaimer) /
`.ba` (✗/✓ two-column comparison) / `.check` (checklist) / `.promptbox` (copy-paste code) / `figure` + SVG (diagram)

## Diagrams

Embed SVG inline as-is (no conversion needed). `role="img"` + `aria-label` are required.
See the diagram skill for patterns. Use the theme file's tokens for color.

## Maintaining the MD Converter

Whenever you add a new display-only element (decoration, buttons, etc.), add it to the converter's skip list (.tip/.mdbtn/.num/nav/svg/button).
Conversion mapping: h2-h4 → # headings / .t → term text only / .src → [name](URL) / table → pipe table / figure → "> [Figure] caption" / .promptbox → code fence / .note and .caveat → blockquote / .gl → **term** + definition.

## Verification

1. Tag consistency and duplicate ids: `python3 scripts/verify-html.py <output>.html` (returns PASS/FAIL)
2. JS syntax: `node --check /tmp/_verify_extracted.js` (if node isn't available, review the JS visually and note that in the report)
3. Behavior: in a browser or jsdom, check (a) TOC bar → panel open/close (b) full-document MD↓ (c) per-section MD↓ (d) tooltip display. In an environment with neither, substitute verify-html.py's static check plus `node --check`, and note in the report that behavioral verification wasn't performed
4. Quality of the MD output: check for tooltip body text leaking in, broken tables, or missing links
5. Reachability of source URLs (a 403 from academic sites is acceptable, since it's typically bot blocking)
