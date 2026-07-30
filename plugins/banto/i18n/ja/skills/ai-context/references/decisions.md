# 決定の保存（自動保存ルール / フォーマット / シークレット）

<!-- merged from auto-save-rules.md -->
## 自動保存ルール

設計判断が発生したら**即座に**保存。コミット待ち禁止。base（store / 仮ローカル側）が未生成なら scaffold が自動作成（相対 `.ai-context/` には書かない）。許可は求めない。

## 文体 — 逐語引用の禁止

- 会話の発言を逐語で書かない。**要旨へ丸める**
  - ✗ owner 指示:「これも一緒に対応しておいて」
  - ✓ owner 指示（要旨）: issue #109 を同一 PR で対応する
- 口語（〜してほしい・〜ておいて・〜かな 等）が「」内に残っていたら書き直す。decision は
  生成物であり、後続セッションの検索・学習の正本になるため、口語の混入は品質を下げる
- `ja-lint` hook が decisions/ への書き込みで口語引用を warn する（決定論の補助線）

## 保存対象

- 設計方針の決定（「A ではなく B にしよう」）
- 技術選定
- アーキテクチャ変更
- トレードオフの議論と結論
- 問題の根本原因

## 保存しない

単純な実装作業、typo 修正、事実の回答のみ。

## 保存先

`{base}/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md`

## 命名規則 (秒精度タイムスタンプ, v5.21.4+)

- ファイル名は秒精度の時刻で一意化（`YYYY-MM-DD-HHMMSS_topic_author`）。チーム並行・オフラインでも同日衝突しない（NNN 連番は廃止）
- 旧 `YYYY-MM-DD_NNN_`（連番）形式の既存ファイルはそのまま valid（リネーム不要）

## ファイル名の決定手順

1. タイムスタンプは記憶で書かない。`date +%Y-%m-%d-%H%M%S`（ファイル名）と `date +%Y-%m-%d`（front-matter の `**日付**:` / `date:`）を実行し、その出力をそのまま使う（丸めない。`09:45:00` のようなキリの良い秒 `00` の推測値は不可）
2. その値で `YYYY-MM-DD-HHMMSS_{topic}_{user}.md` を Write
3. PostToolUse hook が検証（規約外の命名は git mv 推奨を提示。Write でファイル名日付が当日と異なれば「記憶で書いた疑い」を警告）

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

## 完全（大きな判断 — 固定スケルトン、節チェック hook 対象）

```markdown
---
status: accepted        # accepted | provisional
date: YYYY-MM-DD
topic: {一行サマリー}
supersedes: []          # 置き換えた旧 decision（任意。鮮度の正はファイル名日付 — これは遡り用リンク）
related: []
---

# {タイトル}: {決定内容の一行サマリー}

## 背景
{なぜこの判断が必要になったか（出発点）}

## 決定
{何に決めたか。1 文書 1 決定、断定形}

## 根拠
{決め手。なぜそれを選んだか}

## 検討した代替案

| 案 | 概要 | 却下理由 |
|---|---|---|
| A | ... | ... |
| B | ... | ... |

## 影響と限界
{この決定がもたらす影響範囲、既知の限界・トレードオフ}

## フリクション（着手前/着手中の違和感・遠回り、Glaser 反映）
{失敗・遠回り・「ここで詰まった」「想定と違った」を残す。学習の本体。任意}

## 学んだこと
{次回に活かせる知見、再利用可能なパターン、回避すべき落とし穴。任意}

## 検証
{どう確認したか / 何が緑なら成功か。任意}
```

**固定スケルトンの理由**（decision 2026-07-17）: (1) 「なぜ X にしなかったか」という検索クエリに「検討した代替案 + 却下理由」が直撃する。(2) 将来の学習データ変換（[B-03] export skill）で、節見出しが decision-context ペア / 合成 QA 生成の機械的な切り出し単位になる。**必須 4 節 = 背景 / 決定 / 根拠 / 検討した代替案**（残りは任意）。欠落は `ai-context-decisions-numbering.sh` hook が警告する（warn-only。下の軽量フォーマットの小型 decision は対象外）。

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

