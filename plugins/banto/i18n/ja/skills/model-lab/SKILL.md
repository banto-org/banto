---
name: model-lab
description: |
  モデルを作成・学習する研究フロー。dev-loop / ai-build の研究層の兄弟。事前学習(from scratch) / フル fine-tune / PEFT・LoRA / 知識蒸留 / pruning / アーキ探索を、検証中心で自走させ、論文(arxiv・LaTeX) + Hugging Face + GitHub の公開まで一貫させる。Frame → Survey（内部検索 + 最新調査 + 論文横断探索）→ Design（手法/モデル/ablation/計算計画）→ Implement → Run（Mac→Nvidia→cloud）→ Verify（eval/ablation/統計）→ Analyze → Paper&Publish → Iterate + 決定記録。
  トリガー: 「モデルを学習」「モデルを作る」「事前学習」「fine-tune して」「蒸留」「pruning」「アーキを探索」「ablation を回す」「論文を書く」「ベンチで評価」「HF に公開」「train a model」「pretrain」「distill」「run ablations」「write the paper」「publish to HF」。/model-lab でも起動可。
  使わない場面: 既存モデルを使うだけのアプリ層 AI 機能（ai-build）／AI 要素のない通常実装（dev-loop / 自走）／設計だけ（spec）／思想だけ（concept）／ストア検索のみ（search）／外部調査のみ（research）／Claude API の id・価格の参照（claude-api skill）。
allowed-tools: Read Grep Glob Edit Write Bash Agent Skill
user-invocable: true
argument-hint: "[作りたいモデル / 研究テーマ]（省略時は会話から意図を自動判定）"
model: opus
compatibility: Claude Code (requires bash, git, jq; PyTorch 系学習スタック・ClearML・lm-eval-harness は利用環境側に用意)
---

# model-lab — モデル研究フロー（frame → survey → design → implement → run → verify → analyze → paper → iterate）

> **保存ベース（store-first）**: 決定・実験台帳・eval 結果は `{base}/...` 配下。`{base}` は SessionStart/PreCompact hook が注入する ai-context ベースの絶対パス（不明なら `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`）。

モデル研究は「動いた」では終わらない。品質は eval・ablation・統計で測り、主張は再現可能な実験で裏づける。本 skill は dev-loop の骨格（実装 → 検証 → 修正 → 反復）を研究向けに拡張し、**検証段を eval + ablation + 統計 + 再現性**に、設計段に**手法/アーキ選定と計算計画**を、出力段に**論文 + 公開**を足す。

機構は既存・実績ツールへ委譲する（再実装しない）。内部検索は `search`、最新調査は `research`、Claude の id・価格は `claude-api` skill。学習は Unsloth/Axolotl/TRL/nanotron/Megatron-LM、追跡は ClearML、設定は Hydra、データ版は DVC、eval は lm-evaluation-harness/lighteval、移植は Accelerate/SkyPilot、環境は pixi/Docker。本 skill が同梱するのは**薄い検証スパイン**（再現性・裏づけ・コストの deterministic ゲート）と**オーケストレーション**のみ。

## 発火条件（すべて満たすとき）

- モデルそのものを作成・学習する依頼（事前学習 / fine-tune / PEFT / 蒸留 / pruning / アーキ探索）
- 「学習する」だけでなく eval・ablation・統計で品質を測り、再現性を担保したい
- 既存モデルを使うアプリ機能ではない（それは ai-build）／設計だけ・思想だけではない（spec / concept）

## 自律度（L3・Autopilot + 強い人間ゲート）

odd.yaml = **L3（Autopilot＝継続実行＋例外時のみ owner 要求）**。安価な内ループ（Mac ローカル検証・既存結果の eval・反復）は自走する。次は**人間ゲート**で必ず止める:

- **有料計算の起動**（クラウド / クラスタ）— Frame の cost ceiling 超過は `compute-cost-gate` が停止 → owner
- **公開**（arxiv 投稿 / HF push / GitHub push / PR / main）— 既存 safety + 本 skill のゲート
- **手法 / アーキテクチャ選定の goal fork**（受け入れ基準・コスト桁・新規性が変わる）— Design で 1 度提示して確認

eval の green/red と再現性チェックは閾値で deterministic に回す。裏づけ実験なき「完了 / 論文化」主張は `model-claim-guard` が Stop でブロックする。

## ステージ

詳細手順は [`references/stages.md`](references/stages.md)。確定スタックの早見は [`references/stack.md`](references/stack.md)。

### Stage 1: Frame（研究問い・成功基準・予算）
- 研究問い + 仮説 + **証明したい主張** + 成功基準（どのベンチで何点・許容コスト・レイテンシ）+ **計算予算上限**を先に決める。曖昧なまま学習に入らない。成功基準が後段 eval の指標になる。

### Stage 2: Survey（内部検索 → 最新調査 → 論文横断探索）
- `search` skill で内部（過去実験・decisions）→ 確信ヒットが無い / 古いなら `research` skill で最新（SOTA / baseline / related work）。
- **論文横断の技術流用**: Connected Papers → Semantic Scholar API → Papers with Code「Methods」で、関連 + 一見無関係な論文からの転用候補を列挙する。詳細は [`references/publishing.md`](references/publishing.md)。

### Stage 3: Design（手法 / モデル / ablation / 計算計画）
- **手法選定**: pretrain / フル FT / PEFT・LoRA / 蒸留 / pruning / アーキ探索（併用可）。
- **baseline + ablation 計画**: どの要素を 1 つずつ落として寄与を測るか事前確定（[`references/eval-rigor.md`](references/eval-rigor.md)）。
- **eval プロトコル + seed(≥5) + 計算計画**（Mac→Nvidia→cloud、[`references/compute.md`](references/compute.md)）。
- **human gate**: 手法 / アーキ / コストの根拠を 1 度提示して確認（L3 の goal fork）。

### Stage 4: Implement（学習コード + 再現性）
- 学習コード（PyTorch + Accelerate + FSDP2）+ config（Hydra）+ データ版（DVC）+ 追跡（ClearML）+ 環境（pixi + Docker）。
- **再現性を最初から**: seed 固定 + 決定性フラグ。`repro-gate` が seed 固定・決定性フラグの欠落と、結果ドキュメントの std / CI 欠落を検出する（config の seed キー・DVC 登録は規律のみ・自動検査は未実装）（[`references/reproducibility.md`](references/reproducibility.md)）。

### Stage 5: Run（Mac → Nvidia → cloud）
- Mac(MLX/MPS) でロジック検証 → Nvidia 小規模 → SkyPilot で Spot クラウド / クラスタへ。
- **有料計算の起動前に `compute-cost-gate`**（有料 launch は一律停止 → owner 予算確認・認可後 `BANTO_ALLOW_COMPUTE=1`）。ClearML が run を記録。

### Stage 6: Verify（eval + ablation + 統計）
- lm-evaluation-harness + lighteval でベンチ + ablation + baseline 比較。
- **統計的厳密性**: ≥3 seed（推奨 5-10）+ BCa bootstrap 95%CI + permutation test。CI が 0 跨ぎ = 有意差なしと明記。汚染対策（Min-K%/ConStat、contamination-resistant bench）。
- 圧縮（蒸留 / pruning）は **多軸**（推論 / 多言語 / IFEval / レイテンシ）。perplexity 単体での「劣化なし」主張は禁止。
- 集計は `sh "$CLAUDE_PLUGIN_ROOT/scripts/eval-stats.sh" <results.jsonl>`（mean±std / 95%CI / p 値 / green|red）。

### Stage 7: Analyze（結果を実行出力から生成）
- 結果の表 / 図を**実行出力から生成**（`plot.py` / `make figures`。手打ち禁止）。
- 主張ごとに claim 台帳（`{base}/experiments/<project>/ledger.jsonl`）へ `verified`（run_id + config + seed + CI）を記録する。台帳ゲート（model-claim-guard の C 検査）を有効にするため `export BANTO_LEDGER={base}/experiments/<project>/ledger.jsonl` を設定する（未設定だと C 検査は黙って no-op — eval red 検査は独立に機能）。

### Stage 8: Paper & Publish（人間ゲート）
- LaTeX 草稿（学会テンプレ）+ related work（research から）+ 結果節を実験出力に結線 + 再現性 appendix。
- `sh "$CLAUDE_PLUGIN_ROOT/scripts/claim-link.sh" <ledger> <paper.tex>` で裏づけ無き主張（unbacked）がゼロか確認。
- 公開: arxiv + HF Hub(model card / eval_results) + GitHub(Papers with Code) + Zenodo DOI。**全公開は人間ゲート**（[`references/publishing.md`](references/publishing.md)）。

### Stage 9: Iterate + 決定記録
- red → 該当段（プロンプト無しの研究では design / implement / data）へ戻す。成功基準到達 or 改善なし N 周（plateau）で収束。
- 採用した手法 / モデル / 最終 eval 結果を `{base}/decisions/` に記録（`ai-context` skill）。最初は `status: provisional`、再現で `accepted` へ昇格。

## 検証スパイン（deterministic・本 skill の差別化）

| ガード | hook | 効果 |
|---|---|---|
| 裏づけなき主張 | `model-claim-guard.sh`（Stop） | claim 台帳に verified が無い「完了 / 論文化」をブロック（verify-claim-guard の研究版） |
| 再現性欠落 | `repro-gate.sh`（PreToolUse） | seed 固定・決定性フラグ / 結果の std・CI の欠落を検出（escape: `BANTO_ALLOW_UNREPRO=1`） |
| 計算コスト | `compute-cost-gate.sh`（PreToolUse） | 有料計算の launch（クラウド / クラスタ起動・Spot 含む）を一律停止 → owner が予算確認、認可後 `BANTO_ALLOW_COMPUTE=1`（ローカル実行は対象外） |
| 外部流出 | `egress-guard.sh`（既存） | eval / 学習データへの client 本番データ・PII 混入を遮断 |

不可逆操作（push / PR / main / 削除 / 外部投稿）は `safety` rule に従い人間ゲート。

## 使い方（インテント検出 — コマンド暗記は不要）

- `/model-lab`（引数なし）: 会話から意図判定（モデル学習の依頼なら Stage 1 へ）
- `/model-lab <研究テーマ>`: そのテーマを Stage 1 から進める

## 関連

- 内部検索: `search` / 最新調査: `research` / Claude id・価格: `claude-api` skill / 設計書化: `spec` / 思想: `concept` / 汎用自走: `dev-loop`（本 skill はその研究特化兄弟）/ アプリ層 AI 機能: `ai-build` / 決定記録: `ai-context`。
