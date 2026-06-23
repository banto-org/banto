# plugin.json リファレンス

配置: `.claude-plugin/plugin.json`

**重要**: `.claude-plugin/` には **plugin.json だけ**。他のディレクトリ（commands/, agents/, skills/, hooks/）はプラグインルート直下に置く。Note: マニフェスト自体オプション、省略時は Claude Code がデフォルト場所からコンポーネントを自動検出（ディレクトリ名から plugin name を導出）。

## テンプレート（最小）

```json
{
  "name": "{name}"
}
```

`name` のみ必須。

## テンプレート（推奨）

```json
{
  "name": "{name}",
  "version": "1.0.0",
  "description": "{何をするプラグインか}",
  "author": { "name": "{author}" },
  "homepage": "https://github.com/{owner}/{repo}",
  "repository": "https://github.com/{owner}/{repo}",
  "license": "MIT",
  "keywords": ["{keyword1}", "{keyword2}"]
}
```

## 全フィールド（公式 plugins-reference 由来）

### 標準メタデータ

| フィールド | 必須 | 説明 |
|-----------|:---:|------|
| `name` | ✓ | 一意識別子。スキル名前空間のプレフィックス（`/name:skill`）|
| `$schema` | | エディタ補完用、Claude Code はロード時無視 |
| `version` | | semver。設定するとピン留め、省略時は git commit SHA がフォールバック |
| `description` | | プラグインマネージャー UI に表示 |
| `author` | | `{name, email, url}` |
| `homepage` | | プロジェクト URL |
| `repository` | | Git リポジトリ URL |
| `license` | | ライセンス（MIT 等）|
| `keywords` | | 検索キーワード配列 |

### コンポーネントパス（カスタムパス指定）

| フィールド | デフォルト | パス動作 |
|-----------|----------|---------|
| `skills` | `skills/` | string\|array。**追加** |
| `commands` | `commands/` | string\|array。**置き換え** |
| `agents` | `agents/` | string\|array。**置き換え** |
| `hooks` | `hooks/hooks.json` | string\|array\|object。**マージ** |
| `mcpServers` | `.mcp.json` | string\|array\|object。**マージ** |
| `lspServers` | `.lsp.json` | string\|array\|object。**マージ** |
| `outputStyles` | `output-styles/` | **置き換え** |

### 実験的フィールド（公式推奨配置）

```json
{
  "experimental": {
    "themes": "./themes/",
    "monitors": "./monitors.json"
  }
}
```

旧トップレベル `themes` / `monitors` はまだ機能するが `claude plugin validate` で警告、将来は `experimental.*` 必須。

### ユーザー設定 / チャネル / 依存

| フィールド | 説明 |
|-----------|------|
| `userConfig` | プラグイン有効化時にプロンプトされる設定。`type/title/description/sensitive/required/default/multiple/min/max` |
| `channels` | メッセージ注入用チャネル宣言（Telegram/Slack/Discord 風）|
| `dependencies` | 他プラグインへの semver 依存（例: `~2.1.0`）|

## userConfig 例

```json
{
  "userConfig": {
    "api_token": {
      "type": "string",
      "title": "API トークン",
      "description": "API 認証トークン",
      "sensitive": true,
      "required": true
    },
    "max_results": {
      "type": "number",
      "title": "最大結果数",
      "default": 10,
      "min": 1,
      "max": 100
    }
  }
}
```

- 非 sensitive → `settings.json` の `pluginConfigs` に保存
- sensitive → システムキーチェーン（~2KB 制限）
- 環境変数 `CLAUDE_PLUGIN_OPTION_<KEY>` でサブプロセスに展開
- スキル内で `${user_config.KEY}` 参照（非 sensitive のみ）

## 環境変数

| 変数 | 用途 | 注意 |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | プラグインインストールディレクトリへの絶対パス | プラグイン更新で**変更される**。状態を書き込まない |
| `${CLAUDE_PLUGIN_DATA}` | 更新後も保持される永続ディレクトリ（`~/.claude/plugins/data/{id}/`）| node_modules、キャッシュ等。最初の参照時に自動作成 |

`${CLAUDE_PLUGIN_ROOT}/` を MCP / hooks / LSP のコマンドパスで使うこと（絶対パス禁止）。永続データは `${CLAUDE_PLUGIN_DATA}/` に書く。

## マーケットプレイス配布（scaffold 用の最小形）

`marketplace.json` で各プラグインのエントリを宣言する。plugin-dev が生成する最小形:

```json
{
  "name": "marketplace-name",
  "owner": { "name": "Team", "email": "team@example.com" },
  "metadata": { "pluginRoot": "./plugins" },
  "plugins": [
    { "name": "plugin-name", "source": "./plugins/my-plugin", "version": "1.0.0" }
  ]
}
```

- `source` は相対パスのほか github / url / git-subdir / npm / pip を取れる。各ソースは `ref`（ブランチ/タグ）と `sha` でピン止め可能。
- `strict`（既定 `true`）: plugin.json がコンポーネント定義の権限、エントリが補完。`false` ではエントリが全定義。
- 6 種のソース形式・install スコープ（user / project / local / managed）・CLI コマンドの全仕様は公式リファレンスを正本とする: https://code.claude.com/docs/en/plugins-reference

scaffold で頻出する CLI:

```bash
claude plugin validate .                       # 構文・スキーマ検証
claude --plugin-dir ./my-plugin                # ローカルテスト
claude plugin install <plugin>[@marketplace]   # 配布
```

公式提出: https://claude.ai/settings/plugins/submit
