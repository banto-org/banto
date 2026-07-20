---
name: ai-build
description: |
  AI 機能（LLM / RAG / agent / プロンプト）の構築フロー。dev-loop の AI 特化の兄弟。要件定義 → 内部検索 → 最新調査（鮮度が効く）→ 設計（prompt / RAG / fine-tune 選定 + モデル選定 + eval 計画）→ 実装 → eval（LLM-as-judge）→ 反復 + 決定記録、を一貫で進める。
  トリガー: 「AI 機能を作る」「LLM を組み込む」「RAG を組みたい」「エージェントを作る」「プロンプトを設計」「eval を回したい」「LLM-as-judge」「fine-tune するか」「build a RAG」「build an agent」「set up evals」「prompt engineering」「which model should I use」。/ai-build でも起動可。
  使わない場面: AI 要素のない通常実装（dev-loop / 自走）／設計だけ（spec）／思想だけ（concept）／既存ストアの検索のみ（search）／純粋な外部調査のみ（research）／Claude API の id・価格・パラメータの参照（claude-api skill を直接読む）。
allowed-tools: Read Grep Glob Edit Write Bash Agent Skill
user-invocable: true
argument-hint: "[作りたい AI 機能 / 課題]（省略時は会話から意図を自動判定）"
model: opus
compatibility: Claude Code (requires bash, git, jq; claude CLI for eval)
---

# ai-build — AI 機能構築フロー（frame → search → research → design → implement → eval → iterate）

> **保存ベース（store-first）**: 決定・eval 結果など `{base}/...` への Read/Write は、SessionStart/PreCompact hook が注入する「ai-context ベース: &lt;絶対パス&gt;」の配下で行う。不明なら `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`。

AI 機能は「動いた」では終わらない。プロンプト・RAG・モデル選定は鮮度が効き（モデル / API は数週間で変わる）、品質は eval で測らないと分からない。本 skill は dev-loop の骨格（実装 → 検証 → 修正 → 反復）を AI 向けに差し替え、**検証段を eval（LLM-as-judge）に**、設計段に**手法選定（prompt / RAG / fine-tune）とモデル選定**を足す。

機構は既存に委譲する: 内部検索は `search`、最新調査は `research`、Claude の id・価格・パラメータは `claude-api` skill。本 skill はそれらを再実装せず**つなぐ**。

## 発火条件（すべて満たすとき）

- LLM / RAG / agent / プロンプト / eval を含む機能の構築依頼
- 「動かす」だけでなく品質を測りたい（eval が要る）
- 設計だけ・思想だけではない（それぞれ spec / concept）

**発火しない**: AI 要素のない通常実装（dev-loop / 自走）／設計のみ（spec）／思想のみ（concept）／ストア検索のみ（search）／外部調査のみ（research）／Claude API リファレンス参照のみ（claude-api skill を直接読む）。

## 自律度（L3・Autopilot）

odd.yaml = **L3（Autopilot＝継続実行＋例外時のみ owner 要求）**。設計段の手法選定（prompt / RAG / fine-tune）とモデル選定は**ゴール分岐**になりうる（受け入れ基準・コスト桁・コンプラ意味が変わる）ため、Stage 4 で**選定根拠を 1 度提示して確認**する（human gate）。eval の green/red 判定は閾値で deterministic に回す。push / PR / main / 外部投稿は人間ゲート（既存 safety）。

## ステージ

詳細手順は [`references/stages.md`](references/stages.md)。

### Stage 1: Frame（要件・成功基準）
- 何を作るか / 誰が使うか / どの入力 → どの出力。
- **成功基準を測れる形で先に決める**（精度・許容レイテンシ・コスト上限・拒否率など）。これが後段の eval 指標になる。曖昧なまま実装に入らない。

### Stage 2: search（内部・evidence-first）
- まず `search` skill でローカル store を調べる（過去の decisions / 既存リサーチ / 同種実装）。`evidence-first` rule の lookup 順序 1。確信ヒットがあれば再調査をスキップして再利用する。

### Stage 3: research（最新 — 鮮度クリティカル）
- モデル / API / 手法は陳腐化が速い。Stage 2 で確信ヒットが無い、または 14 日より古い → `research` skill で最新を取りに行く（research 自身も Step 0 が search なので二重ゲート）。
- **Claude の id・価格・コンテキスト窓・パラメータ・キャッシュ・tool use は `claude-api` skill を読む**（記憶で答えない。research と二重持ちしない）。

### Stage 4: Design（手法選定 + モデル選定 + eval 計画）
- **手法選定**: prompt（few-shot / CoT / 構造化出力）か RAG（検索 + 文脈注入）か fine-tune か。判断表は [`references/model-selection.md`](references/model-selection.md)。
- **モデル選定**: 用途・コスト・レイテンシで選ぶ。Claude の id・価格は `claude-api` skill に委譲（本 skill に id を焼き込まない）。
- **eval 計画**: Stage 1 の成功基準を、テストケース集（入力 + 期待）と採点軸へ落とす。詳細は [`references/eval.md`](references/eval.md)。
- 手法 / モデルの選定根拠を **1 度提示して確認**（L3 の human gate）。確認後は例外まで自走。

### Stage 5: Implement
- 設計に沿って実装（Edit / Write）。プロンプトは版管理し、変更理由を残す。
- 編集ごとに PostToolUse の既存テストが回る（dev-loop と同じガードレールを共有）。

### Stage 6: EVAL（LLM-as-judge）
- ケース集に対し LLM-as-judge を回す: `sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-eval-judge.sh" <cases.jsonl>`（`claude -p` で採点。claude/jq 不在は fail-open）。
- 集計が成功基準を満たせば green、未達は red。指標は 1 行（`green` / `red:<metric>`）で残し、dev-loop の verify-claim / エスカレーションの骨格を流用する。
- promptfoo / RAGAS など外部 eval 基盤は**任意**（同梱しない。案内のみ — [`references/eval.md`](references/eval.md)）。

### Stage 7: iterate + 決定記録
- red → プロンプト / 検索 / モデルを調整して Stage 6 へ戻る。改善なし N 周（plateau）or 成功基準到達で収束。
- 採用した手法 / モデル / eval 結果を `{base}/decisions/` に記録する（`ai-context` skill）。最初は `status: provisional`、eval で裏が取れたら `status: accepted` へ昇格する。

## eval 最小実装

`scripts/ai-eval-judge.sh` — ケース集（JSONL: `{"input","expected"?,"output"?}` 1 行 1 ケース）を `claude -p` で 0–100 採点する最小の LLM-as-judge。`claude` / `jq` が無ければ no-op で exit 0（fail-open）。閾値は `BANTO_EVAL_PASS`（既定 70）。詳細は [`references/eval.md`](references/eval.md)。

## ガードレール（deterministic・既存 hook 共有）

| ガード | hook | 効果 |
|---|---|---|
| churn 停止 | TF カウンタ（`auto-test.sh`）+ ループ手順 | 連続失敗で周回停止 → root cause へ（`odd-gate.sh` の強制ブロックは opt-in） |
| 偽 green 防止 | `verify-claim-guard.sh`（Stop） | eval が red のまま「完了」主張をブロック |
| 外部流出 | `egress-guard.sh` | client パスへの内部名 / PII 流出を遮断（eval ケースに本番データを混ぜない） |

不可逆操作（push / PR / main / 削除 / 外部投稿）は `safety` rule に従い人間ゲート。

## 使い方（インテント検出 — コマンド暗記は不要）

- `/ai-build`（引数なし）: 会話から意図判定（AI 機能の依頼なら Stage 1 へ）
- `/ai-build <機能>`: その機能を Stage 1 から進める

## 関連

- 内部検索: `search` / 最新調査: `research` / Claude id・価格・パラメータ: `claude-api` skill / 設計書化: `spec` / 思想: `concept` / 汎用自走ループ: `dev-loop`（本 skill はその AI 特化兄弟）/ 決定記録: `ai-context`。
