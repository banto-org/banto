# model-lab ステージ詳細

SKILL.md の補足。骨格は dev-loop（実装 → 検証 → 修正 → 反復）で、検証段を eval + ablation + 統計 + 再現性に拡張し、設計段に手法/アーキ選定と計算計画、出力段に論文 + 公開を足す。

## Stage 1: Frame
研究問い + 仮説 + 証明する主張 + 成功基準（ベンチ / 目標値 / コスト / レイテンシ）+ 計算予算上限。成功基準が Stage 6 の eval 指標に落ちる。goal fork（A/B で受け入れ基準が変わる）は事前確認。

## Stage 2: Survey
`search`（内部・過去実験）→ 確信ヒット無 / 古いなら `research`（SOTA / baseline / related work）→ 論文横断探索（Connected Papers → Semantic Scholar API → Papers with Code Methods）。一見無関係な論文からの転用候補も列挙。詳細は publishing.md。

## Stage 3: Design
手法（pretrain / FT / PEFT / 蒸留 / pruning / アーキ）+ モデル + データ + baseline + ablation 計画 + eval プロトコル + seed(≥5) + 計算計画。human gate（手法 / アーキ / コストの根拠を 1 度提示）。ablation は OFAT を基本に、交互作用が疑わしい要素は 2 要素同時で確認（事前にリスト確定）。

## Stage 4: Implement
学習コード（PyTorch + Accelerate + FSDP2）+ Hydra config + DVC データ版 + ClearML 追跡 + pixi/Docker 環境。seed 固定 + `torch.use_deterministic_algorithms(True)`。repro-gate が欠落を検出。

## Stage 5: Run
Mac(MLX/MPS) でロジック検証 → `accelerate launch --cpu` で動作確認 → Nvidia 小規模 → SkyPilot で Spot クラウド/クラスタ。有料計算前に compute-cost-gate。ClearML が run を記録。

## Stage 6: Verify
lm-eval-harness + lighteval でベンチ + ablation + baseline 比較。統計: ≥3 seed（推奨 5-10）+ BCa bootstrap 95%CI + permutation test。CI が 0 跨ぎ = 有意差なし。汚染対策（Min-K% / ConStat、contamination-resistant bench）。圧縮は多軸。詳細は eval-rigor.md。

## Stage 7: Analyze
結果の表 / 図を実行出力から生成（plot.py / make figures、手打ち禁止）。主張ごとに claim 台帳へ verified 記録（run_id + config + seed + CI + baseline）。

## Stage 8: Paper & Publish
LaTeX 草稿（学会テンプレ）+ related work + 結果節を実験出力に結線 + 再現性 appendix。claim-link で unbacked ゼロを確認。公開: arxiv + HF Hub + GitHub + Zenodo DOI（全公開は人間ゲート）。詳細は publishing.md。

## Stage 9: Iterate + 決定記録
red → 該当段へ戻す。成功基準到達 or plateau N 周で収束。手法 / モデル / 最終結果を decisions へ（provisional → 再現で accepted）。

## エスカレーション条件（番頭は例外だけ owner に上げる）
- 手法 / アーキ選定が goal fork / 有料計算が予算超過 / eval red のまま「完了」 / 裏づけ無き主張 / plateau 未達 / 不可逆・外向き操作（公開・push・PR・main・削除）。いずれも止めて owner へ。

> Phase 5（T5.2）で各段の成果物・委譲先をさらに詳細化する。
