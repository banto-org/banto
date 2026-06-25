# 再現性リファレンス

出典: `{base}/docs/research/2026-06-24_experiment-tracking-reproducibility.md`。「結果を後で再現できる形」を最初から残す。repro-gate / repro-check.sh が静的に検査する。

## 再現性 4 点（repro-gate の検査対象）
1. **seed 固定**: 学習スクリプトに seed 固定 + `torch.use_deterministic_algorithms(True)` + `CUBLAS_WORKSPACE_CONFIG=:4096:8`。非決定的演算は RuntimeError で早期検出。
2. **config に seed キー**: Hydra + OmegaConf。config に seed / データ版 / 環境を明示（環境変数依存は非推奨）。
3. **データの DVC 登録**: `dvc.lock` × git commit で「コード × データ × 結果」を固定。大容量データが DVC 未登録なら警告。
4. **結果に std / CI**: 結果レポートに標準偏差・信頼区間の記載が無いまま「改善」と書かない。

## 実験追跡（ClearML）
owner 確定。自動ログ・パイプライン統合・self-host 可。run_id を claim 台帳に紐づける。代替: MLflow（完全 OSS）/ Aim（軽量ローカル）。

## 複数 seed
n ≥ 5 を config に事前記録し、平均 ± 標準偏差 + 信頼区間で報告（単一実行の数値だけで主張しない）。

## 再現性チェックリスト
NeurIPS reproducibility checklist（2019 から義務）/ MLRC（2026 NeurIPS 公式トラック）。コード + seed + 超パラメータ + データ版 + 計算資源の完全開示。

## 環境再現
pixi + Docker。`pixi.lock` が CUDA / cuDNN を含め全依存を固定。ローカル / クラスタ / クラウドで同一イメージ。

> Phase 5（T5.3）で詳細化する。
