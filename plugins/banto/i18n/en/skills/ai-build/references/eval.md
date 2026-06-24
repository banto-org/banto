# eval reference (LLM-as-judge)

An aid to Stage 6. The layer that turns "it ran" into "it was measured." The minimal implementation is the bundled `scripts/ai-eval-judge.sh` (LLM-as-judge via `claude -p`). Full-blown platforms (promptfoo / RAGAS) are **optional and guidance-only** — not bundled (the policy is to avoid adding dependencies).

## What to measure (scoring axes)

Translate your success criteria (Stage 1) into scoring axes. Representative examples:

| Axis | Meaning | Tasks it helps with |
|---|---|---|
| **accuracy / correctness** | Does it match expectations? | Classification / extraction / QA |
| **faithfulness (grounding fidelity)** | Does it stay faithful to the given context without fabricating? | RAG |
| **relevance** | Are the retrieval / answers on point for the question? | RAG / retrieval |
| **format / schema** | Does the structured output conform to the schema? | JSON / tool use |
| **safety / refusal** | Does it refuse what should be refused without over-refusing? | Safety requirements |
| **tone / style** | Are the tone and style as required? | Text generation |

Reducing each axis to a single number (e.g. 0–100) makes the threshold check deterministic. For multiple axes, take a weighted average, or AND together independent per-axis thresholds.

## Case set format (JSONL)

JSONL with one case per line (the input to `scripts/ai-eval-judge.sh`):

```jsonl
{"input": "問い or 入力", "expected": "期待 or 採点基準", "output": "被験システムの出力"}
{"input": "...", "expected": "...", "output": "..."}
```

- If you include `output`, the judge scores it. When `output` is omitted, the judge scores from `input` alone (criteria-based absolute scoring).
- `expected` can be either the "correct answer" or the "scoring criteria (rubric)" (it is passed into the judge prompt).
- **Don't mix in production client data / PII / internal names** (egress-guard blocks leaks to client paths). Use synthetic or anonymized cases.
- Scale: start with 10–30 representative cases (weighted toward boundary and failure-prone examples). Grow the set for regression.

## Running the minimal implementation

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-eval-judge.sh" cases.jsonl
# 各ケースを claude -p で 0–100 採点 → 平均 + PASS/FAIL を出力
# 閾値: BANTO_EVAL_PASS（既定 70）
# judge モデル: BANTO_EVAL_MODEL（既定 claude CLI の既定モデル）
# claude / jq 不在 → no-op で exit 0（fail-open。eval 不能で実装を止めない）
```

If you leave the verdict as a single line (`green` / `red:<metric>`), you can reuse dev-loop's `verify-claim-guard` (blocks a "done" claim while eval is still red) and its escalation skeleton as-is.

### LLM-as-judge caveats

- **Look at the judge and the system under test on separate axes**: the judge is an LLM too, so it carries bias. Watch for position bias (favoring whichever appears first) and verbosity bias (favoring the longer answer).
- **State the rubric explicitly**: writing "what each score means" into the judge prompt improves reproducibility.
- **Avoid self-scoring**: where possible, score with a different model / configuration than the system under test.
- Judge scores are **strong for relative comparison** (which is better, version A vs version B). Absolute scores wobble depending on the rubric.

## External eval platforms (optional, guidance-only — not bundled)

When the minimal implementation no longer suffices (many axes, large case sets, permanent CI), move to an external tool:

| Tool | Good for | Notes |
|---|---|---|
| **promptfoo** | A/B comparison of prompts / models, defining cases in YAML, CI integration | `npx promptfoo eval`. Asserts can mix LLM-rubric / regex / JS |
| **RAGAS** | RAG-specific metrics (faithfulness / answer relevance / context precision and recall) | Python library. Quantitative evaluation of RAG pipelines |
| **DeepEval** | pytest-style LLM tests, a rich set of metrics | Python. Easy to embed as regression tests |

Banto does not bundle these; it only points to them (the minimal-dependency policy). Even if you adopt one, the thinking about case sets (JSONL / CSV) and scoring axes is shared with this file. Fetch the latest usage via the `research` skill.
