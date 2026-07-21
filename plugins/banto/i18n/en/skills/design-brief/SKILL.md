---
name: design-brief
description: |
  Converts a vague UI request ("make it stylish", "make it look nice") into a 14-dimension design specification (a design brief) anchored on purpose and target audience. Sits upstream in the pipeline: concept (ideology) → design-brief (this skill, design specification) → spec (design doc) → implementation.
  Triggers: "spec out this design", "I need a design brief for this screen", "give me UI direction", "I want this to look stylish", "make this screen look nice". Fires ahead of concept or spec whenever a screen or UI is involved.
  Do not use when: the request has no UI involved; adjusting prose for a reader's technical level (docs skill's audience-levels.md); generating the actual HTML/code (docs skill or the implementation phase).
allowed-tools: Read
user-invocable: true
argument-hint: "[screen or service you want designed]"
compatibility: Claude Code
---

# Design Brief — turning a vague UI request into a 14-dimension spec

> Source: [AI でおしゃれな画面を作るためのデザインシステムを学ぼう！](https://qiita.com/yusuke_ando_vj/items/dd17a285217a15841a3a) (Qiita, Japanese). This skill borrows only the structure of dimensions and rebuilds it independently; see the source article for the full catalog.

## Why this exists

A request that only says "make it stylish" or "make it look nice" conveys nothing to an AI or a
designer. Web design is decided by a combination of dimensions — information architecture, layout,
visual style, color, typography — and **the same service has a different correct answer once the
target audience changes**. This skill converts a vague request into a brief with clearly-defined
dimensions to fill in.

## Procedure

1. Read `references/target-driven-design.md` and pin down the target audience (persona, situation,
   emotional state) first. **Do not move on to any other dimension until the target is settled** —
   every other dimension ripples out from it.
2. Fill in the 14 dimensions from `references/brief-template.md`, in order. Run this as a plain-text
   dialogue and capture the user's own words (do not use AskUserQuestion).
3. When choosing a visual style, pick from the representative styles in
   `references/style-catalog.md` and specify a combination rather than a single style.
4. Present the completed brief in the conversation. If the work moves on to implementation or
   screen generation, hand it off to `/spec` — generating code itself is out of scope here.

## Principles

- Target first: color, type size, tone, and style all ripple out from the target audience (see
  `references/target-driven-design.md` for detail).
- State the impression to avoid alongside the impression you want — never just one side.
- Audience level (L1-L3, the axis for how readable a piece of writing is) and design target (the
  axis for how a screen looks) are independent — don't conflate them.

## Forbidden

- Deciding layout, color, or style before the target audience is settled.
- Rushing through all 14 dimensions vaguely instead of nailing each one down.
