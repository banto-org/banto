# Reproducibility reference

Source: `{base}/docs/research/2026-06-24_experiment-tracking-reproducibility.md`. Leave behind "a form you can reproduce the results from later" from the start. repro-gate / repro-check.sh check this statically.

## The 4 reproducibility points (repro-gate auto-checks 1 and 4; 2 and 3 are discipline only — automated checks are a future extension)
1. **Fixed seed**: fixed seed in the training script + `torch.use_deterministic_algorithms(True)` + `CUBLAS_WORKSPACE_CONFIG=:4096:8`. Non-deterministic ops are caught early via RuntimeError.
2. **A seed key in config**: Hydra + OmegaConf. State seed / data version / environment explicitly in config (depending on environment variables is discouraged).
3. **DVC registration of data**: `dvc.lock` × git commit fixes "code × data × results." A warning if large data is unregistered in DVC.
4. **std / CI in results**: don't write "improvement" without standard deviation / confidence interval in the result report.

## Experiment tracking (ClearML)
Owner-settled. Auto-logging, pipeline integration, self-host capable. Tie run_id to the claim ledger. Alternatives: MLflow (fully OSS) / Aim (lightweight local).

## Multiple seeds
Record n ≥ 5 in config in advance and report with mean ± standard deviation + confidence interval (don't claim on a single run's number alone).

## Reproducibility checklist
The NeurIPS reproducibility checklist (mandatory since 2019) / MLRC (2026 NeurIPS official track). Full disclosure of code + seed + hyperparameters + data version + compute resources.

## Environment reproduction
pixi + Docker. `pixi.lock` fixes all dependencies including CUDA / cuDNN. The same image across local / cluster / cloud.

> To be detailed in Phase 5 (T5.3).
