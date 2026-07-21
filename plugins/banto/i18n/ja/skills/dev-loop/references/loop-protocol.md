# Dev-Loop プロトコル詳細

SKILL.md の補足。周回の具体・状態ファイル・cadence・ML 学習ループの差し替え点を記す。

## 状態ファイル（既存 ② build-and-verify が書く・正本）

| ファイル | 書き手 | 内容 |
|---|---|---|
| `$HOME/.cache/banto/verify-last-<session>` | `verify-run.sh` | `green` ／ `green (no verify commands detected)` ／ `red:<失敗ステップ>` |
| `$HOME/.cache/banto/test-failures-<session>` | `auto-test.sh` / `verify-run.sh` | TF カウンタ（green で 0 リセット・red で +1） |

`<session>` の解決順は 3 段：`BANTO_SESSION_ID` / `CLAUDE_SESSION_ID`（env）→ odd-gate が PreToolUse:Write|Edit で残す cwd 単位ポインタ `session-current-<cwd_id>`（実装ループでは先行 Edit が必ず書く）→ どちらも無ければ `manual`。状態 dir は `ODD_STATE_DIR`（既定 `$HOME/.cache/banto`）。ポインタ鍵は cwd の cksum のため、**verify-run はセッションの cwd（リポジトリ root）で呼ぶ**こと（サブディレクトリ指定だと鍵が割れて manual に落ちる）。

## フル検証の呼び方

```sh
sh "$CLAUDE_PLUGIN_ROOT/hooks/verify-run.sh" <project_dir>
# exit 0 = green（または検証コマンド無し） / exit 2 = red
# 検出は verify-detect.sh が正本（BUILD_CMD / TEST_CMD / API_SMOKE_CMD）
# 結果は verify-last-<session> に 1 行で残る
```

red の出力は stderr に各ステップ PASS/FAIL ＋ 失敗ステップの末尾 8 行。これを debugger agent に渡して root cause を取る。

### no-commands フォールバック（markdown / 設定 / docs リポジトリ）

build/test/api コマンドが無いリポジトリ（markdown 中心の plugin・設定リポジトリ等）では `verify-run.sh` が「nothing to verify（exit 0）」を返す。これは「検証スキップ」ではなく「汎用ランナーの対象外」を意味するので、その場合は**ドメイン固有チェックへ fallback する**:

| リポジトリ種別 | fallback 検証 |
|---|---|
| banto plugin 自体 | 該当を flag した監査スクリプト再実行（`plugin-audit-interface.sh` / `-collect.sh` 等）＋ i18n materialize 後の active=canonical diff |
| シェルスクリプト | `sh -n`（構文）／ shellcheck |
| YAML / JSON 設定 | スキーマ / パーサ検証（`jq empty` / `yaml.safe_load`） |
| ドキュメントのみ | リンク切れ・参照先実在・プレースホルダ残存チェック |

green/red の判定は同じ（fallback チェックが通れば green 扱いで次タスクへ、落ちれば red として修正）。

## 周回の擬似コード（Phase 1）

```
while tasks.md に [ ] が残る:
    task = ai-context next（依存が解けた先頭の [ ]）
    if task が並列フラグ群:
        1 メッセージで複数 Agent を fan-out（同一ファイル非接触が前提）
    else:
        実装（Edit/Write）
    sh verify-run.sh <project>
    if red:
        if TF カウンタ >= 3（閾値到達。odd-gate 有効時は edit がブロック済み）:
            STOP → owner にエスカレーション（churn しない）
        else:
            debugger agent で修正 → verify-run.sh を再実行
    else (green):
        tasks.md の該当行を [x]
        git add -A && git commit（ブランチ止まり・push しない）
```

## エスカレーション条件（番頭は例外だけ主人に持っていく）

- テスト 3 連続失敗（TF カウンタ閾値到達）
- verify-last が red のまま「完了」と言いそう（verify-claim-guard が Stop でブロック）
- goal fork（A/B で受け入れ基準・影響範囲・セキュリティ意味が変わる／owner 固有のビジネス知識依存）
- 仕様が曖昧で採用解釈が立たない
- 不可逆 / 外向き操作（push・PR・main・削除・外部投稿）の要求

いずれも **止めて owner に上げる**。自走の中で勝手に通さない。

## cadence の選び方

| 状況 | 駆動 | 理由 |
|---|---|---|
| いまセッション内で一気に回す | インライン（Phase 1 を順に実行） | 最速・追加機構不要 |
| 放置で進めたい / 作業中ポーリング | native `/loop`（self-paced・1 周回＝次の 1 タスク） | セッション内・7 日失効 |
| 永続 / 夜間 / PC オフ | Routine（クラウド・`schedule` skill） | スケジュール / GitHub トリガーで稼働 |

`/loop` を引数なしで使うと self-paced（モデルが次の起床を決める）。詳細は native `/loop` skill に従う。

## ML 学習ループ（派生）

dev ループと同じ骨格で、**検証段だけ差し替える**:

| dev ループ | ML 学習ループ |
|---|---|
| 実装（Edit/Write） | train step（小型タスク：1 epoch / 1 config の学習） |
| `verify-run.sh`（build/test/api） | 学習スクリプトの **eval**（指標を 1 行で出す） |
| green = テスト PASS | green = 指標が目標達成 or 改善 |
| red = テスト FAIL | red = 指標が悪化 / 未達 |
| retry cap = TF カウンタ（3 連続） | retry cap = 改善なし N 周（plateau 検出） |
| 完了 = tasks.md 尽きる | 完了 = 目標到達 or plateau |

eval の green/red 判定を verify-last 互換の 1 行（`green` / `red:<metric>`）で書けば、verify-claim-guard・エスカレーションの仕組みをそのまま流用できる。`moe-pruning` 等の学習スキルと接続する場合は、その eval を検証段に差す。

## tasks.md 台帳

- 場所: per-ws `workspaces/<author>/[scope] topic/tasks.md`（store base 配下）。
- 形式: `- [ ]`（未）/ `- [x]`（完）/ `- [~]`（進行中・部分）。
- next / phase-done は `ai-context` skill が所有。dev-loop はそれを呼ぶだけで台帳ロジックを再実装しない。
