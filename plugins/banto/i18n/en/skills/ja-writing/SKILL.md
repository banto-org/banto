---
name: ja-writing
description: |
  Practical patterns for writing Japanese documents, reports, Excel cells, and audience-adjusted prose. Applies the `writing-ja` rule's form with concrete examples by document type and audience level.
  Triggers: "write a report", "a Japanese document", "write it in Excel", "a PR description", "a commit message", "write it for this audience", "for executives", "so a non-technical reader can follow".
  Do not use when: generating the HTML document itself (html-doc skill); reading the canonical rule directly (`~/.claude/rules/writing-ja.md`); simple chat-response tone adjustment (the writing-ja rule alone is enough).
allowed-tools: Read
user-invocable: true
compatibility: Claude Code
---

# ja-writing — Practical Japanese writing patterns

Built on the `writing-ja` rule (structure / sentence / ending / notation principles), this skill
holds **concrete, document-type- and audience-level-specific patterns**. The rule owns "what to
follow"; this skill owns "how to write it differently for each case".

## When to use

Before writing a Japanese report, proposal, runbook, Excel cell, chat response, PR description, or
commit message — or whenever the writing needs to be adjusted for a specific audience (executives,
PMs, engineers, etc.).

## Choosing a reference

- Writing for a specific audience level (L1 non-technical / L2 semi-technical / L3 technical) → `references/audience-levels.md`
- Writing a document-type deliverable (report, proposal, runbook) → `references/patterns-documents.md`
- Writing Japanese into Excel cells (label / value / note) → `references/patterns-excel.md`
- Writing a chat response, PR description, or commit message → `references/patterns-chat-pr.md`

Read the matching reference before writing. When multiple angles apply (e.g. a proposal for
executives), Read both audience-levels.md and patterns-documents.md.

## Common principles

- State the conclusion in the first sentence; put reasoning and background after.
- Use exact numbers — never round them.
- Never end a sentence with だ/である/です/ます (use noun-stop or plain verb form).
- Never write process metadata ("(latest)", "newly added", "previously was") into a deliverable —
  git log and decisions already own that history.
- Fix the audience level for the whole document; never mix levels within one document.
