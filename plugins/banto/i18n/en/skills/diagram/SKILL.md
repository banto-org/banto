---
name: diagram
description: |
  Practical patterns for building diagrams, sequence diagrams, architecture diagrams, SVG, mermaid, and draw.io for documents. Assumes the html-doc skill's render pipeline (theme header, render-diagram.sh, SVG embedding) and specializes in choosing and writing the notation itself.
  Triggers: "make a diagram", "a sequence diagram", "an architecture diagram", "an AWS architecture diagram", "in mermaid", "in draw.io", "draw it as SVG", "a flowchart".
  Do not use when: generating the whole HTML document or the render pipeline itself (html-doc skill's diagrams.md); creating diagrams inside Figma (figma-generate-diagram skill).
allowed-tools: Read
user-invocable: true
compatibility: Claude Code
---

# diagram — Choosing a diagram notation and practical patterns

The html-doc skill's `diagrams.md` owns the render pipeline (SVG rendering via mermaid / draw.io,
theming, embedding). This skill specializes in what comes before that: **which notation to choose
and how to write it**. It does not restate the pipeline.

## When to use

Before adding a diagram to a document, when unsure which notation (mermaid / draw.io / hand-drawn
SVG) to pick, or when a chosen notation keeps breaking layout.

## Choosing a reference

- Flowcharts, sequence diagrams, Gantt charts — anything mermaid can draw → `references/mermaid.md`
- AWS architecture diagrams (nested VPC / subnet / AZ, icon sets) → `references/drawio-aws.md`
- Free-layout diagrams that break mermaid's node placement (diagonal emphasis boxes, circular
  processes, annotations over a map) → `references/svg.md`

When unsure, try mermaid first and switch to hand-drawn SVG only once the layout breaks (see "When
to choose hand-drawn SVG" in `references/svg.md`).

## Common principles

- The render pipeline and theme tokens are owned by the html-doc skill's diagrams.md /
  color-themes.md / design-system.md — don't restate them here, and don't invent new colors.
- Keep visual consistency: align to an 8px grid, use one unified arrow marker.
- Mermaid wins for flowcharts, sequence diagrams, and Gantt charts. Hand-drawn SVG is reserved for
  layouts mermaid cannot express.
