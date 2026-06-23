# plugin.json reference

Placement: `.claude-plugin/plugin.json`

**Important**: `.claude-plugin/` holds **only plugin.json**. Other directories (commands/, agents/, skills/, hooks/) go directly under the plugin root. Note: the manifest itself is optional; when omitted, Claude Code auto-detects components from default locations (deriving the plugin name from the directory name).

## Template (minimal)

```json
{
  "name": "{name}"
}
```

Only `name` is required.

## Template (recommended)

```json
{
  "name": "{name}",
  "version": "1.0.0",
  "description": "{what the plugin does}",
  "author": { "name": "{author}" },
  "homepage": "https://github.com/{owner}/{repo}",
  "repository": "https://github.com/{owner}/{repo}",
  "license": "MIT",
  "keywords": ["{keyword1}", "{keyword2}"]
}
```

## All fields (from the official plugins-reference)

### Standard metadata

| Field | Required | Description |
|-----------|:---:|------|
| `name` | ✓ | Unique identifier. Prefix of the skill namespace (`/name:skill`) |
| `$schema` | | For editor completion; Claude Code ignores it on load |
| `version` | | semver. Setting it pins; when omitted the git commit SHA is the fallback |
| `description` | | Shown in the plugin manager UI |
| `author` | | `{name, email, url}` |
| `homepage` | | Project URL |
| `repository` | | Git repository URL |
| `license` | | License (MIT, etc.) |
| `keywords` | | Array of search keywords |

### Component paths (custom path specification)

| Field | Default | Path behavior |
|-----------|----------|---------|
| `skills` | `skills/` | string\|array. **Add** |
| `commands` | `commands/` | string\|array. **Replace** |
| `agents` | `agents/` | string\|array. **Replace** |
| `hooks` | `hooks/hooks.json` | string\|array\|object. **Merge** |
| `mcpServers` | `.mcp.json` | string\|array\|object. **Merge** |
| `lspServers` | `.lsp.json` | string\|array\|object. **Merge** |
| `outputStyles` | `output-styles/` | **Replace** |

### Experimental fields (officially recommended placement)

```json
{
  "experimental": {
    "themes": "./themes/",
    "monitors": "./monitors.json"
  }
}
```

The old top-level `themes` / `monitors` still work but warn under `claude plugin validate`; `experimental.*` will be required in the future.

### User config / channels / dependencies

| Field | Description |
|-----------|------|
| `userConfig` | Settings prompted when the plugin is enabled. `type/title/description/sensitive/required/default/multiple/min/max` |
| `channels` | Channel declarations for message injection (Telegram/Slack/Discord style) |
| `dependencies` | semver dependencies on other plugins (e.g. `~2.1.0`) |

## userConfig example

```json
{
  "userConfig": {
    "api_token": {
      "type": "string",
      "title": "API token",
      "description": "API authentication token",
      "sensitive": true,
      "required": true
    },
    "max_results": {
      "type": "number",
      "title": "Max results",
      "default": 10,
      "min": 1,
      "max": 100
    }
  }
}
```

- Non-sensitive → saved in `settings.json`'s `pluginConfigs`
- sensitive → system keychain (~2KB limit)
- Expanded into the subprocess via the environment variable `CLAUDE_PLUGIN_OPTION_<KEY>`
- Referenced inside a skill as `${user_config.KEY}` (non-sensitive only)

## Environment variables

| Variable | Use | Note |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the plugin install directory | **Changes** on plugin update. Do not write state |
| `${CLAUDE_PLUGIN_DATA}` | Persistent directory retained across updates (`~/.claude/plugins/data/{id}/`) | node_modules, cache, etc. Auto-created on first reference |

Use `${CLAUDE_PLUGIN_ROOT}/` for MCP / hooks / LSP command paths (no absolute paths). Write persistent data to `${CLAUDE_PLUGIN_DATA}/`.

## Marketplace distribution (minimal form for scaffolding)

Declare each plugin's entry in `marketplace.json`. The minimal form plugin-dev generates:

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

- Besides a relative path, `source` can be github / url / git-subdir / npm / pip. Each source can be pinned with `ref` (branch/tag) and `sha`.
- `strict` (default `true`): plugin.json is the authority for component definitions and the entry supplements it. With `false`, the entry is the full definition.
- For the full spec of the 6 source forms, install scopes (user / project / local / managed), and CLI commands, the canonical source is the official reference: https://code.claude.com/docs/en/plugins-reference

CLI commonly used in scaffolding:

```bash
claude plugin validate .                       # syntax / schema validation
claude --plugin-dir ./my-plugin                # local test
claude plugin install <plugin>[@marketplace]   # distribute
```

Official submission: https://claude.ai/settings/plugins/submit
