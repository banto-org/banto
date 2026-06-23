# agents/*.md リファレンス

配置: `agents/{name}.md`（plugin root 直下）

## テンプレート

```yaml
---
name: my-agent
description: |
  何をするエージェントか（三人称、詳細に）。
  use proactively when: いつ Claude が委譲すべきか。
  INVOKES: Read, Grep, WebSearch
model: sonnet
tools: Read, Grep, Glob, WebSearch
---

エージェントのシステムプロンプト本文。
```

description は **詳細に書く**（公式 Tip）。委譲判断に使われるため。
**「use proactively」** などのフレーズで自動委譲を促進。

## 全フィールド

### 必須

| フィールド | 説明 |
|-----------|------|
| `name` | 一意識別子。小文字英数+ハイフン |
| `description` | Claude がタスク委譲するか判断する説明 |

### 推奨 / 任意

| フィールド | 説明 | プラグイン制限 |
|-----------|------|:---:|
| `tools` | 許可ツール。省略時は全継承。`Skill` プリロードは別途 `skills` で指定 | - |
| `disallowedTools` | 拒否ツール（tools と併用時は先に適用）| - |
| `model` | sonnet/opus/haiku/full-ID/`inherit`（デフォルト inherit）| - |
| `permissionMode` | default/acceptEdits/auto/dontAsk/bypassPermissions/plan | **❌ 無視** |
| `maxTurns` | 最大ターン数 | - |
| `skills` | 起動時にプリロードするスキル | - |
| `mcpServers` | MCP サーバー（インライン or 名前参照）| **❌ 無視** |
| `hooks` | エージェントスコープの hook | **❌ 無視** |
| `memory` | `user` / `project` / `local`（永続メモリスコープ）| - |
| `background` | `true` でバックグラウンド実行 | - |
| `effort` | low / medium / high / xhigh / max | - |
| `isolation` | `worktree`（git worktree 分離）| - |
| `color` | red/blue/green/yellow/purple/orange/pink/cyan | - |
| `initialPrompt` | `--agent` 起動時の自動初期プロンプト | - |

## ⚠️ Plugin Agent の制限事項（公式原文）

> 「セキュリティ上の理由から、プラグインサブエージェントは `hooks`、`mcpServers`、または `permissionMode` フロントマターフィールドをサポートしていません。これらのフィールドはプラグインからエージェントを読み込むときに無視されます。これらが必要な場合は、エージェントファイルを `.claude/agents/` または `~/.claude/agents/` にコピーしてください。」

→ プラグインで配布する agent では上記 3 フィールドが**完全に無視される**。validation で警告すべき。
これらが本当に必要な場合は、agent ファイルを別途 `.claude/agents/` または `~/.claude/agents/` に配置するインストールパスを設ける（例: harness-setup.sh で配布）。

## Tools の指定

### 許可リスト形式（`tools`）

```yaml
tools:
  - Read
  - Grep
  - Glob
  - Bash(git:*)         # パターンマッチ可
  - Skill(commit)       # 特定 skill のみ
  - Agent(researcher)   # 特定エージェント生成のみ
```

### 拒否リスト併用（`disallowedTools`）

```yaml
tools: Read, Grep, Glob
disallowedTools: Write, Edit
```

### Agent ツールアクセス制御

`Agent(agent_type)` 構文で生成可能なサブエージェントを許可リスト指定:

```yaml
tools: Agent(worker, researcher), Read, Bash
```

括弧なしの `Agent` で全制限解除。リストから完全除外でサブエージェント生成不可（メインスレッドの場合のみ意味あり、サブエージェントは他のサブエージェントを生成できない）。

## description ベスプラ

公式 sub-agents Tip:
> 「**焦点を絞ったサブエージェントを設計する**: 各サブエージェントは 1 つの特定のタスクに優れている必要があります
> **詳細な説明を書く**: Claude は説明を使用して委譲するかどうかを決定します
> **ツールアクセスを制限する**: セキュリティと焦点のために必要な権限のみを付与します
> **バージョン管理にチェックインする**: プロジェクトサブエージェントをチームと共有します」

積極的委譲の促進:
> 「積極的な委譲を促進するには、サブエージェントの description フィールドに**「use proactively」**などのフレーズを含めます。」

## description テンプレ（推奨形）

```yaml
description: |
  {何をするエージェントか、三人称、詳細}
  use proactively when: {委譲すべき状況 A、B、C}
  DO NOT USE FOR: {対象外の状況 / 別 agent との切り分け}
  INVOKES: Read / Grep / Glob / WebSearch（具体的なツール）
  FOR SINGLE OPERATIONS: {単純なら直接ツールで十分}
```

plugin-audit の品質軸を満たす推奨形。
