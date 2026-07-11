# Patterns for chat responses, PR descriptions, and commit messages

The shorter the output, the more a fixed form pays off. The form differs across these three settings.

## Chat responses (conversation)

Conversation can use natural language (the sentence-ending rule doesn't apply here). But always
keep three things: put the conclusion in the first sentence; scale response length to the weight of
the question (don't return three paragraphs for a question a single line answers); say in Japanese
what could be said in katakana-English loanwords (イシュー/issue, フィックス/fix, アップデート/update).

> Good: "Fixed. The cause was the load order of environment variables; all 12 tests are green."
> Bad: "Thank you for your question. To summarize the situation first, this issue is…"

## PR descriptions

Skeleton: what changes (one sentence) → why (1–2 sentences) → verification (the commands run and
their exact-number results) → blast radius / what to focus a review on.

> Good: "Scope checkpoint consumption to /clear only. Fixes a race where resume consumed it first,
> leaving nothing for the immediately following /clear (details in decision 2026-07-08-160000).
> test-idle-checkpoint-delivery.sh 17/17 green. Backward-compatible with the existing checkpoint format."

Don't restate what a diff already shows (which files changed, how many lines). Write what the diff
doesn't show — intent, alternatives you rejected, and verification results.

## Commit messages

First line: `type(scope): summary of the change` (aim for 50 characters, present tense, states what
changes). Body (only if needed): why this change. The diff already carries the "what," so write only
the "why."

> Good: `fix(search): resolve silent no-op from OR relaxation on 0-hit results`
> Bad: `修正` (fix) / `いろいろ更新` (various updates) / `検索機能について、0件になる場合があったため、その対応を実施` (rambling, no clear scope)

## Forbidden across all three settings

Never open with a formulaic apology or thanks. Never soften an assertion with "I think…" or
"maybe" (if genuinely uncertain, prefix it "Unverified:" to keep it distinct from a stated fact).
Never say the same thing twice in different words. Never use emoji or "!" in a deliverable.
