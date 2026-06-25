# eval / 統計的厳密性リファレンス

出典: `{base}/docs/research/2026-06-24_model-eval-benchmarking-rigor.md`。「動いた」を「測れた」に変える層。

## eval harness
- 主軸: **lm-evaluation-harness**（200+ タスク・YAML 1 枚でカスタムベンチ追加）+ **lighteval**（Open LLM Leaderboard 準拠）。
- HELM は 2026-06 保守モード入りで新規採用を避ける。OpenCompass は多言語 / 中国語向け。

## ablation 設計
OFAT を基本に、交互作用が疑わしい要素は 2 要素同時 ablation で確認。ablation リストは事前確定し、統計的有意性検定を ablation 結果にも適用する。

## 統計的厳密性（最低ライン）
- 最低 3 seed（推奨 5-10）+ **BCa bootstrap 95%CI**（1,000 回以上）+ **sign-flip permutation test** の paired プロトコル。
- CI が 0 を含む場合は「有意差なし」と明記。eval-stats.sh がこの集計を担う。

## 汚染対策（contamination）
Min-K% Prob / ConStat でチェックし `decontamination_report` に記録。新規ベンチは LiveCodeBench / LiveBench など contamination-resistant を優先。公開ベンチ（GSM8K / MMLU 等）は汚染前提で複数ベンチ横断。

## 圧縮後の多軸評価
perplexity 単体は不十分。推論（ARC / HellaSwag / MMLU）・多言語・instruction-following（IFEval）・推論レイテンシの全軸を報告する。圧縮順は Pruning → Distillation → Quantization が最良。

> Phase 5（T5.4）で詳細化する。
