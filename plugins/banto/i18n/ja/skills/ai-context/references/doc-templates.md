# メモ / ナレッジ テンプレート

`memo` と `knowledge` サブコマンドが書き込む Markdown の穴埋めテンプレート。SKILL.md 本体からは
モード判定と保存先パスのみ参照し、雛形はここにまとめる。

## メモ（`memo`）

### Mode 1: 引数なし（会話の要約）

現在の会話を要約してメモにする。抽出する項目: 議論したトピック / 下した決定 / 未解決の論点 / 主要な発見・知見。
保存先: `{base}/docs/[Memo] session-summary-{YYYY-MM-DD}.md`

```markdown
# [Memo] Session Summary

- **Date**: {today's date}
- **Author**: AI

## Topics discussed
- {topic 1}
- {topic 2}

## Decisions made
-

## Open issues
-

## Key findings / insights
-
```

Mode 1 では**要約をテキストで提示してから保存**する（事後開示 — store への保存は safety.md の「自由に実行してよい」非破壊操作。ユーザーは後から修正を依頼できる）。

### Mode 2: 引数あり（指定内容をメモ化）

`$ARGUMENTS` の内容をメモとして記録する。
保存先: `{base}/docs/[Memo] {slugified argument}-{YYYY-MM-DD}.md`

```markdown
# [Memo] {title from the argument}

- **Date**: {today's date}
- **Author**: AI

## Content

{structured write-up of $ARGUMENTS}
```

保存・報告は共通パターン（`${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` §2 パターン B / §3 命名規則 / §4 報告フォーマット / §1.6 文体規約）に従う。日本語のメモ本文は `~/.claude/rules/writing-ja.md` に従う。

## ナレッジ（`knowledge`）

構造: 詳細は [`directory-structure.md`](directory-structure.md)。昇格先 = `{base}/docs/knowledges/{topic}.md`、下書き = `{base}/docs/knowledges/drafts/{topic}.md`。

### モードを判定（`$ARGUMENTS` の最初のトークン）

- **引数なし / `list`** → 下書き一覧
- **数字 / `promote`** → 昇格モード
- **トピック文字列** → ナレッジエントリを新規作成

#### list（下書き一覧）

1. `Glob("{base}/docs/knowledges/drafts/*.md")`
2. 各ファイルの先頭 3 行（タイトル）を読む
3. 一覧を表示し、昇格する番号（または "all"）を尋ねる:

```
## Knowledge drafts

1. **PostToolUse JSON shell expansion issue** (drafts/posttooluse-json-shell-expansion.md)
2. **search query expansion tuning** (drafts/search-query-expansion-tuning.md)

Pick the ones to promote (number, or "all").
```

#### promote（昇格）

1. 選択されたファイルを全文 Read して表示し、ユーザーに修正を尋ねる
2. 確認が取れたら `drafts/` から `knowledges/` 直下へ移動する:
   ```bash
   git mv "{base}/docs/knowledges/drafts/{file}" "{base}/docs/knowledges/{file}"
   ```
   （store 内で git 管理外なら `mv`）
3. 検索ランキングは decisions/docs を直接走査するため、移動後はそのまま検索対象になる（FTS5 セクション索引は Write を契機に PostToolUse hook が自動追従する）

#### 新規作成

`$ARGUMENTS` をトピックとして `knowledges/` 直下に保存する:

```markdown
# {topic}

## Problem
{what happened}

## Cause
{why it happened}

## Solution
{how it was solved}

## Lesson
{how to prevent the same problem}

## Related
- {related decisions/ files}
- {related research/ files}
```

命名は knowledge exception（プレフィックスなし。タイトルがそのままファイル名）に従う（`_common-pattern.md` §3「knowledge exception」）。昇格済みナレッジは `search` skill（`/search <query>`）で横断検索できる。

> **下書きの自動保存（hook）**: `ai-context-auto.sh` は「ハマった」「原因は」「解決した」「パターン」「分かった」「判明」「発見した」「気づ」「gotcha」「workaround」「notice」を検出すると下書き保存を促す。溜まった下書きは SessionStart hook（`knowledge-draft-review.sh`）が閾値超で提示し、この `knowledge` 手順で処理する。
