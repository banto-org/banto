# eval / statistical-rigor reference

Source: `{base}/docs/research/2026-06-24_model-eval-benchmarking-rigor.md`. The layer that turns "it ran" into "it was measured."

## eval harness
- Main axis: **lm-evaluation-harness** (200+ tasks · add a custom benchmark with one YAML) + **lighteval** (Open LLM Leaderboard compliant).
- HELM entered maintenance mode in 2026-06; avoid adopting it for new work. OpenCompass is for multilingual / Chinese.

## ablation design
OFAT by default, with factors suspected of an interaction confirmed via a two-factor simultaneous ablation. Fix the ablation list in advance, and apply statistical significance testing to the ablation results too.

## Statistical rigor (the floor)
- A paired protocol of at least 3 seeds (5-10 recommended) + **BCa bootstrap 95% CI** (1,000+ iterations) + a **sign-flip permutation test**.
- When the CI includes 0, state "no significant difference" explicitly. eval-stats.sh handles this aggregation.

## Contamination defenses
Check with Min-K% Prob / ConStat and record in `decontamination_report`. For new benchmarks, prefer contamination-resistant ones like LiveCodeBench / LiveBench. Treat public benchmarks (GSM8K / MMLU etc.) as contaminated and span multiple benchmarks.

## Multi-axis evaluation after compression
perplexity alone is insufficient. Report all axes: reasoning (ARC / HellaSwag / MMLU), multilingual, instruction-following (IFEval), and inference latency. The best compression order is Pruning → Distillation → Quantization.

> To be detailed in Phase 5 (T5.4).
