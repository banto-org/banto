# .mcp.json reference

Placement: `.mcp.json` (directly under the plugin root)

It is **auto-registered** when the plugin is enabled. No `claude mcp add` needed.

## stdio type template (command execution)

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

## HTTP / SSE / WS type template

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

## The type field

| Value | Use |
|---|---|
| `stdio` | Default. Command-execution type |
| `http` (= `streamable-http`) | HTTP communication |
| `sse` | Server-Sent Events (**deprecated**) |
| `ws` | WebSocket |

Official statement:
> "The `type` field accepts `streamable-http` as an alias for `http`. Since the MCP spec uses the name `streamable-http` for this transport, configurations copied from server documentation work without changes."

## Choosing between environment variables

| Variable | When to use |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | Reference to a plugin-bundled binary / script / config |
| `${CLAUDE_PLUGIN_DATA}` | Storage destination for persistent data (DB / cache / node_modules) |
| `${VAR:-default}` | Environment-variable expansion with a fallback |

`${CLAUDE_PLUGIN_ROOT}` **changes** on plugin update, so do not write state to it. Always use `${CLAUDE_PLUGIN_DATA}` for persistence.

Example:
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

## Optional fields

| Field | Use |
|---|---|
| `command` | Command to run (stdio type) |
| `args` | Command arguments |
| `env` | Environment variables |
| `cwd` | Working directory |
| `url` | Endpoint URL (http/sse/ws) |
| `headers` | HTTP headers (http/sse/ws) |
| `headersHelper` | Path to a header-generation helper script |
| `alwaysLoad` | `true` to bypass tool search |
| `oauth` | OAuth config (`clientId`/`callbackPort`/`scopes`/`authServerMetadataUrl`) |

## OAuth

The `oauth` field (`clientId` / `callbackPort` / `scopes` / `authServerMetadataUrl`) configures authentication for an http-type server. For a complete example, see the official MCP reference: https://code.claude.com/docs/en/mcp

## Rules

- Reference the plugin root with `${CLAUDE_PLUGIN_ROOT}` (no absolute paths)
- Use `${CLAUDE_PLUGIN_DATA}` for persistence
- Relative paths starting with `./` must not reference outside the plugin root (path-traversal restriction)
- If a required variable is unset and has no default, parsing fails
- Multiple MCP servers can be defined in a single `.mcp.json`
- The MCP implementation body (server.py, etc.) can be placed in any directory inside the plugin (convention: `mcp-servers/{name}/`)
