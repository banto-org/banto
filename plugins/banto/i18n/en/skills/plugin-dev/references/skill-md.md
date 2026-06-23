# SKILL.md reference

Placement: `skills/{name}/SKILL.md`

## All frontmatter fields

### Open Standard core (30+ tool support)

| Field | Required | Description |
|-----------|:---:|------|
| `name` | ◎ (Open Standard) | lowercase alphanumeric + hyphen, max 64 chars, matches the parent directory name |
| `description` | recommended | The skill's purpose and timing of use, max **1,024 chars** |
| `license` | | License identifier (Open Standard) |
| `compatibility` | | Environment requirements, max 500 chars (Open Standard) |
| `metadata` | | Arbitrary key-value map (Open Standard) |
| `allowed-tools` | | Allowed tools, space-separated or YAML array (Experimental) |

### Claude Code extensions

| Field | Description |
|-----------|------|
| `when_to_use` | Additional triggers. Counts toward **1,536 chars** combined with description |
| `argument-hint` | Autocomplete display for `/skill [argument hint]` |
| `arguments` | Named arguments (space-separated or YAML). Expanded with `$name` |
| `disable-model-invocation` | `true` forbids Claude auto-fire (explicit invocation `/name` only) |
| `user-invocable` | `false` hides from the `/` menu (Claude-only launch) |
| `model` | sonnet/opus/haiku/full-id/`inherit` |
| `effort` | low / medium / high / xhigh / max (max is Opus only) |
| `context` | `fork` for separated subagent execution |
| `agent` | The agent type when `context: fork` (Explore / Plan / general-purpose, etc.) |
| `paths` | Auto-fire condition by glob pattern (comma-separated or YAML array) |
| `hooks` | Skill-scoped lifecycle hook definitions |
| `shell` | `bash` (default) or `powershell` |

**Important corrections (misinformation from old audits)**:
- `when_to_use` is **officially supported** (old versions wrote "Claude ignores it", which is wrong)
- `license` / `metadata` / `compatibility` **should not be deleted** (Open Standard core, compatible-tool support)
- The description char cap is **1,024 chars (Open Standard) / 1,536 chars (combined)** (old versions' 250 chars is wrong)

## description char count

| Limit | Value |
|------|----|
| description alone | ≤ **1,024 chars** (Open Standard limit) |
| description + when_to_use combined | ≤ **1,536 chars** (Claude Code display-truncation boundary) |
| all-skills combined dynamic budget | **1%** of the context, fallback **8,000 chars** |

Keeping it short improves auto-fire decision accuracy. Aim for 100–500 chars, concisely packing trigger / exclusion / INVOKES.

## Templates (recommended forms)

### Normal skill (both auto-fire + user invocation)

```yaml
---
name: {skill-name}
description: |
  **{WORKFLOW SKILL | UTILITY SKILL | ANALYSIS SKILL}** — {what it does, third person}.
  USE FOR: {main triggers A, B, C}
  DO NOT USE FOR: {exclusion conditions / distinction from another skill}
  INVOKES: {dependency tools / agent / command}
  FOR SINGLE OPERATIONS: {for a simple operation, a direct tool is enough}
user-invocable: true
allowed-tools: Read Grep Glob
---

# {Skill Title}

If $ARGUMENTS is given, use it as the input.

## Procedure
1. ...
2. ...
```

### Explicit-invocation-only skill (side-effect workflow)

```yaml
---
name: {skill-name}
description: |
  **WORKFLOW SKILL** — {what it does}. Explicit invocation only via /{skill-name}.
  INVOKES: {dependency agent}
  FOR SINGLE OPERATIONS: {if simple, another approach}
user-invocable: true
disable-model-invocation: true
argument-hint: "[argument hint]"
allowed-tools: Read Write Bash Agent
---
```

Design guideline: side-effect workflows such as commit / deploy / send are recommended to use `disable-model-invocation: true` (official Skills page).

### Background-knowledge skill (Claude-only launch)

```yaml
---
name: {skill-name}
description: "{what it does, auto-referenced by Claude}"
user-invocable: false
---
```

## skill classification prefix (recommended)

The classification tag written at the top of the description / body:

| Prefix | Use |
|---|---|
| `**WORKFLOW SKILL**` | Multi-step orchestration (spec, research) |
| `**UTILITY SKILL**` | Single-purpose helper (status, save-checkpoint, ws) |
| `**ANALYSIS SKILL**` | Read-only analysis (search, plugin-audit, harness-audit) |

Not in the official spec, but it helps with search, visualization, and design decisions.

## description tips

- description alone ≤ 1,024 chars, combined (including when_to_use) ≤ 1,536 chars
- Third person ("I can help..." ❌, "Helps users..." ✓)
- HeavySkill 4-block pattern:
  - `USE FOR:` or "トリガー：" → main firing conditions (multiple)
  - `DO NOT USE FOR:` or "使ってはいけない場面：" → exclusion conditions
  - `INVOKES:` or "依存：" → tools / agents to call
  - `FOR SINGLE OPERATIONS:` or "単純な〜なら〜で十分" → single-operation distinction
- Keep sentences short, use line breaks to visualize structure

## Template variables

| Variable | Description |
|-----|------|
| `$ARGUMENTS` | All text after `/skill-name` |
| `$ARGUMENTS[0]` or `$0` | First argument (shell-style quoting supported) |
| `$ARGUMENTS[1]` or `$1` | Second argument |
| `$name` | A named argument declared in the `arguments` frontmatter |
| `${CLAUDE_SESSION_ID}` | Session ID |
| `${CLAUDE_EFFORT}` | Current effort level |
| `${CLAUDE_SKILL_DIR}` | The SKILL.md directory path |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin install directory |
| `${CLAUDE_PLUGIN_DATA}` | Plugin persistent data directory |

## Dynamic context injection `` !`command` ``

Run a shell command **before** the skill loads and substitute the output into the placeholder:

```yaml
## Current changes
!`git diff HEAD`
```

Multiple lines use a fenced code block opened with ``` ```! ```:
````markdown
```!
node --version
git status --short
```
````

Disable: `"disableSkillShellExecution": true`

## Namespace

- Inside a plugin: `/<plugin-name>:<skill-name>`
- Standalone: `/<skill-name>`

## supporting files (handling over 500 lines, token warnings)

```
skills/{name}/
├── SKILL.md          ← overview (within 500 lines, token warn=500/hard=1000)
├── references/       ← details (Read only when needed)
│   ├── api.md
│   └── examples.md
└── scripts/          ← executable scripts
```

Nesting is one level only (SKILL.md → reference.md is OK, reference → detail is NG).

## HeavySkill 4-component (recommended for complex workflow skills)

Skills involving complex reasoning / judgment adopt the HeavySkill 4-component (Activation Conditions / Parallel Protocol / Deliberation / Output Constraints). See `references/heavyskill-template.md` for the canonical template and applicability criteria.

## Self-describing schema (reference, not adopted)

The `metadata: { role, parent, children }` structure derived from the AFFiNE Block is conceptually powerful, but it is outside the Claude Code skill frontmatter spec, so it is not adopted in this plugin. It can be reconsidered within the Open Standard `metadata` key when the plugin is extended in the future.
