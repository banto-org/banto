---
name: dev-loop
description: |
  大玉（spec / ドキュメント / 大きめタスク）を小型タスクへ自動分解し、実装 → 検証（② build-and-verify）→ 問題検知 → 修正 → 再検証を tasks.md が緑になるまで自走し、例外だけ owner に上げる自走開発ループ。② verify-run ＋ ④ 並列分解 ＋ spec ＋ debugger ＋ /loop を束ねる orchestrator（新規スクリプト無し）。検証段を eval 指標に差し替えれば ML 学習ループ（train→eval→調整）の派生になる。
  トリガー: 「自走で開発」「大玉を分解して回して」「ループで開発」「全部やって（大玉）」「自動で実装してテストまで」「dev loop」「学習ループ」。/dev-loop でも起動可。
  使わない場面: 単発の小さな編集（直接 Edit）／次の 1 タスクを進めるだけ（ai-context next で十分）／設計だけ（spec）／思想だけ（concept）／ブランチ・worktree 操作（ws）。
allowed-tools: Read Grep Glob Edit Write Bash Agent Skill
user-invocable: true
argument-hint: "[start|status|stop]（省略時は会話から意図を自動判定）"
model: opus
compatibility: Claude Code (requires bash, git, jq)
---

# Dev-Loop — 自走開発ループ（decompose → implement → verify → fix → loop）

> **保存ベース（store-first）**: `tasks.md` / 決定など `.ai-context/...` への Read/Write は、SessionStart/PreCompact hook が注入する「ai-context ベース: &lt;絶対パス&gt;」の配下で行う。不明なら `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`。

owner が大玉を渡す → 小型タスクへ分解 → 各タスクを実装し ② build-and-verify で検証、red なら修正して再検証、green なら次へ。tasks.md が尽きるまで自走し、**例外だけ owner に上げる**（番頭契約）。部品はすべて既存 ── **新規スクリプトは作らない**。

## 発火条件（すべて満たすとき）

- owner が大玉（spec / doc / 大きめタスク）の自走実行を求めた（「回して」「全部やって」「dev loop」）
- 小型タスクへ分解でき、実装 → 検証 → 修正のサイクルが複数回る
- 単発編集ではない

**発火しない**: 単発の小編集（直接 Edit）／次の 1 タスクを進めるだけ（`ai-context` next）／設計のみ（`spec`）／思想のみ（`concept`）。

## 自律度（L3・Autopilot）

odd.yaml = **L3（Autopilot＝継続実行＋例外時のみ owner 要求）**。banto は L0–L3 のみ（L4+ は別 plugin `banto-autonomy` に分離）。explicit stop は deterministic hook（`odd-gate` / `verify-claim-guard`）が担い、human gate は Phase 0 の分解プラン確認と push/PR/main。

## ループ手順

### Phase 0: 入力確定と分解
1. 入力を特定（現 ws の大玉タスク / 指定 spec / ドキュメント）。
2. spec が無ければ `spec` skill で要件を小型タスクへ分解 → per-ws `tasks.md` に `[ ]` で書く。
3. ④ の判断基準（同一ファイル非接触・直列依存なし）で独立な小型タスクを **並列フラグ**化（fan-out Agent 候補）。
4. **分解プラン（小型タスク列＋並列方針）を owner に 1 度提示して確認**（L3 の human gate）。確認後は例外まで回す。

### Phase 1: 周回（tasks.md が尽きるまで）
各タスクで:
1. `ai-context` の next で次の `[ ]`（依存が解けたもの）を取得。並列フラグ群は 1 メッセージ複数 Agent で fan-out、それ以外は直列。
2. **実装**（Edit / Write）。編集ごとに PostToolUse `auto-test.sh` が関連テストを回す。3 連続失敗で `odd-gate.sh` が edit を自動停止（churn 防止＝既存の retry cap）。
3. **フル検証**: `sh "$CLAUDE_PLUGIN_ROOT/hooks/verify-run.sh" <project>`（build → test → api を集約。exit 0=green / 2=red。結果は `$HOME/.cache/banto/verify-last-<session>` に `green` か `red:<steps>`）。
4. **red** → `debugger` agent で root cause 修正 → 3 へ戻る。`odd-gate` の 3 連続失敗ガードに当たったら **周回を止めて owner に上げる**（churn しない）。
5. **green** → `tasks.md` を `[x]`、ブランチへ commit（push / PR / main は人間ゲート＝既存 safety）。

### Phase 2: 収束 / 例外
- tasks.md が尽きた → 完了報告（実装・検証・採用解釈の要約）。Phase 完了なら `ai-context` の phase-done で `tasks-old/` へアーカイブ。
- 例外（連続失敗 / goal fork / 仕様曖昧 / 不可逆操作の要求）→ **止めて owner にエスカレーション**。

詳細手順・cadence・ML 学習ループ: [`references/loop-protocol.md`](references/loop-protocol.md)

## 周回の駆動（cadence）

- 既定は **インライン自走**（このセッションで Phase 1 を順に回す）。
- 放置 / 長時間で回すなら native `/loop`（self-paced）でラップし「1 周回＝次の 1 タスク」。永続 / 夜間 / PC オフは Routine（クラウド・`schedule` skill）。

## ガードレール（deterministic・既存 hook）

| ガード | hook | 効果 |
|---|---|---|
| churn 停止 | `odd-gate.sh`（PreToolUse） | テスト 3 連続失敗で edit をブロック → root cause へ |
| 偽 green 防止 | `verify-claim-guard.sh`（Stop） | verify-last が red のとき「完了」主張をブロック |
| 外部流出 | `egress-guard.sh` ＋ ⑤ sandbox | 秘匿 / 他案件名の client 流出を遮断 |
| 不可逆操作 | safety rule | push / PR / main / 削除は人間ゲート |

## ML 学習ループ（派生）

Phase 1 の検証(3)を「テスト」から **eval 指標** に差し替えた variant。train step（小型タスク）→ eval → 指標で green/red 判定 → 調整して再 train → 目標 / plateau まで周回。`verify-run.sh` の代わりに学習スクリプトの eval を回し、green/red・retry cap・エスカレーションの骨格は同じ。詳細: [`references/loop-protocol.md`](references/loop-protocol.md)。

## 使い方（インテント検出 — コマンド暗記は不要）

- `/dev-loop`（引数なし）: 会話から意図判定（大玉があれば分解プランを提示）
- `/dev-loop start`: 自走ループ開始（Phase 0 → 確認 → Phase 1）
- `/dev-loop status`: 現在の tasks.md 進捗・直近 verify 結果・retry カウンタ
- `/dev-loop stop`: 周回を止める（状態は tasks.md に残る）

## 関連

分解: `spec` / タスク台帳・next: `ai-context` / 並列判断: `ws`（並列の自発提案）/ 検証: ② build-and-verify（`hooks/verify-*.sh`）/ 修正: `debugger` agent。
