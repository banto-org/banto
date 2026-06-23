# 決定の保存（自動保存ルール / フォーマット / シークレット）

<!-- merged from auto-save-rules.md -->
## 自動保存ルール

設計判断が発生したら**即座に**保存。コミット待ち禁止。`.ai-context/` がなければ自動作成。許可は求めない。

## 保存対象

- 設計方針の決定（「A ではなく B にしよう」）
- 技術選定
- アーキテクチャ変更
- トレードオフの議論と結論
- 問題の根本原因

## 保存しない

単純な実装作業、typo 修正、事実の回答のみ。

## 保存先

`.ai-context/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md`

## 命名規則 (秒精度タイムスタンプ, v5.21.4+)

- ファイル名は秒精度の時刻で一意化（`YYYY-MM-DD-HHMMSS_topic_author`）。チーム並行・オフラインでも同日衝突しない（NNN 連番は廃止）
- 推奨名は `ai-context-decisions-numbering.sh` hook が PreToolUse で context に注入
- 旧 `YYYY-MM-DD_NNN_`（連番）形式の既存ファイルはそのまま valid（リネーム不要）

## ファイル名の決定手順

1. PreToolUse hook が「推奨ファイル名（秒精度タイムスタンプ）」を表示
2. その名前で `YYYY-MM-DD-HHMMSS_{topic}_{user}.md` を Write
3. PostToolUse hook が命名規則を検証（日付始まりだが規約外なら git mv 推奨を提示）

GitHub アカウント名は `gh api user --jq '.login'`、失敗時は `git config user.name`。

<!-- merged from decision-log-format.md -->
## Decision Log フォーマット

## 軽量（小さな判断）

```markdown
## {タイトル}

- **日付**: YYYY-MM-DD
- **タグ**: architecture, security, performance, etc.

## 判断
{何を決めたか、なぜか。2〜3行}
```

## 完全（大きな判断、Glaser フリクション含む）

```markdown
## {タイトル}: {決定内容の一行サマリー}

- **日付**: YYYY-MM-DD
- **タグ**: architecture, security, performance, etc.

## 出発点
{なぜこの判断が必要になったか}

## 検討した選択肢

| 選択肢 | メリット | デメリット |
|---------|----------|------------|
| A | ... | ... |
| B | ... | ... |

## 決め手
{最終的にどれを選び、なぜか}

## 捨てた理由
{他の選択肢を不採用にした理由}

## フリクション（着手前/着手中の違和感・遠回り、Glaser 反映）
{失敗・遠回り・「ここで詰まった」「想定と違った」を残す。学習の本体}

## 学んだこと
{次回に活かせる知見、再利用可能なパターン、回避すべき落とし穴}
```

## フリクションを残す理由 (Robert Glaser "When Everyone Has AI" より)

> "By the time the story is cleaned up enough to become a best-practice slide, the important learning has often lost its teeth. What made it useful was the friction: the missing context, the test that failed, the weird API behavior, the moment where the agent sprawled into nonsense and someone had to pull it back."

「採用の理由」だけでは形式知が空洞化する。フリクション（失敗・違和感）を残すことが組織学習の本質。

詳細: https://www.robert-glaser.de/when-everyone-has-ai-and-the-company-still-learns-nothing/

<!-- merged from secrets.md -->
## シークレット取り扱い

## 保存時（decisions/ ・チェックポイント等）

設計判断ログやチェックポイントに以下のようなトークンは**書き込まない**:
`sk-*`, `ghp_*`, `Bearer *`, `.env` 内の値, API キー, 接続文字列 等。
必要な場合は `{SECRET}` または `[MASKED]` のようなプレースホルダーに置換する。

## 表示時（ターミナル・チャット出力）

チャット履歴に残るリスクは保存時と同等。Bash 経由で値を出力するときも必ず mask する:

- `cat .env` / `diff .env .env.old` / `grep = .env` のような**生出力を禁止**
- 値が必要な時は `sed 's/=.*/=***/' .env` でキー名だけ出す
- 差分は両側を mask してから `diff`
- `grep` は prefix 限定（例: `grep "^AWS_"`）、token 系（`*_TOKEN`, `*_API_KEY`, `*_SECRET`, `Bearer *`）を巻き込まない
- **デバッグトレース禁止**: `bash -x` / `set -x` / `env` / `printenv` / `declare -p` は `.env` 由来の値が trace に出てチャットに残る。個別変数を `echo "KEY=[${#VAR} chars]"` で長さだけ出す、または `LAMBDA_API_KEY=dummy bash script.sh` のような stub で代替

詳細は `~/.claude/rules/safety.md`（harness-setup.sh でデプロイ）を参照。

## 露出してしまった時

値がチャット履歴・ログ・ファイルに残ったら、即座にユーザーへ通知し **revoke / rotation を強く勧める**。履歴からの削除だけでは不十分（外部キャッシュが残り得る）。

