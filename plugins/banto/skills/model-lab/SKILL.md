---
name: model-lab
description: |
  Research flow for creating and training models. The research-layer sibling of dev-loop / ai-build. Drives pretraining (from scratch) / full fine-tune / PEFT-LoRA / knowledge distillation / pruning / architecture search through a verification-centric autopilot, all the way to publishing the paper (arxiv / LaTeX) + Hugging Face + GitHub. Frame → Survey (internal search + latest research + cross-paper exploration) → Design (method/model/ablation/compute plan) → Implement → Run (Mac→Nvidia→cloud) → Verify (eval/ablation/stats) → Analyze → Paper&Publish → Iterate + decision logging.
  Triggers: "train a model", "build a model", "pretrain", "fine-tune this", "distill", "pruning", "search the architecture", "run ablations", "write the paper", "evaluate on benchmarks", "publish to HF", "distill", "run ablations", "write the paper", "publish to HF". Also invocable via /model-lab.
  Don't use for: app-layer AI features that only use an existing model (ai-build) / ordinary implementation with no AI element (dev-loop / autopilot) / design only (spec) / ideology only (concept) / store search only (search) / external research only (research) / looking up Claude API ids or pricing (claude-api skill).
allowed-tools: Read Grep Glob Edit Write Bash Agent Skill
user-invocable: true
argument-hint: "[the model / research topic you want to build] (when omitted, intent is inferred from the conversation)"
model: opus
compatibility: Claude Code (requires bash, git, jq; the PyTorch training stack / ClearML / lm-eval-harness must be provided on your environment)
---

# model-lab — model research flow (frame → survey → design → implement → run → verify → analyze → paper → iterate)

> **store-first**: Read/Write of decisions, the experiment ledger, eval results, and the like under `{base}/...` happens beneath the "ai-context base: &lt;absolute path&gt;" injected by the SessionStart/PreCompact hook. If unsure, run `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`.

Model research isn't done at "it ran." Quality is measured with eval, ablations, and statistics, and claims are backed by reproducible experiments. This skill extends dev-loop's skeleton (implement → verify → fix → iterate) for research: the **verify stage becomes eval + ablation + statistics + reproducibility**, the design stage gains **method/architecture selection and a compute plan**, and the output stage adds **paper + publishing**.

The machinery is delegated to existing, proven tools (no reimplementation): internal search to `search`, latest research to `research`, and Claude's ids / pricing to the `claude-api` skill. Training is Unsloth/Axolotl/TRL/nanotron/Megatron-LM, tracking is ClearML, config is Hydra, data versioning is DVC, eval is lm-evaluation-harness/lighteval, portability is Accelerate/SkyPilot, and the environment is pixi/Docker. What this skill bundles is only a **thin verification spine** (deterministic gates for reproducibility, evidence-backing, and cost) and **orchestration**.

## Firing conditions (when all hold)

- A request to create or train the model itself (pretraining / fine-tune / PEFT / distillation / pruning / architecture search)
- You want to measure quality with eval, ablations, and statistics — not just "train it" — and guarantee reproducibility
- It's not an app feature that uses an existing model (that's ai-build) / it's not design-only or ideology-only (spec / concept)

## Autonomy (L3 · Autopilot + strong human gates)

odd.yaml = **L3 (Autopilot = keep running, request the owner only on exceptions)**. The cheap inner loop (local Mac verification, eval of existing results, iteration) runs autonomously. It always stops at these **human gates**:

- **Launching paid compute** (cloud / cluster, Spot included) — every paid launch is stopped by `compute-cost-gate` → owner checks it against the Frame cost ceiling
- **Publishing** (arxiv submission / HF push / GitHub push / PR / main) — existing safety + this skill's gates
- **A method / architecture selection goal fork** (the acceptance criteria, order-of-magnitude cost, or novelty changes) — present once in Design and confirm

The eval green/red decision and the reproducibility check run deterministically against a threshold. A "done / paper-ready" claim with no backing experiment is blocked at Stop by `model-claim-guard`.

## Stages

Detailed steps are in [`references/stages.md`](references/stages.md). The quick reference for the settled stack is in [`references/stack.md`](references/stack.md).

### Stage 1: Frame (research question · success criteria · budget)
- Decide up front: the research question + hypothesis + **the claim you want to prove** + success criteria (which benchmark, what score, acceptable cost, latency) + **the compute budget ceiling**. Don't start training while these are still vague. The success criteria become the eval metrics for the later stages.

### Stage 2: Survey (internal search → latest research → cross-paper exploration)
- `search` skill for the internal store (past experiments / decisions) → if there's no confident hit or it's stale, the `research` skill for the latest (SOTA / baseline / related work).
- **Cross-paper technique reuse**: with Connected Papers → Semantic Scholar API → Papers with Code "Methods", enumerate reuse candidates from related — and seemingly unrelated — papers. Details in [`references/publishing.md`](references/publishing.md).

### Stage 3: Design (method / model / ablation / compute plan)
- **Method selection**: pretrain / full FT / PEFT-LoRA / distillation / pruning / architecture search (combinable).
- **baseline + ablation plan**: fix up front which factor to drop one at a time to measure its contribution ([`references/eval-rigor.md`](references/eval-rigor.md)).
- **eval protocol + seed (≥5) + compute plan** (Mac→Nvidia→cloud, [`references/compute.md`](references/compute.md)).
- **human gate**: present the rationale for method / architecture / cost once and confirm (the L3 goal fork).

### Stage 4: Implement (training code + reproducibility)
- Training code (PyTorch + Accelerate + FSDP2) + config (Hydra) + data versioning (DVC) + tracking (ClearML) + environment (pixi + Docker).
- **Reproducibility from the start**: fixed seed + determinism flags. `repro-gate` detects a missing fixed seed / determinism flags and missing std / CI in result documents (the config seed key and DVC registration are discipline only — no automated check) ([`references/reproducibility.md`](references/reproducibility.md)).

### Stage 5: Run (Mac → Nvidia → cloud)
- Verify the logic on Mac (MLX/MPS) → small-scale Nvidia → Spot cloud / cluster via SkyPilot.
- **Before launching paid compute, `compute-cost-gate`** (every paid launch stops → owner confirms the budget → authorize with `BANTO_ALLOW_COMPUTE=1`). ClearML records the run.

### Stage 6: Verify (eval + ablation + statistics)
- Benchmark + ablation + baseline comparison with lm-evaluation-harness + lighteval.
- **Statistical rigor**: ≥3 seeds (5-10 recommended) + BCa bootstrap 95% CI + permutation test. State explicitly that a CI straddling 0 = no significant difference. Contamination defenses (Min-K%/ConStat, contamination-resistant benchmarks).
- Compression (distillation / pruning) is **multi-axis** (reasoning / multilingual / IFEval / latency). A "no degradation" claim based on perplexity alone is forbidden.
- Aggregate with `sh "$CLAUDE_PLUGIN_ROOT/scripts/eval-stats.sh" <results.jsonl>` (mean±std / 95% CI / p-value / green|red).

### Stage 7: Analyze (generate from execution output)
- **Generate** the result tables / figures **from execution output** (`plot.py` / `make figures`. No hand-typing).
- For each claim, record `verified` (run_id + config + seed + CI) into the claim ledger (`{base}/experiments/<project>/ledger.jsonl`). To arm the ledger gate (model-claim-guard check C), set `export BANTO_LEDGER={base}/experiments/<project>/ledger.jsonl` (unset, check C is silently a no-op — the eval-red check works independently).

### Stage 8: Paper & Publish (human gate)
- LaTeX draft (conference template) + related work (from research) + results section wired to the experiment output + reproducibility appendix.
- Use `sh "$CLAUDE_PLUGIN_ROOT/scripts/claim-link.sh" <ledger> <paper.tex>` to confirm zero unbacked claims.
- Publish: arxiv + HF Hub (model card / eval_results) + GitHub (Papers with Code) + Zenodo DOI. **Every publish is a human gate** ([`references/publishing.md`](references/publishing.md)).

### Stage 9: Iterate + decision logging
- red → go back to the relevant stage (in prompt-free research that's design / implement / data). Converge on reaching the success criteria or N rounds with no improvement (plateau).
- Record the adopted method / model / final eval results under `{base}/decisions/` (`ai-context` skill). Start with `status: provisional`, and once reproduced, promote to `accepted`.

## Verification spine (deterministic · what sets this skill apart)

| Guard | hook | Effect |
|---|---|---|
| unbacked claim | `model-claim-guard.sh` (Stop) | Blocks a "done / paper-ready" with no verified entry in the claim ledger (the research version of verify-claim-guard) |
| missing reproducibility | `repro-gate.sh` (PreToolUse) | Detects a missing fixed seed / determinism flags / std·CI in results (escape: `BANTO_ALLOW_UNREPRO=1`) |
| compute cost | `compute-cost-gate.sh` (PreToolUse) | Stops every paid-compute launch (cloud / cluster, Spot included) → owner confirms the budget, then authorize with `BANTO_ALLOW_COMPUTE=1` (local runs are not gated) |
| egress | `egress-guard.sh` (existing) | Blocks client production data / PII leaking into eval / training data |
| irreversible ops | safety rule (existing) | push / PR / main / deletion / external posting are human gates |

## How to use (intent detection — no need to memorize commands)

- `/model-lab` (no args): infer intent from the conversation (if it's a model-training request, go to Stage 1)
- `/model-lab <research topic>`: drive that topic from Stage 1

## Related

- Internal search: `search` / latest research: `research` / Claude ids · pricing: `claude-api` skill / writing up a spec: `spec` / ideology: `concept` / general-purpose autopilot: `dev-loop` (this skill is its research-specialized sibling) / app-layer AI features: `ai-build` / decision logging: `ai-context`.
