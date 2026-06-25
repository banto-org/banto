# 確定スタック早見（手法別ツール + Mac/Nvidia 境界）

出典: `{base}/docs/research/2026-06-24_ml-training-frameworks-multibackend.md` ほか 4 本（2026-06-24 調査）。id・価格の焼き込みは禁止（陳腐化が速い。最新は `research` で取る）。

## 手法 → ツール

| 手法 | 採用ツール | 向き |
|---|---|---|
| fine-tune（単一 GPU / Mac 検証） | Unsloth | 2-5× 高速・検証/HP 探索 |
| fine-tune（マルチ GPU 本番） | Axolotl | YAML 駆動・本番 |
| RLHF / GRPO | TRL | 参照実装（CUDA 専用） |
| 初手 / GUI | LLaMA-Factory | 探索の入口 |
| 事前学習（中規模） | nanotron | HF 系 |
| 事前学習（大規模） | Megatron-LM | CUDA 専用・最適化器 Muon を選択肢に |
| 圧縮 | Prune → Distill → Quantize の順 | SparseGPT + AWQ。多軸評価で劣化測定 |
| 基盤 | PyTorch + Accelerate + FSDP2 | 同一コードで全スケール |

JAX は TPU 大規模研究に限定。それ以外は PyTorch が 2026 標準。

## Mac / Nvidia 境界（重要）

- **Mac(MLX / MPS) = 検証層**: LoRA / QLoRA の小規模検証・HP 探索・デバッグまで。統合メモリで大きいモデルを載せられる利点。
- **本番学習は Nvidia(CUDA)**: FlashAttention・bitsandbytes・RLHF/GRPO・マルチノード分散は MPS 非対応。eGPU は macOS が 2019 年にサポート廃止。
- 二段構え定石: Mac でロジック/小規模検証 → Nvidia 小規模 → クラウド/クラスタ本番。

> Phase 5（T5.1）で詳細化する。
