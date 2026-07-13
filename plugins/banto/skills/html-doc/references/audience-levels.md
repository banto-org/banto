# Audience Levels — Matching the Reader's Level

Most document failures come from "writing at the writer's resolution." Choose the level based on **whether the reader could explain it to someone else the next morning**.
The level is a **writing-calibration axis independent of the template (use case)** — any template (report / runbook / explainer / proposal) can be written at any level. It's also independent of language (Japanese/English).

## Determining the level

Infer it from the request, and disclose the inferred level as the adopted interpretation up front. When in doubt, **go one level down** (writing at L3 and shipping to an L1 reader is a much worse failure than the reverse).

| Signal | Inferred level |
|---|---|
| "for the CEO," "for executives," "for the client's senior people," "for a decision" | L1 |
| "for the client-side PM," "for a director," "for a non-engineer who still gets it" | L2 |
| "for the team," "for engineers," "for handover," "for technical review" | L3 |

## L1 — Executives / non-engineers

- **Structure**: conclusion (one sentence) → impact/effect (numbers) → the decision being requested → put the rationale in an appendix
- **Style**: zero jargon. For proper tool names, add a short gloss ("X (a mechanism for doing Y)") or put them in a glossary. Aim for sentences under 40 characters
- **Diagrams**: at most one flow with 3–5 boxes. No sequence diagrams or ER diagrams. **Write the conclusion directly into the diagram** (annotations like "this is the bottleneck")
- **Numbers**: convert to cost, effort, and dates ("40% latency reduction" → "wait time drops from 5 seconds to 3 seconds")
- **Length**: 1–2 A4-equivalent pages. If it exceeds 3 screens of scrolling, cut it down

## L2 — PMs / directors / semi-technical roles

- **Structure**: conclusion → background → options and rationale (why adopted/rejected) → schedule impact → next action
- **Style**: jargon is fine, but gloss it in half a line on first use. Always state "why we did it this way"
- **Diagrams**: flow, gantt, and state-transition diagrams are fine. Up to 3 diagrams per document
- **Length**: 2–4 A4-equivalent pages

## L3 — Engineers

- **Structure**: conclusion → technical detail (don't omit it) → verification method (reproduction commands, paths) → known constraints
- **Style**: use precise terminology as-is. Include code blocks, paths, and commit hashes. Mark ambiguity explicitly with "Unverified:"
- **Diagrams**: sequence, ER, and architecture diagrams are fine. Skip the diagram where precise text (paths, types) communicates better than a picture would
- **Length**: as much as needed, but the conclusion and TL;DR must always come first

## Shared rules

- Every level requires a **conclusion box (summary) at the top**. Never ship a document where the reader has to finish reading to find the conclusion
- Every level requires a **next action / decision request at the end**
- Never mix multiple levels in one document. If mixing is unavoidable, split it into "main body at L1 + appendix at L3"
- **Client-facing (external) documents must follow the pii-protection rule**: mask internal member names, other project names, other companies' names, and unit prices ("Person A," "Company X"). The egress-guard blocks on a registry hit, but mask it yourself before that trigger fires
