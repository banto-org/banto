---
name: b2b-docs
description: |
  Structuring proposals, sales decks, PowerPoint, pptx, and B2B documents. Specializes in the chapter structure (conclusion → problem → impact → evidence → cost → rollout → risk) and in choosing between HTML and PowerPoint as the output format.
  Triggers: "write a proposal", "a sales deck", "in PowerPoint", "as a pptx", "a B2B document", "a rollout proposal", "a client-facing document".
  Do not use when: generating the single-page HTML document itself, built for browser viewing and print-to-PDF (html-doc skill); adjusting tone per audience level (ja-writing skill's audience-levels.md).
allowed-tools: Read
user-invocable: true
compatibility: Claude Code (pptx generation requires python-pptx)
---

# b2b-docs — Structure and output format for B2B proposals and sales materials

The html-doc skill handles a single HTML document built for browser viewing and print-to-PDF. This
skill specializes in what's specific to B2B proposals and sales decks: **the chapter structure
itself**, and choosing an output format when PowerPoint is required.

## When to use

When building a proposal or sales document for a prospect or client, or when deciding whether HTML
or PowerPoint is the right output format.

## Choosing a reference

- Assembling the overall chapter structure (cover-page-one-message → problem → impact → evidence →
  cost → rollout → risk) → `references/structure.md`
- Building in PowerPoint (.pptx), or deciding between HTML and PowerPoint → `references/pptx.md`

For audience-level tone adjustment, go directly to the ja-writing skill's
`skills/ja-writing/references/audience-levels.md` (not restated here).

## Common principles

- The cover page states the result the recipient gets, in one sentence — never the product name.
- Always show impact as a before → after pair of exact numbers, with the source cited in the
  evidence chapter.
- Each slide (each section) carries exactly one claim.
- Avoid self-focused framing, exhaustive feature lists, and claims without numbers.
