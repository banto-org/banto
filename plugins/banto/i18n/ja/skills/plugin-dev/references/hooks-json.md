# hooks.json + hook スクリプト リファレンス

配置: `hooks/hooks.json`（plugin root 直下）

プラグイン有効化時に settings.json と**自動マージ**される。手動編集不要。

## テンプレート

```json
{
  "description": "プラグインの説明",
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/my-hook.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/after-edit.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## イベント一覧（全 29 イベント）

scaffold で頻出するイベントを上段にまとめる。全 29 イベントの一覧と詳細仕様は公式 hooks リファレンスを正本とする: https://code.claude.com/docs/en/hooks

### 頻出イベント（scaffold 対象）

| Event | 発火 | matcher? |
|---|---|---|
| `SessionStart` | セッション開始 / 再開（stdout が context に追加） | あり (`startup`/`resume`/`clear`/`compact`) |
| `UserPromptSubmit` | プロンプト送信時、Claude 処理前（stdout が context に追加） | なし |
| `PreToolUse` | ツール呼び出し前。**ブロック可能**（permissionDecision） | あり (ツール名) |
| `PostToolUse` | ツール成功後 | あり |
| `Stop` | Claude 応答完了時 | なし |
| `PreCompact` | コンテキスト圧縮前 | あり (`manual`/`auto`) |
| `SessionEnd` | セッション終了 | あり (`clear`/`resume`/`logout`/`other` 等) |

### その他のイベント（matcher 有無のみ）

| matcher なし | matcher あり |
|---|---|
| `PostToolBatch`、`TeammateIdle`、`TaskCreated`、`TaskCompleted`、`CwdChanged`、`WorktreeCreate`、`WorktreeRemove` | `Setup`、`UserPromptExpansion`、`PermissionRequest`、`PermissionDenied`、`PostToolUseFailure`、`Notification`、`StopFailure`、`SubagentStart`、`SubagentStop`、`InstructionsLoaded`、`ConfigChange`、`FileChanged`、`PostCompact`、`Elicitation`、`ElicitationResult` |

各イベントの正確な発火タイミング・matcher 値・stdin payload は上記公式リファレンスを参照。

## hook タイプ 5 種

| タイプ | 説明 |
|---|---|
| `command` | シェルコマンド / スクリプト実行 |
| `http` | イベント JSON を URL への POST |
| `mcp_tool` | 設定された MCP server のツール呼び出し |
| `prompt` | LLM でプロンプト評価（`$ARGUMENTS` 置換あり）|
| `agent` | 複雑な検証用 agentic verifier（実験的）|

## matcher パターン規則

公式原文:
> 「`"*"`、`""`、または省略 → イベントのすべての出現で発火
> 文字、数字、`_`、`|` のみ → 完全一致または `|` で区切られた完全一致のリスト
> その他の文字を含む → JavaScript 正規表現として評価」

例:
- `"Bash"` ✓ — Bash ツールのみ完全一致
- `"Write|Edit"` ✓ — Write または Edit
- `"^Notebook"` — 正規表現、Notebook で始まる全ツール
- `"mcp__memory__.*"` — memory MCP server の全ツール
- `"*"` または `""` — 全イベント発火
- `"bash"` ❌ — ツール名は大文字小文字区別、`Bash` が正解

## hook オプション

```json
{
  "type": "command",
  "command": "...",
  "timeout": 600,             // 秒。command: 600 / prompt: 30 / agent: 60 デフォルト
  "statusMessage": "実行中...",
  "once": true                // セッション中 1 回のみ（skill/agent のみ）
}
```

## Exit Code の意味

| Code | 意味 |
|------|------|
| `0` | 成功。stdout は JSON または通常テキスト解析。`UserPromptSubmit`/`UserPromptExpansion`/`SessionStart` では stdout が Claude のコンテキストに追加 |
| **`2`** | **ブロッキングエラー**。stdout・JSON 無視、**stderr が Claude にフィードバック**。イベント別効果あり |
| その他 | 非ブロッキングエラー。stderr は `--debug` で表示 |

`PostToolUse`/`PostToolUseFailure` は exit 2 でも非ブロッキング（ツールは実行済み）。
`StopFailure` は出力・終了コード**無視**。

## PreToolUse の permissionDecision

JSON 出力で `allow` / `deny` / `ask` / `defer` を返す。複数 hook の優先順位:
**deny > defer > ask > allow**

```json
{
  "permissionDecision": "deny",
  "decisionReason": "本番 DB への書き込みは禁止"
}
```

## 環境変数 / stdin / stdout

| 変数 / 機構 | 用途 |
|---|---|
| `$CLAUDE_PROJECT_DIR` | プロジェクトルート |
| `${CLAUDE_PLUGIN_ROOT}` | プラグインインストールディレクトリ |
| `${CLAUDE_PLUGIN_DATA}` | 永続データディレクトリ |
| `$CLAUDE_ENV_FILE` | SessionStart/Setup/CwdChanged/FileChanged で利用可 |
| `$CLAUDE_EFFORT` | 現在の努力レベル |
| `$CLAUDE_CODE_REMOTE` | リモート Web 環境では `"true"` |
| stdin | イベントの JSON 入力 |
| stdout | exit 0 でのみ処理。JSON or 通常テキスト（`additionalContext` として） |
| stderr | エラーメッセージ（exit 2 で Claude にフィードバック）|

## hook スクリプトの書き方

### PostToolUse hook（一時ファイル必須）

```sh
#!/bin/sh
# 重要: echo "$INPUT" | jq は content 内の $() でシェル展開される
# 必ず一時ファイル経由で jq に渡す
command -v jq >/dev/null 2>&1 || exit 0
TEMP_INPUT=$(mktemp)
cat > "$TEMP_INPUT"
TOOL_NAME=$(jq -r '.tool_name // empty' "$TEMP_INPUT" 2>/dev/null)
FILE_PATH=$(jq -r '.tool_input.file_path // empty' "$TEMP_INPUT" 2>/dev/null)
CWD=$(jq -r '.cwd // empty' "$TEMP_INPUT" 2>/dev/null)
rm -f "$TEMP_INPUT"
# 処理 ...
exit 0
```

### UserPromptSubmit / SessionStart hook

```sh
#!/bin/sh
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
# 処理 ...
exit 0
```

## アンチパターン（公式言及）

公式 hooks ページ AdditionalContext より:
> 「テキストを命令型システム指示ではなく、事実的なステートメントとして記述します。「デプロイしてください」(命令型) ではなく、「デプロイ ターゲットは本番環境です」「このリポジトリは bun test を使用します」などのフレーズはプロジェクト情報として読み取られます。帯域外システム コマンドとしてフレーム化されたテキストは Claude のプロンプト インジェクション防御をトリガーする可能性があります。」

## 実装上の注意

- スクリプトは `chmod +x` で実行権限付与必須
- POSIX 互換 shebang（`#!/bin/sh` or `#!/bin/bash`）
- `${CLAUDE_PLUGIN_ROOT}` を必ず使う（絶対パス禁止）
- shell トレース無効化（secret 露出防止、`bash -x` などを避ける）
- ツール名・イベント名すべて大文字小文字を区別
