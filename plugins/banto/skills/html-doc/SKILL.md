---
name: html-doc
description: |
  Generates modern, self-contained HTML documents from templates (by purpose: report / runbook / explainer / proposal × Japanese / English × 7 color themes). Defaults to Claude-style light mode (ivory background + white cards + a single accent color). Every template ships with HTML-native rich layers (a reading-progress bar, a scroll-synced table of contents, KPI stat cards, a timeline, CSS bar charts, code blocks with copy buttons, collapsible appendices, and load-in animation). Diagrams go through mermaid (.mmd → inline SVG) or draw.io (an editable .drawio file bundled alongside). Audience level (L1 non-technical / L2 semi-technical / L3 technical) is applied across every template as a writing-style adjustment axis. Light mode only, using standard system fonts.
  Triggers: "make an HTML report", "write a runbook", "turn this into a document", "put together an explainer", "draft a proposal", "report", "runbook", "proposal", "explainer".
  Do not use when: implementing an app/screen UI (use the ui-design skill instead if available), internal memos or decision records (Markdown suffices), or deciding B2B proposal chapter structure / pptx generation (b2b-docs skill).
user-invocable: true
argument-hint: "[purpose (report/guide/explainer/proposal) or a description of the subject matter (optional)]"
allowed-tools: Read Write Edit Bash Glob
compatibility: Claude Code
---

# HTML Doc — Modern HTML Document Generation Skill

Generates documents as a single, self-contained HTML file (zero external requests).
Safe even for NDA-covered deliverables (no CDN fonts, no external CSS, no tracking — fonts are standard system fonts only, and diagrams are pre-rendered inline SVG). **Light mode only** (built for print/PDF; no dark mode is produced).

## Design policy (Claude-style + HTML-native richness)

The top priority is being **more visually absorbable** than an ordinary document — not a degraded copy of a paper PDF.

- **Palette**: default theme `claude` (ivory background `#F0EEE6` + white cards `#FFFFFF` + a terracotta accent `#D97757`). A calm, warm-toned base; swap in one of 6 other themes depending on industry.
- **Typography**: serif headings (`Iowan Old Style` / `Georgia` family), sans-serif system font for body text. The contrast between heading and body creates visual hierarchy.
- **HTML-native rich layers** (built into every template; individual pieces can be removed):
  - A **reading-progress bar** at the top / a **scroll-synced table of contents** in the right rail (highlights current position) / **Back to top**
  - **KPI stat cards** (numbers as the visual centerpiece) / **timeline** (chronology) / **CSS bar charts** (quantity comparison)
  - **Code blocks with a copy button** / **collapsible appendices (`<details>`)** / card-styled tables and callouts
  - **Load-in animation** (time-based, completes in roughly 1 second; hero elements fade in sequentially)
- **Print**: `@media print` automatically strips the decorative layer (bar / TOC / buttons / animation / shadows) and optimizes for A4 portrait.
- **Forbidden**: implementing **scroll-reveal that hides body content via `IntersectionObserver` is forbidden** (content disappears in headless screenshots, PDF export, or JS-disabled environments). Animation must always be time-based, and the final state must always be visible.

## Workflow

```
1. Gather requirements → identify purpose (see table below) / language (Japanese or English) /
               audience level (L1-L3) / theme.
               If unclear, infer from the request and disclose it as an adopted interpretation.
2. Choose template → Read one of ${CLAUDE_PLUGIN_ROOT}/templates/html-doc/{report,guide,explainer,proposal}.html (Japanese)
               or ${CLAUDE_PLUGIN_ROOT}/templates/html-doc/en/*.html (English).
3. Choose theme  → set <html data-theme="..."> from the 7 options (default: claude; see references/color-themes.md)
4. Confirm design → references/design-system.md (numeric values / prohibitions) + audience-levels.md (audience-level adjustment)
               For Japanese documents, also apply ~/.claude/rules/writing-ja.md (sentence-ending style,
               reducing katakana loanwords, half-width spaces, not rounding numbers)
5. Build diagrams → first consult the diagram skill for which notation to use and how (mermaid / draw.io / hand-drawn SVG)
               → render per references/diagrams.md: .mmd → render-diagram.sh → inline SVG
6. Assemble      → replace every {{PLACEHOLDER}}, save as a single HTML file, and check it with open
7. Self-check    → run the checklist below
```

## Templates (scoped by purpose, each available in both Japanese / English)

Template location: `${CLAUDE_PLUGIN_ROOT}/templates/html-doc/` (paths below are relative to this)

| Purpose | Japanese | English | Layout signature |
|---|---|---|---|
| Report (status / investigation / incident) | `report.html` | `en/report.html` | Left margin label column |
| Runbook (setup / operations) | `guide.html` | `en/guide.html` | Large STEP numbers + verification checkpoints |
| Explainer (concepts / mechanisms / onboarding) | `explainer.html` | `en/explainer.html` | Ghost chapter numbers |
| Proposal / plan document | `proposal.html` | `en/proposal.html` | Accent-bar cover page |

- Choose language based on **the reader's language** (even if the request is in Japanese, use en/ if the audience is English-speaking, and disclose this as an adopted interpretation)
- Audience level (L1 non-technical / L2 semi-technical / L3 technical) is a **writing-style adjustment axis** independent of the template → see `references/audience-levels.md`

## Color themes (shared across all templates, switched via data-theme)

`claude` (**default** — general-purpose / warm) / `navy` (reporting / finance) / `forest` (environment / healthcare) / `burgundy` (tradition / culture) / `sumi` (specifications / minimal) / `copper` (creative) / `slate` (IT / SaaS)
For custom derivation from a client's brand colors → `references/color-themes.md`

## Diagram pipeline (details: references/diagrams.md)

- **First choice: mermaid** — write `.mmd`, run `sh "$CLAUDE_PLUGIN_ROOT/scripts/render-diagram.sh" x.mmd`, then inline the resulting SVG (works offline, print-safe, id collisions avoided automatically)
- **draw.io**: for freely-placed architecture diagrams → bundle the `.drawio` XML alongside the document (client-editable). Converted to SVG only when the CLI is available.
- Fall back to a CDN runtime only when rendering is not possible (always disclose that this introduces an external request)

## Saving and verification

- Save location: wherever specified; otherwise the project's `docs/`, or the ai-context store's `docs/` for internal reports
- Bundle `.mmd` / `.drawio` source files alongside the document (so they can be regenerated / revised)
- After generation, check with `open <file>`. If the document is meant for print, also check the print preview.

## Self-check (always run before delivering)

- [ ] No `{{` remains (no unreplaced placeholders)
- [ ] Zero external requests: `grep -oE 'https?://[^"'"'"' >]+' file.html | grep -v w3.org` returns nothing (SVG's `xmlns` is a non-network identifier and is excluded)
- [ ] Language matches the reader (no English labels mixed into a Japanese document, or vice versa). No italics in Japanese text (italics are fine in English)
- [ ] **Japanese body text follows `~/.claude/rules/writing-ja.md`** (no だ・である・です・ます sentence endings — use noun endings / plain form / reduce katakana loanwords / half-width space around alphanumerics / never round numbers in reports). Does not apply to English output.
- [ ] For client-facing documents → internal names, other companies' names, and PII are masked (per the pii-protection rule)
- [ ] Writing style matches the audience level (no jargon shown to an L1 audience)
- [ ] Exactly one theme is applied, with a single accent color (the 3 status colors are an exception), and zero emoji
- [ ] Diagram SVGs use `max-width:100%` without breaking, and don't split across pages in print preview
- [ ] **Body content is never hidden by scroll-reveal** (animation is time-based; the final state is always visible)
- [ ] **Verify actual rendering headlessly** (recommended): check the screen with `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --screenshot=/tmp/shot.png --window-size=1440,2400 file.html`, and check print output with `--print-to-pdf=/tmp/out.pdf`
- [ ] The TOC correctly picks up h2 headings and `id` values are unique (when using the rich layers)

## Detailed references

- `references/design-system.md` — numeric document design system (type scale, line length, spacing, print, prohibitions)
- `references/color-themes.md` — the 7 color themes (default: claude) + custom derivation from brand colors
- `references/audience-levels.md` — writing style, structure, and diagram granularity by L1/L2/L3
- `references/diagrams.md` — mermaid / draw.io drafting, rendering, and embedding steps
