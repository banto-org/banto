---
name: docs
description: An integrated skill that produces Japanese explainer documents to a "zero-friction" standard. It switches between HTML (the richest version, with tooltips, a table of contents, and Markdown export), Excel (xlsx), slides (pptx), Word (docx), and tables depending on the document's purpose, while keeping the underlying writing style consistent across every format. Color and design are managed through swappable theme files. Whenever the user says "make me a document," "put together a summary of X," "report," "explainer," "proposal," "write-up," "as slides," "in Excel," or "in Word," use this skill even if the format isn't stated explicitly, and decide the best format from the format-selection table. Combine with the diagram skill (banto) for diagram generation.
user-invocable: true
compatibility: Claude Code (requires bash, python3)
---

# docs — Integrated Skill for Japanese Documents

Whichever format you build (HTML/xlsx/pptx/docx), the underlying writing style and the "zero-friction" quality bar are the same.
Only the format-specific vessel-building steps change.

**Runtime assumptions**: assumes a Claude-family environment where bash and python3 are available. Format-specific external tools (rsvg-convert, LibreOffice, etc.) each have an availability-check branch in their respective format reference.

## Steps (follow this order)

1. **Decide the reader, purpose, and format** — decide using the format-selection table below. Follow the user's specification if given. **If the reader isn't specified, default to "the general reader with the least domain expertise"**
2. **Read `references/shared-rules.md`** — cross-cutting rules for citations, terminology sweeps, themes, diagrams, and verification. Required for every format
3. **Read `references/writing-core.md`** — the writing style shared across all formats (three layers: cognition = readability / persuasion = rhetorical force / scene = document-type conventions. Wording substitutions live in `references/wording-swaps.md`)
4. **Read the format-specific reference** — the matching one of `references/format-html.md` / `references/format-xlsx.md` / `references/format-pptx.md` / `references/format-docx.md`. Also read `references/format-tables.md` if you're using tables
5. **Write, draw, and verify** — follow the steps in shared-rules.md. Always run the `scripts/` checkers
   (term-sweep = terminology / style-sweep = phrasing / verify-html = HTML)
6. **Save** — follow the ai-context `docs/` canon (`skills/ai-context/references/directory-structure.md`) for save location and naming; do not invent your own naming. `{base}/docs/[Prefix] {YYYY-MM-DD}_{slug}[_{variant}].ext`:
   - **Pick the prefix by intent**: explainer / how-to / overview → `[Guide]` / proposal / plan / design → `[Design]` / progress / report → `[Status]` / audit / analysis → `[Audit]`
   - **Date goes first, `_` separator**. Get the date by running `date +%Y-%m-%d` (do not write it from memory). `_variant` is an optional suffix for model comparisons etc. (e.g. `_fable`)
   - **Slug language**: English by default. **Only distributable office documents (docx / xlsx / pptx) use a Japanese slug** to match the body; HTML and md use an English slug (URL portability / structural artifacts)

## Format-selection table

| What the reader does | Format | Rationale |
|---|---|---|
| Reads closely to understand (internal sharing, explainers, investigation reports) | **HTML** | Maximizes information density. Can carry tooltips, a table of contents, and Markdown export all at once |
| Checks, reuses, or re-sorts numbers | **xlsx** | When the spreadsheet computation itself is the point. Don't build a document meant to be read in Excel |
| Presented live in a meeting / flipped through by the reader / the recipient edits or swaps slides | **pptx** | Live-presentation design differs from handout design — see the branch in format-pptx.md. Choose pptx if the recipient is expected to edit it into their own template |
| Printed, circulated, stamped, or kept as a formal document | **docx** | Approval requests, reports, contract-related documents. Best suited to a long, continuous read |
| Comparing 3+ items across 2+ attributes | **Table** (within any format) | Don't lay numbers out in prose — follow format-tables.md |

When in doubt, choose HTML — it loses the least information across the widest range of reader environments.
If you need both HTML and pptx, lock down the outline in HTML or plain text first, then pour it into pptx.

For structure, tone, and prohibitions specific to a scenario (proposal / report / request / apology / release notes), follow the
layer-3 convention table in writing-core.md (e.g., reports and requests lead with the conclusion; proposals alone save the conclusion for the end).
