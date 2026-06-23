# .mcp.json リファレンス

配置: `.mcp.json`（plugin root 直下）

プラグイン有効化時に**自動登録**される。`claude mcp add` 不要。

## stdio 型テンプレート（コマンド実行）

```json
{
  "mcpServers": {
    "{server-name}": {
      "command": "uv",
      "args": [
        "run",
        "${CLAUDE_PLUGIN_ROOT}/mcp-servers/{server}/server.py"
      ],
      "env": {
        "DB_PATH": "${CLAUDE_PLUGIN_DATA}/db"
      },
      "cwd": "${CLAUDE_PLUGIN_ROOT}",
      "type": "stdio"
    }
  }
}
```

## HTTP / SSE / WS 型テンプレート

```json
{
  "mcpServers": {
    "{name}": {
      "type": "http",
      "url": "https://example.com/mcp",
      "headers": {
        "Authorization": "Bearer ${TOKEN}"
      }
    }
  }
}
```

## type フィールド

| 値 | 用途 |
|---|---|
| `stdio` | デフォルト。コマンド実行型 |
| `http` (= `streamable-http`) | HTTP 通信 |
| `sse` | Server-Sent Events（**非推奨**）|
| `ws` | WebSocket |

公式記述:
> 「`type` フィールドは `http` のエイリアスとして `streamable-http` を受け入れます。MCP 仕様ではこのトランスポートに `streamable-http` という名前を使用しているため、サーバードキュメントからコピーされた設定は変更なしで機能します。」

## 環境変数の使い分け

| 変数 | 使う場面 |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | プラグイン同梱バイナリ・スクリプト・config への参照 |
| `${CLAUDE_PLUGIN_DATA}` | 永続化データ（DB / cache / node_modules）の保存先 |
| `${VAR:-default}` | フォールバック付き環境変数展開 |

`${CLAUDE_PLUGIN_ROOT}` はプラグイン更新で**変更される**ため、状態を書き込んではいけない。永続化は必ず `${CLAUDE_PLUGIN_DATA}` を使う。

例:
```json
{
  "mcpServers": {
    "db-server": {
      "command": "${CLAUDE_PLUGIN_ROOT}/bin/db-server",
      "env": {
        "DATA_DIR": "${CLAUDE_PLUGIN_DATA}/db",
        "API_KEY": "${MY_API_KEY:-test_key}"
      }
    }
  }
}
```

## オプションフィールド

| フィールド | 用途 |
|---|---|
| `command` | 実行コマンド（stdio 型）|
| `args` | コマンド引数 |
| `env` | 環境変数 |
| `cwd` | 作業ディレクトリ |
| `url` | エンドポイント URL（http/sse/ws）|
| `headers` | HTTP ヘッダー（http/sse/ws）|
| `headersHelper` | ヘッダー生成ヘルパースクリプトのパス |
| `alwaysLoad` | `true` でツール検索バイパス |
| `oauth` | OAuth 設定（`clientId`/`callbackPort`/`scopes`/`authServerMetadataUrl`）|

## OAuth

`oauth` フィールド（`clientId` / `callbackPort` / `scopes` / `authServerMetadataUrl`）で http 型サーバーの認証を設定する。完全な例は公式 MCP リファレンスを参照: https://code.claude.com/docs/en/mcp

## ルール

- `${CLAUDE_PLUGIN_ROOT}` で plugin root 参照（絶対パス禁止）
- 永続化は `${CLAUDE_PLUGIN_DATA}` を使う
- `./` で始まる相対パスはプラグインルート外を参照禁止（パストラバーサル制限）
- 必要な変数が未設定でデフォルトもなければパース失敗
- 複数の MCP サーバーを 1 つの `.mcp.json` に定義可
- MCP 実装本体（server.py 等）はプラグイン内の任意ディレクトリに配置可（慣例: `mcp-servers/{name}/`）
