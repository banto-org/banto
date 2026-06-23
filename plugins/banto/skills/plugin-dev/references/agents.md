# agents/*.md reference

Placement: `agents/{name}.md` (directly under the plugin root)

## Template

```yaml
---
name: my-agent
description: |
  What the agent does (third person, in detail).
  use proactively when: when Claude should delegate.
  INVOKES: Read, Grep, WebSearch
model: sonnet
tools: Read, Grep, Glob, WebSearch
---

The body of the agent's system prompt.
```

Write the description **in detail** (official Tip). It is used for the delegation decision.
Phrases like **"use proactively"** encourage automatic delegation.

## All fields

### Required

| Field | Description |
|-----------|------|
| `name` | Unique identifier. lowercase alphanumeric + hyphen |
| `description` | The description Claude uses to decide whether to delegate the task |

### Recommended / optional

| Field | Description | Plugin restriction |
|-----------|------|:---:|
| `tools` | Allowed tools. When omitted, all are inherited. `Skill` preload is specified separately via `skills` | - |
| `disallowedTools` | Denied tools (applied first when used together with tools) | - |
| `model` | sonnet/opus/haiku/full-ID/`inherit` (default inherit) | - |
| `permissionMode` | default/acceptEdits/auto/dontAsk/bypassPermissions/plan | **❌ ignored** |
| `maxTurns` | Maximum number of turns | - |
| `skills` | Skills to preload at startup | - |
| `mcpServers` | MCP servers (inline or name reference) | **❌ ignored** |
| `hooks` | Agent-scoped hooks | **❌ ignored** |
| `memory` | `user` / `project` / `local` (persistent memory scope) | - |
| `background` | `true` for background execution | - |
| `effort` | low / medium / high / xhigh / max | - |
| `isolation` | `worktree` (git worktree isolation) | - |
| `color` | red/blue/green/yellow/purple/orange/pink/cyan | - |
| `initialPrompt` | Automatic initial prompt when launched with `--agent` | - |

## ⚠️ Plugin Agent restrictions (official original text)

> "For security reasons, plugin subagents do not support the `hooks`, `mcpServers`, or `permissionMode` frontmatter fields. These fields are ignored when loading an agent from a plugin. If you need them, copy the agent file to `.claude/agents/` or `~/.claude/agents/`."

→ In an agent distributed by a plugin, the three fields above are **completely ignored**. Validation should warn about it.
If they are genuinely needed, set up an install path that places the agent file separately in `.claude/agents/` or `~/.claude/agents/` (e.g. distribute via harness-setup.sh).

## Specifying Tools

### Allow-list form (`tools`)

```yaml
tools:
  - Read
  - Grep
  - Glob
  - Bash(git:*)         # pattern matching allowed
  - Skill(commit)       # a specific skill only
  - Agent(researcher)   # spawning a specific agent only
```

### Combined with a deny list (`disallowedTools`)

```yaml
tools: Read, Grep, Glob
disallowedTools: Write, Edit
```

### Agent tool access control

Specify the subagents that can be spawned via the `Agent(agent_type)` syntax as an allow list:

```yaml
tools: Agent(worker, researcher), Read, Bash
```

A bare `Agent` without parentheses removes all restrictions. Excluding it entirely from the list makes subagent spawning impossible (only meaningful for the main thread; a subagent cannot spawn other subagents).

## description best practice

Official sub-agents Tip:
> "**Design focused subagents**: each subagent should excel at one specific task
> **Write detailed descriptions**: Claude uses the description to decide whether to delegate
> **Limit tool access**: grant only the permissions needed, for security and focus
> **Check into version control**: share project subagents with your team"

Encouraging proactive delegation:
> "To encourage proactive delegation, include phrases like **'use proactively'** in the subagent's description field."

## description template (recommended form)

```yaml
description: |
  {what the agent does, third person, detailed}
  use proactively when: {situations A, B, C where it should be delegated}
  DO NOT USE FOR: {out-of-scope situations / distinction from another agent}
  INVOKES: Read / Grep / Glob / WebSearch (the concrete tools)
  FOR SINGLE OPERATIONS: {if simple, a direct tool is enough}
```

The recommended form that satisfies plugin-audit's quality axes.
