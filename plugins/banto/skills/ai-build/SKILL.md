---
name: ai-build
description: |
  Build flow for AI features (LLM / RAG / agent / prompting). The AI-specialized sibling of dev-loop. Runs end to end: requirements → internal search → latest research (freshness matters) → design (prompt / RAG / fine-tune choice + model choice + eval plan) → implement → eval (LLM-as-judge) → iterate + decision logging.
  Triggers: "build an AI feature", "embed an LLM", "build a RAG", "build an agent", "design a prompt", "run evals", "LLM-as-judge", "should I fine-tune", "which model should I use", "set up evals", "prompt engineering". Also invocable via /ai-build.
  Don't use for: ordinary implementation with no AI element (dev-loop / autopilot) / design only (spec) / ideology only (concept) / searching an existing store only (search) / pure external research only (research) / looking up Claude API ids, pricing, or params (read the claude-api skill directly).
allowed-tools: Read Grep Glob Edit Write Bash Agent Skill
user-invocable: true
argument-hint: "[the AI feature / problem you want to build] (when omitted, intent is inferred from the conversation)"
model: opus
compatibility: Claude Code (requires bash, git, jq; claude CLI for eval)
---

# ai-build — AI feature build flow (frame → search → research → design → implement → eval → iterate)

> **store-first**: Read/Write of decisions, eval results, and the like under `{base}/...` happens beneath the "ai-context base: &lt;absolute path&gt;" injected by the SessionStart/PreCompact hook. If unsure, run `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`.

An AI feature isn't done at "it ran." Prompts, RAG, and model choice are freshness-sensitive (models / APIs change in a matter of weeks), and you can't know the quality without measuring it via eval. This skill swaps dev-loop's skeleton (implement → verify → fix → iterate) for an AI build, **replacing the verify stage with eval (LLM-as-judge)** and adding **method selection (prompt / RAG / fine-tune) and model selection** to the design stage.

The machinery is delegated to existing parts: internal search to `search`, latest research to `research`, and Claude's ids / pricing / params to the `claude-api` skill. This skill doesn't reimplement them — it **wires them together**.

## Firing conditions (when all hold)

- A request to build a feature involving LLM / RAG / agent / prompting / eval
- You want to measure quality, not just "make it run" (eval is needed)
- It's not design-only or ideology-only (those are spec / concept respectively)

**Does not fire**: ordinary implementation with no AI element (dev-loop / autopilot) / design only (spec) / ideology only (concept) / store search only (search) / external research only (research) / Claude API reference lookup only (read the claude-api skill directly).

## Autonomy (L3 · Autopilot)

odd.yaml = **L3 (Autopilot = keep running, request the owner only on exceptions)**. The method selection in the design stage (prompt / RAG / fine-tune) and the model selection can be a **goal fork** (the acceptance criteria, the order-of-magnitude cost, or the compliance meaning may change), so in Stage 4 you **present the selection rationale once and confirm** (human gate). The eval green/red decision runs deterministically against a threshold. push / PR / main / external posting are human gates (existing safety).

## Stages

Detailed steps are in [`references/stages.md`](references/stages.md).

### Stage 1: Frame (requirements · success criteria)
- What to build / who uses it / which input → which output.
- **Decide the success criteria in measurable form first** (accuracy, acceptable latency, cost ceiling, refusal rate, etc.). These become the eval metrics for the later stages. Don't start implementing while they're still vague.

### Stage 2: search (internal · evidence-first)
- First check the local store with the `search` skill (past decisions / existing research / similar implementations). Lookup order 1 of the `evidence-first` rule. If there's a confident hit, skip re-research and reuse it.

### Stage 3: research (latest — freshness-critical)
- Models / APIs / methods go stale fast. If Stage 2 had no confident hit, or it's older than 14 days → go fetch the latest with the `research` skill (research itself has search as its Step 0, so it's a double gate).
- **For Claude's ids / pricing / context window / params / caching / tool use, read the `claude-api` skill** (don't answer from memory; don't keep a duplicate copy alongside research).

### Stage 4: Design (method selection + model selection + eval plan)
- **Method selection**: prompt (few-shot / CoT / structured output), RAG (retrieval + context injection), or fine-tune. The decision table is in [`references/model-selection.md`](references/model-selection.md).
- **Model selection**: choose by use case, cost, and latency. Claude's ids / pricing are delegated to the `claude-api` skill (don't bake ids into this skill).
- **eval plan**: turn Stage 1's success criteria into a test-case set (input + expected) and scoring axes. Details in [`references/eval.md`](references/eval.md).
- **Present the method / model selection rationale once and confirm** (the L3 human gate). After confirmation, run autonomously until an exception.

### Stage 5: Implement
- Implement per the design (Edit / Write). Version-control the prompts and record the reason for each change.
- After each edit, PostToolUse's existing tests run (sharing the same guardrails as dev-loop).

### Stage 6: EVAL (LLM-as-judge)
- Run LLM-as-judge against the case set: `sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-eval-judge.sh" <cases.jsonl>` (scores via `claude -p`; absence of claude/jq is fail-open).
- green if the aggregate meets the success criteria, red if not. Record the metric on one line (`green` / `red:<metric>`), reusing dev-loop's verify-claim / escalation skeleton.
- External eval platforms like promptfoo / RAGAS are **optional** (not bundled; pointers only — [`references/eval.md`](references/eval.md)).

### Stage 7: iterate + decision logging
- red → adjust the prompt / retrieval / model and go back to Stage 6. Converge on either N rounds with no improvement (plateau) or reaching the success criteria.
- Record the adopted method / model / eval results under `{base}/decisions/` (`ai-context` skill). Start with `status: provisional`, and once the eval backs it up, promote to `status: accepted`.

## Minimal eval implementation

`scripts/ai-eval-judge.sh` — a minimal LLM-as-judge that scores the case set (JSONL: `{"input","expected"?,"output"?}`, one case per line) 0–100 via `claude -p`. If `claude` / `jq` are absent, it's a no-op and exits 0 (fail-open). The threshold is `BANTO_EVAL_PASS` (default 70). Details in [`references/eval.md`](references/eval.md).

## Guardrails (deterministic · shared existing hooks)

| Guard | hook | Effect |
|---|---|---|
| churn stop | TF counter (`auto-test.sh`) + loop protocol | Stop the loop on repeated failures → go to root cause (forced blocking by `odd-gate.sh` is opt-in) |
| false-green prevention | `verify-claim-guard.sh` (Stop) | Blocks a "done" claim while eval is still red |
| egress | `egress-guard.sh` | Blocks internal names / PII leaking to a client path (don't mix production data into eval cases) |

Irreversible ops (push / PR / main / deletion / external posting) are human gates per the `safety` rule.

## How to use (intent detection — no need to memorize commands)

- `/ai-build` (no args): infer intent from the conversation (if it's an AI-feature request, go to Stage 1)
- `/ai-build <feature>`: drive that feature from Stage 1

## Related

- Internal search: `search` / latest research: `research` / Claude ids · pricing · params: `claude-api` skill / writing up a spec: `spec` / ideology: `concept` / general-purpose autopilot loop: `dev-loop` (this skill is its AI-specialized sibling) / decision logging: `ai-context`.
