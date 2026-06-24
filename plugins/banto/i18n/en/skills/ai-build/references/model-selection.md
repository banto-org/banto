# Method Selection + Model Selection Guide

Auxiliary to Stage 4. **Decide the method (prompt / RAG / fine-tune) first, then pick the model on top of that.** Claude's concrete ids, pricing, context windows, and parameters go stale fast, so this file does **not bake them in** — it delegates to the `claude-api` skill (don't answer from memory).

## Method selection (prompt / RAG / fine-tune)

The principle is "try the lightest option that gets the job done first." If prompting suffices, don't add RAG. If RAG suffices, don't fine-tune.

| Method | Fits | Doesn't fit | Cost / effort |
|---|---|---|---|
| **Prompt only** | General tasks (summarize / classify / extract / rewrite / converse). Knowledge fits inside the model or the context | Needs large private / fresh knowledge, or mass reproduction of a strict format | Minimal (instant iteration) |
| **RAG** (retrieval + context injection) | Ground answers in private documents / fresh information, cite sources, knowledge updates frequently | Want to change the reasoning style itself, or tacit knowledge retrieval can't surface | Medium (retrieval infra + chunk design) |
| **fine-tune** | Mass reproduction of a fixed format, shrinking for lower latency / cost, specialized domain vocabulary | Just want to add knowledge (→ RAG), or fluid requirements | Large (data prep + training + retraining ops) |

Rules of thumb:
- First try whether **prompting** reaches the success criteria (few-shot / CoT / structured output).
- Need **grounding** in private / fresh knowledge → **RAG**.
- Strict format reproduction, or **cost / latency** at scale is the problem and data can be prepared → **fine-tune**.
- Combining is fine (RAG + few-shot, a fine-tuned small model + RAG, etc.).

## Prompt design patterns

- **few-shot**: 2–5 input/output examples. Show the format, tone, and boundary cases.
- **chain-of-thought**: prompt for step-by-step reasoning (separate the final output from the thinking when extracting).
- **structured output**: lock to machine-readable form via JSON schema / tool use (catch parse failures with eval's format axis).
- For detailed and up-to-date features (prompt caching / tool use / extended thinking, etc.), see the `claude-api` skill.

## RAG design essentials

| Element | What to decide |
|---|---|
| Chunking | Size / overlap / boundaries (e.g. per heading) |
| Embedding | Model selection (dimensions, cost, multilingual support) |
| Retrieval | top-k, hybrid (BM25 + vector), whether reranking is needed |
| Injection | How many items fit in the context window, how to attach sources |

For RAG, measure **faithfulness (true to the grounding) / relevance (is retrieval on point)** in eval ([`eval.md`](eval.md)).

## Model selection

The axes are **quality for the use case / cost / latency / context window**. For the concrete options (ids, pricing, windows, each model's strengths), **read the `claude-api` skill** (this skill holds no ids). Only the general rules:

- Hard reasoning / agentic multi-step tasks → a higher-tier model.
- High-volume / simple / low-latency requirements → a small, fast model.
- Build the quality on a higher tier first, then **drop to a smaller model to optimize cost** as far as eval still passes (eval is the safety net).
- If the target is another provider (OpenAI / Gemini, etc.), skip claude-api and pull that provider's primary sources via research.

## Recording the decision

Record the chosen method / model and the rationale under `{base}/decisions/` (`ai-context`). Use `status: provisional` before eval, and `accepted` once eval backs it up. When you later swap the model, the past selection rationale and eval scores become the basis for comparison.
