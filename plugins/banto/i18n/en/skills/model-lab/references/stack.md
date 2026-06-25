# Settled-stack quick reference (per-method tools + Mac/Nvidia boundary)

Source: `{base}/docs/research/2026-06-24_ml-training-frameworks-multibackend.md` and 4 others (2026-06-24 research). Baking in ids / pricing is forbidden (they go stale fast; get the latest with `research`).

## Method → tool

| Method | Adopted tool | Suited for |
|---|---|---|
| fine-tune (single GPU / Mac verification) | Unsloth | 2-5× faster · verification/HP search |
| fine-tune (multi-GPU production) | Axolotl | YAML-driven · production |
| RLHF / GRPO | TRL | Reference implementation (CUDA-only) |
| First step / GUI | LLaMA-Factory | Entry point for exploration |
| Pretraining (mid-scale) | nanotron | HF family |
| Pretraining (large-scale) | Megatron-LM | CUDA-only · Muon optimizer as an option |
| Compression | Prune → Distill → Quantize order | SparseGPT + AWQ. Measure degradation with multi-axis eval |
| Foundation | PyTorch + Accelerate + FSDP2 | Same code across all scales |

JAX is limited to large-scale TPU research. Otherwise PyTorch is the 2026 standard.

## Mac / Nvidia boundary (important)

- **Mac (MLX / MPS) = verification layer**: up to small-scale verification of LoRA / QLoRA, HP search, and debugging. The unified memory lets you load larger models.
- **Production training is Nvidia (CUDA)**: FlashAttention, bitsandbytes, RLHF/GRPO, and multi-node distribution are not supported on MPS. eGPU support was dropped by macOS in 2019.
- The two-step idiom: logic / small-scale verification on Mac → small-scale Nvidia → cloud / cluster production.

> To be detailed in Phase 5 (T5.1).
