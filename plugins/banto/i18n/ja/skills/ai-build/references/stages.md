# ai-build ステージ詳細

SKILL.md の補足。各ステージの具体・成果物・委譲先を記す。骨格は dev-loop と同じ（実装 → 検証 → 修正 → 反復）で、検証段を **eval**、設計段に **手法 / モデル選定** を足したもの。

## Stage 1: Frame（要件・成功基準）

| 決めること | 例 |
|---|---|
| 入出力 | 入力（自然文 / 文書 / 画像）→ 出力（分類ラベル / 要約 / 構造化 JSON / 会話） |
| 利用者 | エンドユーザー / 社内 / バッチ |
| 成功基準（測れる形） | 精度 ≥ X%・p95 レイテンシ ≤ Y 秒・1 件あたりコスト ≤ Z・拒否率 ≤ W% |
| 制約 | NDA / PII（client データを eval に混ぜない）・オフライン要否・既存スタック |

成功基準は **Stage 6 の eval 指標にそのまま落ちる**。曖昧なまま実装に入ると eval が組めない。ゴール分岐（A/B で受け入れ基準が変わる）は spec-fidelity に従い事前確認する。

## Stage 2: search（内部・evidence-first）

`search` skill を起動し、ローカル store（`{base}/decisions/` + `{base}/docs/`（過去リサーチ含む）+ 会話履歴）を調べる。evidence-first rule の lookup 順序 1。

- 確信ヒットがあり問いに答えられる → 再調査をスキップして再利用。
- 一部だけヒット → 答えられた範囲は確定し、残りだけ Stage 3 へ回す。
- ゼロ確信 → Stage 3 へ。

## Stage 3: research（最新 — 鮮度クリティカル）

モデル / API / eval 手法は陳腐化が速い（cutoff の知識で答えない）。

- `research` skill を起動して最新を取りに行く（research 自身も Step 0 が search なので二重ゲート。重複起動を避けたいなら Stage 2 の search 結果を research に渡す）。
- **Claude の id・価格・コンテキスト窓・パラメータ・prompt caching・tool use・token counting は `claude-api` skill を読む。** research と二重持ちせず、記憶でも答えない。
- 重大 / 論争的トピック（真偽が判断を左右する）は research 経由で `deep-research`（敵対的検証）へ。

## Stage 4: Design（手法選定 + モデル選定 + eval 計画）

1. **手法選定**: prompt / RAG / fine-tune のどれか（併用可）。判断表は [`model-selection.md`](model-selection.md)。
2. **モデル選定**: 用途・コスト・レイテンシ・コンテキスト窓で選ぶ。id・価格は `claude-api` skill に委譲（**本 skill に焼き込まない** — ドリフト源になる）。
3. **eval 計画**: Stage 1 の成功基準 → ケース集（入力 + 期待）+ 採点軸（accuracy / faithfulness / relevance / format など）。詳細は [`eval.md`](eval.md)。
4. **human gate**: 手法 / モデルの選定根拠を 1 度提示して確認する（L3）。手法 / モデルは goal fork になりうる（コスト桁・受け入れ基準・コンプラ意味が変わる）。

## Stage 5: Implement

- 設計に沿って実装（Edit / Write）。
- **プロンプトは版管理する**（変更理由を残し、どの版でどの eval スコアだったか追える形に）。RAG ならチャンク戦略・埋め込み・検索 top-k を明記。
- 編集ごとに既存 PostToolUse テストが回る（dev-loop と同じガードレール）。

## Stage 6: EVAL（LLM-as-judge）

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-eval-judge.sh" <cases.jsonl>
# 0–100 採点の平均 + PASS/FAIL（閾値 BANTO_EVAL_PASS、既定 70）を出す
# claude / jq 不在は no-op で exit 0（fail-open）
```

- 集計が成功基準を満たす → green、未達 → red。判定は 1 行（`green` / `red:<metric>`）で残す。
- これで dev-loop の `verify-claim-guard`（偽 green ブロック）とエスカレーション骨格をそのまま流用できる。
- promptfoo / RAGAS は任意の外部基盤（同梱しない・案内のみ）。詳細は [`eval.md`](eval.md)。

## Stage 7: iterate + 決定記録

- red → プロンプト / 検索パラメータ / モデルを調整して Stage 6 へ戻る。
- 収束条件: 成功基準到達 or 改善なし N 周（plateau）。plateau で未達なら owner にエスカレーション（churn しない）。
- 採用した手法 / モデル / 最終 eval 結果を `{base}/decisions/` に記録（`ai-context` skill）。最初は `status: provisional`、eval で裏が取れたら `status: accepted` へ昇格。

## エスカレーション条件（番頭は例外だけ主人に持っていく）

- 手法 / モデル選定が goal fork（受け入れ基準・コスト桁・コンプラ意味が変わる）
- eval が red のまま「完了」と言いそう（verify-claim-guard が Stop でブロック）
- 改善なし N 周（plateau）で成功基準未達
- eval ケースに本番 client データ / PII を取り込む必要が出た（出所確認）
- 不可逆 / 外向き操作（push・PR・main・削除・外部投稿）の要求

いずれも **止めて owner に上げる**。自走の中で勝手に通さない。
