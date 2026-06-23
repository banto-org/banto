---
name: knowledge
description: |
  **UTILITY SKILL** — ナレッジ下書き（drafts/）をレビュー・昇格し、正式なナレッジエントリへと整理する。
  トリガー: 「ナレッジにして」「ナレッジ昇格」「下書き一覧見せて」「ナレッジに追加」「教訓として残して」。/knowledge でも起動可。（draft 保存 hook は「/knowledge でレビュー」と案内するが、自然言語でも到達する。）
  使わない場面: 設計判断の記録（ai-context skill の decisions/ —「決定」では発火しない）、外部リサーチ（research skill）、単純なメモ保存（memo skill）、単一ファイルの単純コピー（直接 Bash の `mv`）。
  依存: Read（下書き一覧）、Write（昇格先 .ai-context/docs/knowledges/）、Glob、Bash（git mv）。
user-invocable: true
argument-hint: "[省略: 下書き一覧表示 / 'promote': 昇格モード / topic: 新規作成]"
allowed-tools: Read Write Glob Bash
compatibility: Claude Code (requires bash, git, jq)
---

# Knowledge — ナレッジ管理

> **保存ベース（store-first）**: 昇格先 `.ai-context/docs/knowledges/...` は ai-context ベースを指す。SessionStart/PreCompact hook が「ai-context ベース: &lt;絶対パス&gt;」として注入する絶対パス配下で Read/Write する — 相対 `.ai-context/` には絶対に書かない（既存の legacy repo にのみ存在する。不明なときは `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決）。

**パターン**: B（穴埋めテンプレート、ただし**プレフィックスなしの例外**あり）— 共通スケルトンは `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` §3「knowledge exception」を参照
**保存先**: `.ai-context/docs/knowledges/{topic}.md`（昇格済み）+ `drafts/{topic}.md`（下書き）

ナレッジエントリの応答・記述はユーザーの会話言語で行う（ユーザーが日本語で会話していれば日本語）。

## Directory structure

```
.ai-context/docs/knowledges/
├── drafts/              # drafts (auto-saved when a hook detects them)
│   ├── posttooluse-json-shell-expansion.md
│   └── search-query-expansion-tuning.md
├── posttooluse-json-shell-expansion.md   # promoted knowledge
└── search-query-expansion-tuning.md
```

## Step 1: モードを判定

- **引数なし** → `drafts/` を一覧表示
- **数字または `promote`** → 昇格モード
- **トピック文字列** → ナレッジエントリを新規作成

## Step 2: モード別処理

### 2a. 下書き一覧

1. `Glob(".ai-context/docs/knowledges/drafts/*.md")`
2. 各ファイルの先頭 3 行（タイトル）を読む
3. 一覧を表示:

```
## Knowledge drafts

1. **PostToolUse JSON shell expansion issue** (drafts/posttooluse-json-shell-expansion.md)
2. **search query expansion tuning** (drafts/search-query-expansion-tuning.md)

Pick the ones to promote (number, or "all").
```

### 2b. 昇格

1. 選択されたファイルを全文 Read して表示し、ユーザーに修正を尋ねる
2. 確認が取れたら、`drafts/` から `knowledges/` 直下へ移動する:
   ```bash
   git mv .ai-context/docs/knowledges/drafts/{file} .ai-context/docs/knowledges/{file}
   ```
3. combined.txt は docs への Write を契機に PostToolUse hook が自動再生成する

### 2c. 新規作成

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

## Step 3/4: 保存 + 報告

共通パターン（`_common-pattern.md` §2 パターン B / §4 報告フォーマット）に従う。命名は knowledge exception（プレフィックスなし。タイトルがそのままファイル名）に従う。

## Searching knowledge

昇格済みのナレッジは search skill で検索できる:
- `/search {query}` が `.ai-context/`（+ config.json の `extra_docs_dirs` で追加したディレクトリ）を横断検索する
- 自然言語トリガーでも発火する（例: 「思い出して」 → `search` skill）

## Automatic draft saving by hook

`ai-context-auto.sh` は以下のキーワードを検出すると下書き保存を促す:

- 「ハマった」「原因は」「解決した」「パターン」「分かった」「判明」
- 「発見した」「気づ」「gotcha」「workaround」「notice」
