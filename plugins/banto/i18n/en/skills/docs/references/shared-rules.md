# shared-rules — Rules Shared Across All Formats (citation, terminology, theme, diagrams, verification)

## Citation and sourcing rules

The classifying criterion is **not where the information sits, but where the claim's authority
comes from**.

- **No citation needed**: the user's own internal data, facts handed over directly in
  conversation (sales figures, internal decisions, etc.). A mention of the file name is enough
  if needed.
- **Citation required**: any claim whose basis has an **external origin** — research, statistics,
  standards, books, other companies' case studies. **Even if it's been transcribed into a file on
  the PC, an externally-originated claim still requires a citation** (trace it back to the
  original source to verify).
- Example: if a source file says "研究によると…" ("according to research at XX university…"),
  that's external information. Being inside a file doesn't exempt it from citation.
- Verify the source URL before writing it. Don't write an external claim you can't verify.
- **The linked claim must actually match**: don't just confirm the URL resolves — confirm the
  linked page actually backs the specific claim (e.g. don't cite a measurement paper as the
  source for "voted word of the year" — match each claim to the correct original source).
- Placement: put numbers, research, and standards right after the claim (HTML = link, pptx/docx =
  footnote or margin note, xlsx = a note).
- **Density cap**: at most 2 citations per sentence. If 3 or more would cluster together, keep
  one representative citation in the body and move the rest to a source list at the end (a
  cluster of links breaks the reading flow).
- **Consistent labeling**: link labels are "Author name Year↗" (e.g. Cowan 2010↗). If there's no
  clear author, use "Publisher name Year↗" (e.g. Agency for Cultural Affairs 2022↗). Don't use
  type labels like "実験研究↗" ("experimental study↗") or "メタ分析↗" ("meta-analysis↗").

## Terminology sweep (never skip)

The most common quality failure is a term left unglossed that only industry insiders or English
speakers would understand.

1. **Extract**: run `scripts/term-sweep.py <deliverable> --known <deliverable-name>.known-terms.txt`
   to mechanically enumerate katakana loanwords, English words, and abbreviations (the known-file
   location follows the same convention as the wording sweep section).
2. **Judge**: decide term by term whether the intended reader would understand it without
   explanation. **If the reader isn't specified, default to a general reader, and when in doubt,
   err toward "won't understand"** (a gloss is never a friction point in excess).
3. **Gloss**: gloss unfamiliar terms **once, on first appearance**. The method follows the "term
   glossing" section of each format-specific reference (that's the canonical source — not
   repeated here).
4. **Re-check**: any term appearing 5+ times must be in the glossary even if already glossed
   inline. English-origin tool/concept names (skill, hook, token, etc.) are also glossing targets.
   "A developer would understand it" is not an excuse.
5. **Glossary quality**: headword entries carry the original English alongside the Japanese (e.g.
   ワーキングメモリ working memory). Even where the body text simplifies away the formal name
   (e.g. rendering BLUF as "結論を最初に書く型," "the pattern of writing the conclusion first"),
   **the formal name must still appear in the glossary** — simplifying the body is one
   obligation, preserving the formal name in the glossary is a separate one.
6. **Completion check**: re-run term-sweep.py and confirm zero unglossed terms (or that all
   remaining ones are on a reviewed exclusion list).

## Theme resolution rule (swapping colors/design)

1. If `theme-custom.md` exists in the references/ folder, **use it** (a company's or individual's theme; it
   overrides every token).
2. If it doesn't exist, use `references/theme-default.md`.
3. If the user specifies a theme in conversation, save it as theme-custom.md first, then use it
   (so it takes effect from then on too).

The theme may only change colors, fonts, and logo-type assets. Never change the body text or
layout structure.

## Diagram rules

- Once a prose explanation of a comparison, correspondence, flow, hierarchy, or ranking runs past
  3 lines, turn it into a diagram. Patterns live in the diagram skill.
- **Use plain language inside diagrams**: diagram labels should use a plain rewording, not the
  technical term itself (e.g. "外在的負荷" ("extraneous load") → "伝え方の負荷" ("the burden of
  how it's explained"); "MECE" → "重複と漏れなく" ("no overlaps, no gaps")). The exact technical
  name and its explanation belong in the body text's tooltip/gloss. Division of labor: the
  diagram carries the message's plainness, the body carries its precision.
- Conversion: HTML = embed the SVG as-is / pptx, xlsx, docx = convert the SVG to PNG (300dpi-
  equivalent, transparent background; steps live in each format's reference).
- **Visual check is mandatory**: open or render the deliverable and check for (a) text overflow,
  (b) missing or broken diagram parts, (c) overlapping labels. Never deliver without this check.

## Wording sweep (never skip)

After unglossed terminology, the next most common quality failure is leaving stiff,
translation-ese, or AI-sounding expressions in place (e.g. "されうる," "することができる,"
"において"). The canonical swap list is `references/wording-swaps.md`.

0. **Exclusion-file convention**: place `<deliverable-name>.known-terms.txt` (terminology) and
   `<deliverable-name>.known-style.txt` (wording) in the same directory as the deliverable, and
   keep them alongside it (a record of judgment calls; start both empty on the first pass).
1. **Detect**: run `scripts/style-sweep.py <deliverable> --known <deliverable-name>.known-style.txt`
   and enumerate the flagged lines.
2. **Judge**: for each hit, decide "rewrite it" or "keep it deliberately." When keeping one
   (legal register, a quotation, etc.), register the context snippet in the exclusion file (this
   becomes a record of the judgment call).
3. **Completion check**: re-run and confirm zero detections (or that everything remaining is
   registered as excluded).

## Shared verification (in addition to each format's own verification)

1. Confirm zero unglossed terms with `scripts/term-sweep.py` (for HTML, also run
   `scripts/verify-html.py`).
2. Confirm zero stiff-expression/style-mixing detections with `scripts/style-sweep.py` (the
   wording-sweep procedure above).
3. Confirm externally-originated claims are cited, and that internal information doesn't carry
   unnecessary citations.
4. Confirm the diagram visual check is complete.
5. Friction self-check: read straight through as if you were someone with no prior context, and
   flag (a) any term that made you want to look it up, (b) any claim you doubted, (c) any passage
   you had to read twice. Keep revising until there are zero flags.
