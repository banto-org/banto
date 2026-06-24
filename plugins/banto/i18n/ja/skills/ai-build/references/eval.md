# eval リファレンス（LLM-as-judge）

Stage 6 の補助。「動いた」を「測れた」に変える層。最小実装は同梱の `scripts/ai-eval-judge.sh`（`claude -p` による LLM-as-judge）。本格基盤（promptfoo / RAGAS）は**任意・案内のみ**で同梱しない（依存を増やさない方針）。

## 何を測るか（採点軸）

成功基準（Stage 1）を採点軸へ落とす。代表例:

| 軸 | 意味 | 効く課題 |
|---|---|---|
| **accuracy / correctness** | 期待と合致するか | 分類 / 抽出 / QA |
| **faithfulness（根拠忠実性）** | 与えた文脈に沿い、捏造しないか | RAG |
| **relevance** | 検索 / 回答が問いに的確か | RAG / 検索 |
| **format / schema** | 構造化出力がスキーマに合うか | JSON / tool use |
| **safety / refusal** | 拒否すべきを拒否し、過剰拒否しないか | 安全要件 |
| **tone / style** | トーン・様式が要件どおりか | 文章生成 |

1 軸 = 1 数値（0–100 など）に落とすと閾値判定が deterministic になる。複数軸は重み付き平均か、各軸独立の閾値で AND を取る。

## ケース集の形式（JSONL）

1 行 1 ケースの JSONL（`scripts/ai-eval-judge.sh` の入力）:

```jsonl
{"input": "問い or 入力", "expected": "期待 or 採点基準", "output": "被験システムの出力"}
{"input": "...", "expected": "...", "output": "..."}
```

- `output` を入れておけば judge はそれを採点する。`output` 省略時は judge が `input` のみで採点（基準ベースの絶対採点）。
- `expected` は「正解」でも「採点基準（rubric）」でもよい（judge プロンプトに渡る）。
- **本番 client データ / PII / 内部名を混ぜない**（egress-guard が client パス流出を遮断）。合成 or 匿名化したケースを使う。
- 規模: まず 10〜30 件の代表ケース（境界・失敗しがちな例を厚く）。回帰用に増やす。

## 最小実装の回し方

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-eval-judge.sh" cases.jsonl
# 各ケースを claude -p で 0–100 採点 → 平均 + PASS/FAIL を出力
# 閾値: BANTO_EVAL_PASS（既定 70）
# judge モデル: BANTO_EVAL_MODEL（既定 claude CLI の既定モデル）
# claude / jq 不在 → no-op で exit 0（fail-open。eval 不能で実装を止めない）
```

判定を 1 行（`green` / `red:<metric>`）で残せば、dev-loop の `verify-claim-guard`（eval が red のまま「完了」主張をブロック）とエスカレーション骨格をそのまま流用できる。

### LLM-as-judge の注意

- **judge と被験を別軸で見る**: judge も LLM なのでバイアスがある。位置バイアス（先に出た方を高評価）・冗長性バイアス（長い方を高評価）に注意。
- **rubric を明示**: 「何点が何を意味するか」を judge プロンプトに書くと再現性が上がる。
- **自己採点を避ける**: 可能なら被験と異なるモデル / 設定で採点する。
- judge スコアは**相対比較に強い**（版 A vs 版 B のどちらが良いか）。絶対点は rubric 次第でぶれる。

## 外部 eval 基盤（任意・案内のみ — 同梱しない）

最小実装で足りなくなったら（多軸・大規模ケース・CI 常設）外部ツールへ:

| ツール | 向く用途 | 備考 |
|---|---|---|
| **promptfoo** | プロンプト / モデルの A/B 比較・YAML でケース定義・CI 連携 | `npx promptfoo eval`。assert に LLM-rubric / 正規表現 / JS を混在可 |
| **RAGAS** | RAG 専用指標（faithfulness / answer relevance / context precision・recall） | Python ライブラリ。RAG パイプラインの定量評価 |
| **DeepEval** | pytest 風の LLM テスト・多彩な metric | Python。回帰テストとして組み込みやすい |

これらは Banto が同梱せず、案内に留める（依存最小の方針）。導入する場合もケース集（JSONL / CSV）と採点軸の考え方は本ファイルと共通。最新の使い方は `research` skill で取りに行く。
