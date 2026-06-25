# model-lab stage details

Supplement to SKILL.md. The skeleton is dev-loop (implement → verify → fix → iterate), with the verify stage extended to eval + ablation + statistics + reproducibility, the design stage gaining method/architecture selection and a compute plan, and the output stage adding paper + publishing.

## Stage 1: Frame
Research question + hypothesis + the claim to prove + success criteria (benchmark / target value / cost / latency) + compute budget ceiling. The success criteria drop into the Stage 6 eval metrics. A goal fork (A/B changes the acceptance criteria) is confirmed in advance.

## Stage 2: Survey
`search` (internal · past experiments) → if no confident hit or stale, `research` (SOTA / baseline / related work) → cross-paper exploration (Connected Papers → Semantic Scholar API → Papers with Code Methods). Also enumerate reuse candidates from seemingly unrelated papers. Details in publishing.md.

## Stage 3: Design
Method (pretrain / FT / PEFT / distillation / pruning / architecture) + model + data + baseline + ablation plan + eval protocol + seed (≥5) + compute plan. human gate (present the rationale for method / architecture / cost once). Make ablations OFAT by default, and confirm factors with a suspected interaction two at a time (fix the list in advance).

## Stage 4: Implement
Training code (PyTorch + Accelerate + FSDP2) + Hydra config + DVC data versioning + ClearML tracking + pixi/Docker environment. Fixed seed + `torch.use_deterministic_algorithms(True)`. repro-gate detects what's missing.

## Stage 5: Run
Verify the logic on Mac (MLX/MPS) → sanity-check with `accelerate launch --cpu` → small-scale Nvidia → Spot cloud/cluster via SkyPilot. compute-cost-gate before paid compute. ClearML records the run.

## Stage 6: Verify
Benchmark + ablation + baseline comparison with lm-eval-harness + lighteval. Statistics: ≥3 seeds (5-10 recommended) + BCa bootstrap 95% CI + permutation test. A CI straddling 0 = no significant difference. Contamination defenses (Min-K% / ConStat, contamination-resistant benchmarks). Compression is multi-axis. Details in eval-rigor.md.

## Stage 7: Analyze
Generate the result tables / figures from execution output (plot.py / make figures, no hand-typing). For each claim, record a verified entry into the claim ledger (run_id + config + seed + CI + baseline).

## Stage 8: Paper & Publish
LaTeX draft (conference template) + related work + results section wired to the experiment output + reproducibility appendix. Confirm zero unbacked claims with claim-link. Publish: arxiv + HF Hub + GitHub + Zenodo DOI (every publish is a human gate). Details in publishing.md.

## Stage 9: Iterate + decision logging
red → go back to the relevant stage. Converge on reaching the success criteria or N rounds of plateau. Record the method / model / final result into decisions (provisional → accepted once reproduced).

## Escalation conditions (the bantō raises only exceptions to the owner)
- A method / architecture selection goal fork / paid compute over budget / eval still red yet "done" / an unbacked claim / plateau not reached / an irreversible or outward-facing op (publish · push · PR · main · deletion). In every case, stop and go to the owner.

> Each stage's artifacts and delegation targets to be detailed further in Phase 5 (T5.2).
