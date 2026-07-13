# Structuring a persuasive B2B document

The existing html-doc skill's audience-levels.md handles the tone/volume adjustment axis for L1
(executives) / L2 (PMs, semi-technical roles) / L3 (engineers). This guide assumes that axis and
specializes in what's specific to B2B proposals and sales decks: **the chapter structure itself**
and the "one claim per slide" discipline. Audience-level judgment and tone go straight to
audience-levels.md — not restated here.

## The overall skeleton

Fix a B2B proposal to this order. Reordering it means the reader carries "what exactly do you want
me to do" all the way to the back half of the document, which is a common cause of drop-off.

1. **Cover page, one message**: write the conclusion, not a title ("cut inventory-check wait time
   from 5 minutes to 30 seconds", not "A proposal to introduce Product X").
2. **Problem**: put into words 1–2 pains the reader already recognizes (leading with a pain they
   haven't noticed yet reads as self-serving).
3. **Impact (before → after numbers)**: show, with exact numbers, the state after the problem is solved.
4. **Evidence**: back up why that impact should be believed (case studies, measured data,
   third-party evaluation).
5. **Cost and timeline**: state the amount and the days to rollout explicitly (don't stop at
   "quote available on request" — give a rough range too).
6. **Rollout steps**: what happens by when, after the contract is signed.
7. **Risks and mitigations**: concerns specific to the rollout (dual operation during migration,
   integration with existing systems) and how they're addressed.

## Building the cover-page-one-message

The cover page states neither the product name nor the company name — it states the one result the
reader gets. Include a number wherever possible.

- Good: "An operational improvement that cuts inquiry-handling time from 80 hours/month to 20 hours/month."
- Bad: "Introducing Company X's Customer Support DX Solution" (the cover alone doesn't say what changes).

## Writing the problem → impact numbers

Always write impact as a before → after pair. A standalone number ("processing speed up 3x") has
no stated baseline and carries no persuasive weight.

- Good: "Time to draft a quote cut from 45 minutes to 8 minutes per case."
- Bad: "Significantly improved operational efficiency" (no number, so the reader can't map it to
  their own situation).
- Bad: "300% improvement in processing speed" (the baseline for that 300% is never stated, so it
  reads as an unverifiable number).

Always state the source of the number (your own measurement, a client's actual results, an industry
average) in the evidence chapter. A number without a cited source is, to the reader, the same as a
number with no basis.

## One claim per slide

Each page of a document (each section, for an HTML document) carries exactly one claim. Packing
multiple claims onto one page leaves the reader unable to tell which one actually matters most.
Supporting evidence and charts for that claim may share the page — but never mix in a different claim.

- Good: one page argues only "the cost payback period is 4 months," with a single supporting chart.
- Bad: one page bullets "cost reduction," "better usability," and "stronger security" together,
  none of them explored in depth.

## Adjusting by audience level (applying audience-levels.md)

For L1 (executives): compress the problem, impact, and cost into 1–2 pages, and push rollout-step
and risk detail into an appendix. Convert numbers into money and labor-hours ("saves ¥150,000/month
in overtime pay", not "40% faster processing").

For L2 (PMs, working-level staff): add an options comparison for "why this approach" alongside the
problem and impact. Write rollout steps by milestone, and go as far as the impact on the relevant
department (e.g. integration work with existing systems).

To combine L1 and L2 in one document, make the body L1-level (a 1–2 page summary) and split the
detail into an L2-level appendix. Mixing both styles into the same chapter makes the document hard
to read for either audience.

## Bad patterns to avoid

Exhaustive feature listing forces the reader to figure out on their own which feature relates to
their problem — avoid it. List only the features tied directly to the reader's problem, not every
feature the product has.

Self-focused framing means writing the document with "we" or "our strength is" as the subject.
Keep the subject fixed on "how your organization changes" — push your company's history or
philosophy to an appendix.

Claims-without-numbers is, as above, any impact statement lacking a before → after pair.
Adjective-only claims like "industry-leading" or "overwhelmingly easy to use" should always be
checked for whether they can be replaced with a number.

## Self-check

- Does the cover page state a one-sentence result instead of a product name?
- Is every impact stated as a before → after pair, with the source cited in the evidence chapter?
- Does each page (each section) carry exactly one claim?
- Do cost and timeline go beyond "quote available on request" (is a rough range given)?
- Are rollout steps written by milestone, down to the impact on the relevant department?
- Do risks and mitigations cover rollout-specific concerns (dual operation, existing integration),
  not just the mirror image of the problem?
- Does the tone match the reader's level (no jargon for L1 — see audience-levels.md)?
- Zero self-focused framing, exhaustive feature lists, or claims without numbers?
