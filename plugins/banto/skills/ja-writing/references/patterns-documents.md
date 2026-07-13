# Document-type patterns (reports / proposals / runbooks)

Write documents from a template. Don't start from a blank page — pour content into the skeleton
below and cut any section that stays empty (never leave an empty section). Common rules: put the
conclusion in the first screen. One topic per paragraph. Never end a sentence with だ/である/です/ます
(use noun-stop or plain verb form). Use exact numbers. Never write process metadata ("(latest)",
"newly added", "previously was") into the deliverable.

## Reports (progress / investigation / incident)

Skeleton: conclusion (3 sentences or fewer) → the number backing it → detail → next action (with owner and due date).

> Good (opening): "The search-speed improvement is complete. Average 1.8s → 0.3s (n=30), no added
> cost. The one remaining item is tuning the monitoring dashboard threshold, due by 7/15."
>
> Bad (opening): "This report covers the search-speed improvement. Starting from the background,
> users have previously reported that search was slow…"

The bad example has three flaws: no conclusion, a restated preamble, and a chronological narrative
that starts from background. State background at the end, only when it's essential to understanding
the conclusion.

## Proposals (internal / client-facing)

Skeleton: the reader's problem (one sentence, in their words) → the proposal (one sentence) →
impact (numbers) → cost and timeline → rollout steps → risks and mitigations.

> Good (proposal section): "Automate the first-pass response to inquiries with AI, cutting average
> response time from 4 hours to 5 minutes. Initial cost ¥800,000, ¥120,000/month, 6-week rollout."

Never sell on the writer's effort, the novelty of the technology, or feature completeness. Only a
before → after showing the reader's problem actually changing carries persuasive weight. If the
impact can't be stated in numbers, the proposal is still too coarse-grained.

## Runbooks (operations / handover)

Skeleton: purpose and time required (one line) → prerequisites (only what causes failure if
unmet) → numbered steps → how to verify → what to do on failure.

One number, one action per step. Write the action (what to do) and the check (what indicates
success) as separate items.

> Good: "3. Run `make deploy`. 4. Confirm `deploy: ok` appears at the end of the output. If it
> doesn't, go to step 8 (rollback)."
>
> Bad: "Run the deploy and confirm there are no problems."

Never write an unverifiable check like "no problems." Branches the reader might get stuck on
(environment differences, permission differences) belong in prerequisites, not scattered through the steps.

## Section headings

Headings are composed, neutral noun phrases ("Response to the concern raised"). Never use a casual
heading ("Answering your worry") or a question as a heading. When a sentence follows a heading
label, connect it with a colon.
