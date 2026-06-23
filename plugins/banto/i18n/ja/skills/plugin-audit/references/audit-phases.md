# 監査 Phase 詳細（Phase 1〜8.5）

## Phase 1: ディレクトリ構造の確認

```
1. .claude-plugin/plugin.json が存在するか
2. .claude-plugin/ 内に plugin.json 以外のコンポーネントがないか（誤配置）
3. skills/, agents/, hooks/, commands/, .mcp.json, .lsp.json の位置が plugin root 直下か
4. 非公式ディレクトリ（rules/, mcp-servers/ 等）があるか → 要警告
```

## Phase 2: plugin.json の検証

```
1. name フィールド存在（必須）
2. version, description, author の推奨フィールド
3. 非公式フィールドの検出
4. experimental.themes / experimental.monitors の使用（旧トップレベル themes/monitors は警告）
```

## Phase 3: SKILL.md frontmatter 監査

各 `skills/*/SKILL.md` について:

**必須チェック**:
- [ ] `name` フィールド存在（小文字英数+ハイフン、最大 64 字、親ディレクトリ名と一致）
- [ ] `description` フィールド存在
- [ ] `description` ≤ **1,024 字**（Open Standard 上限）
- [ ] `description + when_to_use` 合算 ≤ **1,536 字**（Claude Code 表示カット境界）
- [ ] `description` が三人称（"I can..."/"You can..." は NG）
- [ ] `disable-model-invocation: true` でない場合、`description` に "Use when" 等のトリガー文言含む

**公式フィールド一覧（Open Standard + Claude Code 拡張）**:

| フィールド | 区分 | 用途 |
|---|---|---|
| `name` | Open Standard | 識別子 |
| `description` | Open Standard | 自動発火判断 |
| `license` | Open Standard | ライセンス |
| `compatibility` | Open Standard | 環境要件（≤ 500 字）|
| `metadata` | Open Standard | 任意の key-value |
| `allowed-tools` | Open Standard (Experimental) + Claude Code | 許可ツール |
| `when_to_use` | Claude Code | 追加トリガー（description と合算 1,536 字）|
| `argument-hint` | Claude Code | オートコンプリート |
| `arguments` | Claude Code | 名前付き引数 |
| `disable-model-invocation` | Claude Code | 自動発火禁止 |
| `user-invocable` | Claude Code | `/` メニュー制御 |
| `model` / `effort` | Claude Code | モデル / 努力レベル |
| `context` / `agent` | Claude Code | サブエージェント分離 |
| `hooks` | Claude Code | ライフサイクル hook |
| `paths` | Claude Code | glob パターンで selective activation |
| `shell` | Claude Code | bash / powershell |

**重要な訂正（旧監査の誤情報）**:
- `when_to_use` は **公式サポート**（旧監査では誤って「Claude が無視」扱い）
- `license` / `metadata` / `compatibility` は **Open Standard コアフィールド**。削除すべきではない
- `version` は SKILL.md frontmatter 公式仕様外（plugin.json のみ）

**allowed-tools フォーマット**:
- ✓ スペース区切り: `allowed-tools: Read Grep Glob`
- ✓ YAML 配列: `allowed-tools: ["Read", "Grep", "Glob"]` または block 形式
- ❌ カンマ区切り: `allowed-tools: Read, Grep, Glob`（公式仕様外）

## Phase 4: SKILL.md 本文監査

- [ ] 500 行以内（超えたら reference.md 等に分割推奨）
- [ ] 人間向けマーケティング文言なし（「概要」「なぜこの方式か」等）
- [ ] 命令形（action-oriented）
- [ ] 禁止事項は `NEVER` / `ALWAYS` で強調

## Phase 5: hooks/hooks.json 監査

- [ ] `hooks/hooks.json` 存在（hook を持つ場合）
- [ ] `${CLAUDE_PLUGIN_ROOT}` を使用（絶対パス禁止）
- [ ] matcher の大文字小文字が正しい（`Bash` ✓、`bash` ❌、`Edit|Write` ✓）
- [ ] matcher 未対応イベントに matcher を書いていないか（UserPromptSubmit, PostToolBatch, Stop, TaskCreated 等は matcher なし）
- [ ] hook スクリプトに実行権限（`chmod +x`）
- [ ] POSIX 互換（`#!/bin/sh` or `#!/bin/bash`）

**29 種公式イベント**:
SessionStart / Setup / UserPromptSubmit / UserPromptExpansion / PreToolUse / PermissionRequest / PermissionDenied / PostToolUse / PostToolUseFailure / PostToolBatch / Notification / SubagentStart / SubagentStop / TaskCreated / TaskCompleted / Stop / StopFailure / TeammateIdle / InstructionsLoaded / ConfigChange / CwdChanged / FileChanged / WorktreeCreate / WorktreeRemove / PreCompact / PostCompact / Elicitation / ElicitationResult / SessionEnd

**hook タイプ 5 種**: `command` / `http` / `mcp_tool` / `prompt` / `agent`

**Exit code**:
- `0` → 成功（stdout を JSON or 通常テキスト解析）
- `2` → ブロッキングエラー（stderr が Claude にフィードバック）
- その他 → 非ブロッキング

## Phase 6: .mcp.json 監査

- [ ] MCP サーバーを提供する場合は `.mcp.json` が plugin root にあるか
- [ ] `${CLAUDE_PLUGIN_ROOT}` でパス指定（絶対パス禁止）
- [ ] `type` フィールド: `stdio`（デフォルト）/ `http` (= `streamable-http`) / `sse`（非推奨）/ `ws`
- [ ] 環境変数展開 `${VAR:-default}` の利用
- [ ] 永続データは `${CLAUDE_PLUGIN_DATA}` に書く（`${CLAUDE_PLUGIN_ROOT}` は更新で消える）

## Phase 7: commands/*.md 監査

公式表現は **「merged into skills」**（「legacy」「deprecated」とは公式に書かれていない）。新規プラグインは `skills/` 推奨だが、既存 commands は引き続き機能する。

- [ ] frontmatter は SKILL.md と完全互換
- [ ] 同名の skill が存在する場合は skill が優先される
- [ ] 新規プラグインなら commands/ ではなく skills/ で作成（公式推奨）

## Phase 8: 非公式 / 実験的コンポーネント検出

**Open Standard / 公式仕様外**:
- `rules/` → 公式プラグインシステムには統合されていない。`templates/rules/` に置いて install スクリプトで配布する方式が banto の選択
- `mcp-servers/` → 実装本体を置くのは OK、`.mcp.json` から `${CLAUDE_PLUGIN_ROOT}/mcp-servers/...` で参照

**実験的フィールド（plugin.json）**:
- `experimental.themes` / `experimental.monitors` → 公式推奨（旧トップレベル `themes` / `monitors` は警告、将来 deprecated）
- `channels` / `dependencies` / `userConfig` → 公式記載あり

## Phase 8.5: Plugin agent 制限チェック（重要）

`agents/*.md` で以下のフィールドを使っている場合、**プラグイン agent では無視される**（公式 sub-agents Note より、セキュリティ理由）:

- `hooks` → 無視
- `mcpServers` → 無視
- `permissionMode` → 無視

これらが必要な場合は、agent ファイルを `.claude/agents/` または `~/.claude/agents/` にコピーして配布する別経路が必要。
