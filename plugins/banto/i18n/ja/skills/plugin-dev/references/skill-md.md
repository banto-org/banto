# SKILL.md リファレンス

配置: `skills/{name}/SKILL.md`

## frontmatter 全フィールド

### Open Standard コア（30+ ツール対応）

| フィールド | 必須 | 説明 |
|-----------|:---:|------|
| `name` | ◎ (Open Standard) | 小文字英数+ハイフン、最大 64 字、親ディレクトリ名と一致 |
| `description` | 推奨 | スキルの目的と使用タイミング、最大 **1,024 字** |
| `license` | | ライセンス識別子（Open Standard） |
| `compatibility` | | 環境要件、最大 500 字（Open Standard） |
| `metadata` | | 任意の key-value マップ（Open Standard） |
| `allowed-tools` | | 許可ツール、スペース区切り or YAML 配列（Experimental） |

### Claude Code 拡張

| フィールド | 説明 |
|-----------|------|
| `when_to_use` | 追加トリガー。description と合算で **1,536 字** にカウント |
| `argument-hint` | `/skill [引数ヒント]` のオートコンプリート表示 |
| `arguments` | 名前付き引数（スペース区切り or YAML）。`$name` で展開 |
| `disable-model-invocation` | `true` で Claude 自動発火禁止（明示呼出 `/name` のみ）|
| `user-invocable` | `false` で `/` メニュー非表示（Claude のみ起動可）|
| `model` | sonnet/opus/haiku/full-id/`inherit` |
| `effort` | low / medium / high / xhigh / max（max は Opus のみ）|
| `context` | `fork` でサブエージェント分離実行 |
| `agent` | `context: fork` 時の agent 型（Explore / Plan / general-purpose 等）|
| `paths` | glob パターンで自動発火条件（カンマ区切り or YAML 配列）|
| `hooks` | スキルスコープのライフサイクル hook 定義 |
| `shell` | `bash`（デフォルト）or `powershell` |

**重要な訂正（旧監査の誤情報）**:
- `when_to_use` は **公式サポート**（旧版で「Claude が無視」と書かれていたが誤り）
- `license` / `metadata` / `compatibility` は **削除すべきではない**（Open Standard コア、互換ツール対応）
- description 文字数キャップは **1,024 字（Open Standard）/ 1,536 字（合算）**（旧版 250 字は誤り）

## description 文字数

| 制限 | 値 |
|------|----|
| description 単独 | ≤ **1,024 字**（Open Standard 上限）|
| description + when_to_use 合算 | ≤ **1,536 字**（Claude Code 表示カット境界）|
| 全 skill 合算動的予算 | コンテキストの **1%**、フォールバック **8,000 字** |

短く保つ方が自動発火判定の精度が上がる。100〜500 字を目安に、トリガー / 除外条件 / INVOKES を簡潔に詰める。

## テンプレート（推奨形）

### 通常 skill（自動発火 + ユーザー呼出 両対応）

```yaml
---
name: {skill-name}
description: |
  **{WORKFLOW SKILL | UTILITY SKILL | ANALYSIS SKILL}** — {何をするか、三人称}。
  USE FOR: {主要トリガー A、B、C}
  DO NOT USE FOR: {除外条件 / 別 skill との切り分け}
  INVOKES: {依存ツール / agent / コマンド}
  FOR SINGLE OPERATIONS: {単純操作なら直接ツールで十分}
user-invocable: true
allowed-tools: Read Grep Glob
---

# {Skill Title}

$ARGUMENTS が指定された場合、それを入力として使用する。

## 手順
1. ...
2. ...
```

### 明示呼出専用 skill（副作用ワークフロー）

```yaml
---
name: {skill-name}
description: |
  **WORKFLOW SKILL** — {何をするか}。/{skill-name} で明示呼び出し専用。
  INVOKES: {依存 agent}
  FOR SINGLE OPERATIONS: {単純なら別手段}
user-invocable: true
disable-model-invocation: true
argument-hint: "[引数ヒント]"
allowed-tools: Read Write Bash Agent
---
```

設計指針: commit / deploy / send 等の副作用ワークフローは `disable-model-invocation: true` を推奨（公式 Skills ページ）。

### バックグラウンド知識 skill（Claude のみ起動）

```yaml
---
name: {skill-name}
description: "{何をするか、Claude が自動参照}"
user-invocable: false
---
```

## skill 分類プレフィックス（推奨）

description / 本文の冒頭に書く分類タグ:

| プレフィックス | 用途 |
|---|---|
| `**WORKFLOW SKILL**` | 複数ステップオーケストレーション（spec, research）|
| `**UTILITY SKILL**` | 単一目的ヘルパー（status, save-checkpoint, ws）|
| `**ANALYSIS SKILL**` | 読み取り専用解析（search, plugin-audit, harness-audit）|

公式仕様ではないが、検索・可視化・設計判断の助けになる。

## description のコツ

- description 単独 ≤ 1,024 字、合算（when_to_use 含む）≤ 1,536 字
- 三人称（"I can help..." ❌、"Helps users..." ✓）
- HeavySkill 4 ブロックパターン:
  - `USE FOR:` または「トリガー：」 → 主要発火条件（複数）
  - `DO NOT USE FOR:` または「使ってはいけない場面：」 → 除外条件
  - `INVOKES:` または「依存：」 → 呼び出すツール / agent
  - `FOR SINGLE OPERATIONS:` または「単純な〜なら〜で十分」 → 単純操作切り分け
- 文章は短く、改行を活用して構造を視覚化

## テンプレート変数

| 変数 | 説明 |
|-----|------|
| `$ARGUMENTS` | `/skill-name` の後の全テキスト |
| `$ARGUMENTS[0]` or `$0` | 最初の引数（シェルスタイルクォート対応）|
| `$ARGUMENTS[1]` or `$1` | 2 番目の引数 |
| `$name` | `arguments` フロントマターで宣言された名前付き引数 |
| `${CLAUDE_SESSION_ID}` | セッション ID |
| `${CLAUDE_EFFORT}` | 現在の努力レベル |
| `${CLAUDE_SKILL_DIR}` | SKILL.md のディレクトリパス |
| `${CLAUDE_PLUGIN_ROOT}` | プラグインインストールディレクトリ |
| `${CLAUDE_PLUGIN_DATA}` | プラグイン永続データディレクトリ |

## 動的コンテキスト注入 `` !`command` ``

スキルがロードされる**前**にシェルコマンドを実行し、出力をプレースホルダに置換:

```yaml
## Current changes
!`git diff HEAD`
```

複数行は ``` ```! ``` で開かれたフェンスコードブロック:
````markdown
```!
node --version
git status --short
```
````

無効化: `"disableSkillShellExecution": true`

## 名前空間

- プラグイン内: `/<plugin-name>:<skill-name>`
- スタンドアロン: `/<skill-name>`

## supporting files（500 行超え対策、トークン警告対策）

```
skills/{name}/
├── SKILL.md          ← 概要（500 行以内、トークン warn=500/hard=1000）
├── references/       ← 詳細（必要時のみ Read）
│   ├── api.md
│   └── examples.md
└── scripts/          ← 実行スクリプト
```

ネストは 1 段まで（SKILL.md → reference.md は OK、reference → detail は NG）。

## HeavySkill 4-component（複雑な workflow skill 推奨）

複雑な推論・判断を含む skill は HeavySkill 4-component（Activation Conditions / Parallel Protocol / Deliberation / Output Constraints）を採用。正本テンプレと適用基準は `references/heavyskill-template.md` を参照。

## 自己記述スキーマ（参考、未採用）

AFFiNE Block 由来の `metadata: { role, parent, children }` 構造は概念として強力だが、Claude Code skill frontmatter 仕様外のため本プラグインでは未採用。将来 plugin が拡張される際に Open Standard `metadata` キー内で再考可能。
