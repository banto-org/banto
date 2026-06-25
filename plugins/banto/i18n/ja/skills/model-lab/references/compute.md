# 計算 / 移植リファレンス（ローカル → クラスタ → クラウド）

出典: `{base}/docs/research/2026-06-24_compute-portability-local-cluster-cloud.md`。「ローカルで検証 → 同じコードでクラスタ / クラウドへ」。

## 抽象化レイヤ
- **Accelerate**（最小変更・全スケール）+ **PyTorch FSDP2**（7B-70B 本番）の二択に集約。同一コードでシングル GPU → マルチノード。
- DeepSpeed は MoE / CPU オフロードが要るときのみ。Megatron-LM は 70B+ フロンティア専用。

## 実行管理
- クラスタ / クラウド横断は **SkyPilot v0.12**（Slurm 統合・20+ クラウド・Spot 自動回復）。
- Spot / preemptible で 60-90% コスト減（SkyPilot が中断回復を自動処理）。compute-cost-gate が予算超過を停止。

## Mac の位置づけ
MPS / MLX は推論・デバッグ・小規模検証専用。CUDA カーネル（FlashAttention / bitsandbytes）は MPS 非対応で本番学習は Nvidia 一択。eGPU は macOS 廃止済み。

## 環境再現
pixi + Docker が最堅牢（pixi が CUDA runtime / cuDNN を解決、`pixi.lock` で固定）。uv は純 Python ツールの補助。同一 Docker イメージ + `pixi.lock` でローカル / クラスタ / クラウドを揃える。

## 推奨フロー
Mac でロジック検証 → `accelerate launch --cpu` で動作確認 → Nvidia 小規模（Accelerate + FSDP2）→ SkyPilot YAML で Spot クラウドへ一発移植。

> Phase 5（T5.5）で詳細化する。
