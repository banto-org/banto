# hooks.json + hook script reference

Placement: `hooks/hooks.json` (directly under the plugin root)

It is **auto-merged** with settings.json when the plugin is enabled. No manual editing needed.

## Template

```json
{
  "description": "plugin description",
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

## Event list (29 events total)

The commonly-scaffolded events are summarized in the top section. For the full list of all 29 events and their detailed spec, the canonical source is the official hooks reference: https://code.claude.com/docs/en/hooks

### Commonly-scaffolded events

| Event | Fires | matcher? |
|---|---|---|
| `SessionStart` | Session start / resume (stdout added to context) | yes (`startup`/`resume`/`clear`/`compact`) |
| `UserPromptSubmit` | On prompt submit, before Claude processes (stdout added to context) | no |
| `PreToolUse` | Before a tool call. **Can block** (permissionDecision) | yes (tool name) |
| `PostToolUse` | After a tool succeeds | yes |
| `Stop` | When Claude completes a response | no |
| `PreCompact` | Before context compaction | yes (`manual`/`auto`) |
| `SessionEnd` | Session end | yes (`clear`/`resume`/`logout`/`other`, etc.) |

### Other events (matcher presence only)

| No matcher | Takes a matcher |
|---|---|
| `PostToolBatch`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `CwdChanged`, `WorktreeCreate`, `WorktreeRemove` | `Setup`, `UserPromptExpansion`, `PermissionRequest`, `PermissionDenied`, `PostToolUseFailure`, `Notification`, `StopFailure`, `SubagentStart`, `SubagentStop`, `InstructionsLoaded`, `ConfigChange`, `FileChanged`, `PostCompact`, `Elicitation`, `ElicitationResult` |

For each event's exact firing timing, matcher values, and stdin payload, see the official reference above.

## The 5 hook types

| Type | Description |
|---|---|
| `command` | Run a shell command / script |
| `http` | POST the event JSON to a URL |
| `mcp_tool` | Call a tool on a configured MCP server |
| `prompt` | Evaluate a prompt with an LLM (with `$ARGUMENTS` substitution) |
| `agent` | Agentic verifier for complex verification (experimental) |

## matcher pattern rules

Official original text:
> "`"*"`, `""`, or omitted → fires on every occurrence of the event
> Only letters, digits, `_`, `|` → exact match or a list of exact matches separated by `|`
> Containing other characters → evaluated as a JavaScript regular expression"

Examples:
- `"Bash"` ✓ — exact match on the Bash tool only
- `"Write|Edit"` ✓ — Write or Edit
- `"^Notebook"` — regex, all tools starting with Notebook
- `"mcp__memory__.*"` — all tools of the memory MCP server
- `"*"` or `""` — fires on all events
- `"bash"` ❌ — tool names are case-sensitive, `Bash` is correct

## hook options

```json
{
  "type": "command",
  "command": "...",
  "timeout": 600,             // seconds. defaults: command 600 / prompt 30 / agent 60
  "statusMessage": "Running...",
  "once": true                // only once per session (skill/agent only)
}
```

## Exit Code meanings

| Code | Meaning |
|------|------|
| `0` | Success. stdout is parsed as JSON or plain text. For `UserPromptSubmit`/`UserPromptExpansion`/`SessionStart`, stdout is added to Claude's context |
| **`2`** | **Blocking error**. stdout and JSON ignored, **stderr is fed back to Claude**. Has per-event effects |
| other | Non-blocking error. stderr is shown with `--debug` |

`PostToolUse`/`PostToolUseFailure` are non-blocking even with exit 2 (the tool already ran).
`StopFailure` **ignores** output and exit code.

## PreToolUse permissionDecision

Return `allow` / `deny` / `ask` / `defer` in the JSON output. Priority across multiple hooks:
**deny > defer > ask > allow**

```json
{
  "permissionDecision": "deny",
  "decisionReason": "Writing to the production DB is forbidden"
}
```

## Environment variables / stdin / stdout

| Variable / mechanism | Use |
|---|---|
| `$CLAUDE_PROJECT_DIR` | Project root |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin install directory |
| `${CLAUDE_PLUGIN_DATA}` | Persistent data directory |
| `$CLAUDE_ENV_FILE` | Available in SessionStart/Setup/CwdChanged/FileChanged |
| `$CLAUDE_EFFORT` | Current effort level |
| `$CLAUDE_CODE_REMOTE` | `"true"` in a remote Web environment |
| stdin | The event's JSON input |
| stdout | Processed only on exit 0. JSON or plain text (as `additionalContext`) |
| stderr | Error message (fed back to Claude on exit 2) |

## How to write a hook script

### PostToolUse hook (temp file mandatory)

```sh
#!/bin/sh
# Important: `echo "$INPUT" | jq` shell-expands $() inside content
# Always pass to jq via a temp file
command -v jq >/dev/null 2>&1 || exit 0
TEMP_INPUT=$(mktemp)
cat > "$TEMP_INPUT"
TOOL_NAME=$(jq -r '.tool_name // empty' "$TEMP_INPUT" 2>/dev/null)
FILE_PATH=$(jq -r '.tool_input.file_path // empty' "$TEMP_INPUT" 2>/dev/null)
CWD=$(jq -r '.cwd // empty' "$TEMP_INPUT" 2>/dev/null)
rm -f "$TEMP_INPUT"
# processing ...
exit 0
```

### UserPromptSubmit / SessionStart hook

```sh
#!/bin/sh
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
# processing ...
exit 0
```

## Anti-pattern (officially mentioned)

From the official hooks page AdditionalContext:
> "Write the text as factual statements, not as imperative system instructions. Phrases like 'the deploy target is production' or 'this repository uses bun test' are read as project information, rather than 'please deploy' (imperative). Text framed as an out-of-band system command may trigger Claude's prompt-injection defenses."

## Implementation notes

- Scripts must be granted execute permission with `chmod +x`
- POSIX-compatible shebang (`#!/bin/sh` or `#!/bin/bash`)
- Always use `${CLAUDE_PLUGIN_ROOT}` (no absolute paths)
- Disable shell tracing (to prevent secret exposure; avoid `bash -x`, etc.)
- Tool names and event names are all case-sensitive
