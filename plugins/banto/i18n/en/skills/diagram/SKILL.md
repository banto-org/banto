---
name: diagram
description: |
  Practical patterns and notation choice for building diagrams, explanatory illustrations, sequence diagrams, and architecture diagrams in SVG / mermaid / draw.io. Complete SVG code is provided for 14 patterns: correspondence mapping, ✗/✓ comparison, capacity stack, flowchart, ranking bar, pyramid structure, logic tree, 2-axis matrix (four quadrants), Venn diagram, cycle diagram (PDCA), Gantt chart, funnel, roadmap, and swimlane. Assumes the html-doc skill's render pipeline (theme header, render-diagram.sh, SVG embedding) and specializes in choosing a notation and writing it without breaking layout.
  Triggers: "diagram this", "turn this into a diagram", "flowchart", "logic tree", "as a matrix", "four quadrants", "Venn diagram", "Gantt chart", "funnel", "roadmap", "swimlane", "sequence diagram", "architecture diagram", "AWS architecture diagram", "in mermaid", "in draw.io", "draw an SVG diagram".
  Do not use when: generating the whole HTML document or the render pipeline itself (html-doc skill's diagrams.md); creating diagrams inside Figma (figma-generate-diagram skill); charting real data as bar/line/scatter plots (chart libraries).
allowed-tools: Read
user-invocable: true
compatibility: Claude Code
---

# diagram — Choosing a diagram notation and practical patterns

The html-doc skill's `diagrams.md` owns the render pipeline (SVG rendering via mermaid / draw.io,
theming, embedding). This skill specializes in what comes before that: **choosing which notation
fits the structure you want to convey, and how to write it without breaking layout.** It does not
restate the pipeline.

## Choosing a reference

- Explanatory diagrams (conveying a concept or structure) → `references/svg-patterns.md` (a library
  of complete SVG code for 14 patterns — copy one and swap in your own text, colors, and coordinates)
- Sequence diagrams, state diagrams, and auto-generated Gantt charts with dependencies →
  `references/mermaid.md`
- AWS architecture diagrams (nested VPC / subnet / AZ, icon sets) → `references/drawio-aws.md`

For explanatory diagrams, start by choosing from the 14 patterns in svg-patterns.md. Switch to
mermaid's automatic layout only for strict flows with many decision branches, or diagrams whose
element count exceeds a given pattern's limit.

## Selection table (structure to convey → pattern)

| Structure to convey | Pattern |
|---|---|
| One-to-one correspondence between two lists (problem → solution, requirement → feature) | ① Correspondence Mapping |
| Good/bad, Before/After, or a left-right cause-effect contrast | ② Comparison Split (✗/✓) |
| Finite capacity, changing composition (cutting something frees up room) | ③ Capacity Stack |
| The flow of a procedure or process (up to one return branch) | ④ Flowchart |
| Ordering, ranking, magnitude | ⑤ Ranking Bar |
| A persuasive hierarchy topped by the conclusion (proposals, reports) | ⑥ Pyramid Structure |
| Decomposition / hierarchy (mutually exclusive, collectively exhaustive; problem analysis) | ⑦ Logic Tree |
| Positioning / prioritization along two axes | ⑧ 2-Axis Matrix |
| Overlap and commonality between sets (e.g. 3C) | ⑨ Venn Diagram |
| A cyclical process (e.g. PDCA) | ⑩ Cycle Diagram |
| A task × timeframe schedule (ground level) | ⑪ Gantt Chart |
| A process where numbers narrow down through stages | ⑫ Funnel Diagram |
| An overall plan across a timeline × initiative category | ⑬ Roadmap |
| A business process spanning departments / owners (who, when) | ⑭ Swimlane |

Choosing between similar structures: use ⑥ Pyramid when the goal is persuasion, ⑦ Logic Tree when
the goal is decomposition or discovery. Use ⑬ Roadmap for an overall plan and ⑪ Gantt for detailed
weekly schedules. Use ⑧ Matrix for forward-looking strategy, and a scatter plot (a real-data chart)
for the distribution or correlation of existing data.

For structures not in the table, choose a different kind of diagram. Real-data charts —
proportions/breakdowns (pie chart, stacked bar), trends over time (line chart), distribution/
correlation (scatter plot) — should be drawn with a chart library. For an API call timeline, use
mermaid's `sequenceDiagram`; for state transitions, use `stateDiagram-v2` (see mermaid.md).

## Design principles (common to all patterns — 5 rules)

1. **One diagram, one message** — decide the single thing you want to convey before choosing a
   pattern. Cramming in more buries the main message.
2. **Labels next to their elements** — never split them out into a separate legend (a color-to-name
   table). Making the eye travel back and forth hurts comprehension.
3. **Emphasize only one attribute** — vary just one of color, weight, or size. Changing several at
   once slows down visual search.
4. **Zero decoration** — no gradients, shadows, 3D, or unrelated icons. Remove any ink that doesn't
   represent data.
5. **Put the conclusion in the caption** — write the one sentence this diagram is meant to say in
   the `figcaption`. Don't just restate the diagram's contents.

## General numeric constraints (hand-drawn SVG)

- Fix `viewBox="0 0 624 <height>"`. Do not set `width` / `height` attributes.
- Align coordinates to an 8px grid. Standardize box height to 40 / 48 / 56px, and vary only the
  width by content.
- **Box width = max label character count × 13px + 24px padding** as the minimum width, rounded up
  to a multiple of 8.
- Text must be 11px or larger (body labels 12–13px / headings 13–14px). Wrap only with manual
  `tspan` line breaks.
- Reuse a single `<defs><marker>` arrow style. Always include `role="img"` + `aria-label`.
- When a pattern's element-count or character-count limit (given per pattern in svg-patterns.md) is
  exceeded, split the diagram — don't cram it in.

## Common principles

- The render pipeline and the mermaid / draw.io themes are owned by the html-doc skill's
  diagrams.md / color-themes.md. The explanatory diagrams in svg-patterns.md use the navy-based
  color tokens defined at the top of that file — don't invent new colors.
- Deliver output as a `<figure>` + SVG + `<figcaption>` (one conclusion sentence) set.
