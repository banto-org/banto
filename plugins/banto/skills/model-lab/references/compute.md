# Compute / portability reference (local → cluster → cloud)

Source: `{base}/docs/research/2026-06-24_compute-portability-local-cluster-cloud.md`. "Verify locally → the same code to cluster / cloud."

## Abstraction layer
- Consolidate on two: **Accelerate** (minimal changes · all scales) + **PyTorch FSDP2** (7B-70B production). The same code goes from single GPU → multi-node.
- DeepSpeed only when MoE / CPU offload is needed. Megatron-LM is for 70B+ frontier only.

## Execution management
- For cross-cluster / cross-cloud, **SkyPilot v0.12** (Slurm integration · 20+ clouds · automatic Spot recovery).
- Spot / preemptible cuts cost 60-90% (SkyPilot handles interruption recovery automatically). compute-cost-gate stops over-budget runs.

## Mac's place
MPS / MLX are for inference, debugging, and small-scale verification only. CUDA kernels (FlashAttention / bitsandbytes) aren't supported on MPS, so production training is Nvidia-only. eGPU is already dropped from macOS.

## Environment reproduction
pixi + Docker is the most robust (pixi resolves the CUDA runtime / cuDNN, `pixi.lock` fixes it). uv is a supplement for pure-Python tooling. The same Docker image + `pixi.lock` aligns local / cluster / cloud.

## Recommended flow
Verify the logic on Mac → sanity-check with `accelerate launch --cpu` → small-scale Nvidia (Accelerate + FSDP2) → one-shot port to Spot cloud via a SkyPilot YAML.

> To be detailed in Phase 5 (T5.5).
