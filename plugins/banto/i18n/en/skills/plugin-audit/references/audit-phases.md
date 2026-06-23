# Audit Phase Details (Phases 1-8.5)

## Phase 1: Verify the directory structure

```
1. Does .claude-plugin/plugin.json exist?
2. Are there any components other than plugin.json inside .claude-plugin/ (misplacement)?
3. Are skills/, agents/, hooks/, commands/, .mcp.json, .lsp.json located directly under the plugin root?
4. Are there unofficial directories (rules/, mcp-servers/, etc.)? → warn
```

## Phase 2: Validate plugin.json

```
1. name field present (required)
2. version, description, author recommended fields
3. detection of unofficial fields
4. use of experimental.themes / experimental.monitors (the old top-level themes/monitors is a warning)
```

## Phase 3: SKILL.md frontmatter audit

For each `skills/*/SKILL.md`:

**Required checks**:
- [ ] `name` field present (lowercase alphanumerics + hyphens, max 64 chars, matches the parent directory name)
- [ ] `description` field present
- [ ] `description` ≤ **1,024 chars** (Open Standard limit)
- [ ] `description + when_to_use` combined ≤ **1,536 chars** (Claude Code display-cut boundary)
- [ ] `description` is third-person ("I can..."/"You can..." is NG)
- [ ] unless `disable-model-invocation: true`, `description` contains trigger wording such as "Use when"

**Official field list (Open Standard + Claude Code extensions)**:

| Field | Category | Purpose |
|---|---|---|
| `name` | Open Standard | Identifier |
| `description` | Open Standard | Auto-firing decision |
| `license` | Open Standard | License |
| `compatibility` | Open Standard | Environment requirements (≤ 500 chars) |
| `metadata` | Open Standard | Arbitrary key-value |
| `allowed-tools` | Open Standard (Experimental) + Claude Code | Permitted tools |
| `when_to_use` | Claude Code | Additional triggers (combined with description, 1,536 chars) |
| `argument-hint` | Claude Code | Autocomplete |
| `arguments` | Claude Code | Named arguments |
| `disable-model-invocation` | Claude Code | Disable auto-firing |
| `user-invocable` | Claude Code | `/` menu control |
| `model` / `effort` | Claude Code | Model / effort level |
| `context` / `agent` | Claude Code | Subagent isolation |
| `hooks` | Claude Code | Lifecycle hook |
| `paths` | Claude Code | Selective activation via glob pattern |
| `shell` | Claude Code | bash / powershell |

**Important corrections (misinformation from the old audit)**:
- `when_to_use` is **officially supported** (the old audit wrongly treated it as "ignored by Claude")
- `license` / `metadata` / `compatibility` are **Open Standard core fields**. They should not be deleted
- `version` is outside the official SKILL.md frontmatter spec (plugin.json only)

**allowed-tools format**:
- ✓ Space-separated: `allowed-tools: Read Grep Glob`
- ✓ YAML array: `allowed-tools: ["Read", "Grep", "Glob"]` or block form
- ❌ Comma-separated: `allowed-tools: Read, Grep, Glob` (outside the official spec)

## Phase 4: SKILL.md body audit

- [ ] Within 500 lines (if exceeded, recommend splitting into reference.md etc.)
- [ ] No human-facing marketing wording ("Overview", "Why this approach", etc.)
- [ ] Imperative (action-oriented)
- [ ] Prohibitions emphasized with `NEVER` / `ALWAYS`

## Phase 5: hooks/hooks.json audit

- [ ] `hooks/hooks.json` present (if it has hooks)
- [ ] Uses `${CLAUDE_PLUGIN_ROOT}` (no absolute paths)
- [ ] matcher casing is correct (`Bash` ✓, `bash` ❌, `Edit|Write` ✓)
- [ ] No matcher written for events that do not support one (UserPromptSubmit, PostToolBatch, Stop, TaskCreated etc. take no matcher)
- [ ] Hook scripts have execute permission (`chmod +x`)
- [ ] POSIX-compatible (`#!/bin/sh` or `#!/bin/bash`)

**29 official events**:
SessionStart / Setup / UserPromptSubmit / UserPromptExpansion / PreToolUse / PermissionRequest / PermissionDenied / PostToolUse / PostToolUseFailure / PostToolBatch / Notification / SubagentStart / SubagentStop / TaskCreated / TaskCompleted / Stop / StopFailure / TeammateIdle / InstructionsLoaded / ConfigChange / CwdChanged / FileChanged / WorktreeCreate / WorktreeRemove / PreCompact / PostCompact / Elicitation / ElicitationResult / SessionEnd

**5 hook types**: `command` / `http` / `mcp_tool` / `prompt` / `agent`

**Exit code**:
- `0` → success (stdout parsed as JSON or plain text)
- `2` → blocking error (stderr fed back to Claude)
- other → non-blocking

## Phase 6: .mcp.json audit

- [ ] If providing MCP servers, is `.mcp.json` at the plugin root
- [ ] Paths specified with `${CLAUDE_PLUGIN_ROOT}` (no absolute paths)
- [ ] `type` field: `stdio` (default) / `http` (= `streamable-http`) / `sse` (deprecated) / `ws`
- [ ] Use of environment-variable expansion `${VAR:-default}`
- [ ] Persistent data written to `${CLAUDE_PLUGIN_DATA}` (`${CLAUDE_PLUGIN_ROOT}` is wiped on update)

## Phase 7: commands/*.md audit

The official phrasing is **"merged into skills"** ("legacy" / "deprecated" are not written officially). New plugins should use `skills/`, but existing commands continue to work.

- [ ] frontmatter is fully compatible with SKILL.md
- [ ] If a skill of the same name exists, the skill takes precedence
- [ ] For new plugins, create under skills/ rather than commands/ (official recommendation)

## Phase 8: Detect unofficial / experimental components

**Outside Open Standard / the official spec**:
- `rules/` → not integrated into the official plugin system. banto's choice is to place them under `templates/rules/` and distribute via the install script
- `mcp-servers/` → placing the implementation itself is OK; reference it from `.mcp.json` as `${CLAUDE_PLUGIN_ROOT}/mcp-servers/...`

**Experimental fields (plugin.json)**:
- `experimental.themes` / `experimental.monitors` → officially recommended (old top-level `themes` / `monitors` are warned, deprecated in future)
- `channels` / `dependencies` / `userConfig` → documented officially

## Phase 8.5: Plugin agent limitation checks (important)

If `agents/*.md` uses the following fields, they are **ignored for plugin agents** (per the official sub-agents Note, for security reasons):

- `hooks` → ignored
- `mcpServers` → ignored
- `permissionMode` → ignored

If these are needed, a separate distribution path is required — copy the agent file into `.claude/agents/` or `~/.claude/agents/`.
