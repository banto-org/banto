# ai-build Stage details

A supplement to SKILL.md. Documents the specifics, deliverables, and delegation targets for each stage. The skeleton is the same as dev-loop (implement → verify → fix → iterate), with the verification stage being **eval** and the design stage adding **method / model selection**.

## Stage 1: Frame (requirements & success criteria)

| What to decide | Example |
|---|---|
| Input / output | Input (free text / document / image) → output (classification label / summary / structured JSON / conversation) |
| Users | End users / internal / batch |
| Success criteria (in measurable form) | accuracy ≥ X% / p95 latency ≤ Y s / cost per item ≤ Z / refusal rate ≤ W% |
| Constraints | NDA / PII (don't mix client data into eval) / offline requirement / existing stack |

The success criteria **drop straight into the eval metrics in Stage 6**. Entering implementation while they're still vague leaves no eval to build. For goal forks (where A/B changes the acceptance criteria), confirm in advance per spec-fidelity.

## Stage 2: search (internal — evidence-first)

Invoke the `search` skill to check the local store (`{base}/decisions/` + `{base}/docs/` (which also holds past research) + conversation history). This is lookup order step 1 of the evidence-first rule.

- A confident hit that answers the question → skip re-investigation and reuse it.
- A partial hit → lock in what was answered and pass only the rest to Stage 3.
- Zero confidence → go to Stage 3.

## Stage 3: research (latest — freshness-critical)

Models / APIs / eval methods go stale fast (don't answer from cutoff knowledge).

- Invoke the `research` skill to fetch the latest (research's own Step 0 is also search, so it's a double gate; to avoid a duplicate run, hand the Stage 2 search results to research).
- **For Claude ids, pricing, context windows, parameters, prompt caching, tool use, and token counting, read the `claude-api` skill.** Don't keep a second copy alongside research, and don't answer from memory.
- For high-stakes / contentious topics (where the truth swings the decision), route through research to `deep-research` (adversarial verification).

## Stage 4: Design (method selection + model selection + eval plan)

1. **Method selection**: prompt / RAG / fine-tune — pick one (combinations allowed). The decision table is in [`model-selection.md`](model-selection.md).
2. **Model selection**: choose by use case, cost, latency, and context window. Delegate ids and pricing to the `claude-api` skill (**do not bake them into this skill** — that's a source of drift).
3. **eval plan**: Stage 1 success criteria → a case set (inputs + expected) + scoring axes (accuracy / faithfulness / relevance / format, etc.). Details in [`eval.md`](eval.md).
4. **human gate**: present the rationale for the method / model selection once and confirm it (L3). Method / model can be a goal fork (the cost magnitude, acceptance criteria, or compliance meaning changes).

## Stage 5: Implement

- Implement per the design (Edit / Write).
- **Version the prompts** (keep the reason for each change, in a form that lets you trace which version got which eval score). For RAG, spell out the chunking strategy, embeddings, and retrieval top-k.
- Existing PostToolUse tests run on every edit (the same guardrail as dev-loop).

## Stage 6: EVAL (LLM-as-judge)

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-eval-judge.sh" <cases.jsonl>
# Outputs the average of 0–100 scores + PASS/FAIL (threshold BANTO_EVAL_PASS, default 70)
# No-op exit 0 (fail-open) when claude / jq is absent
```

- Aggregate meets the success criteria → green; falls short → red. Record the verdict on one line (`green` / `red:<metric>`).
- This lets you reuse dev-loop's `verify-claim-guard` (false-green block) and its escalation skeleton as-is.
- promptfoo / RAGAS are optional external frameworks (not bundled — pointers only). Details in [`eval.md`](eval.md).

## Stage 7: iterate + record the decision

- red → adjust the prompt / retrieval parameters / model and return to Stage 6.
- Convergence condition: success criteria reached, or no improvement for N rounds (plateau). If still short at plateau, escalate to the owner (don't churn).
- Record the adopted method / model / final eval result in `{base}/decisions/` (the `ai-context` skill). Start at `status: provisional`; once eval backs it up, promote to `status: accepted`.

## Escalation conditions (the bantō brings only exceptions to the owner)

- The method / model selection is a goal fork (the acceptance criteria, cost magnitude, or compliance meaning changes)
- About to say "done" while eval is still red (verify-claim-guard blocks at Stop)
- Success criteria still unmet after N rounds of no improvement (plateau)
- A need arises to pull production client data / PII into the eval cases (verify provenance)
- A request for an irreversible / outward-facing operation (push / PR / main / deletion / external posting)

In every case, **stop and escalate to the owner**. Don't wave it through on your own mid-self-drive.
