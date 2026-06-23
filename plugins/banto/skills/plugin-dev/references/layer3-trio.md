# Layer 3 trio — skill + rule + hook scaffold

When creating a new skill, design it as a **skill + rule + hook trio** along the Layer 3 harness-engineering framework. Completing it with a skill alone hits the ceiling of probabilistic compliance, and after deployment you get accidents like "I wrote it in a rule but it isn't followed" (AGENTIF: tool constraint 43.2%).

## When to use the trio

If the skill contains any of the following, also consider the corresponding rule and hook:

| Nature of the skill | rule candidate | hook candidate |
|------------|----------|----------|
| A procedure meaningful only for a specific file type | path-scoped rule (clarifying the operation context) | PreToolUse Write|Edit (the relevant path matcher) |
| The ordering constraint "always X before Y" | behavioral-principle rule (the intent of the procedure) | check in PreToolUse, block if not executed |
| Dangerous operation (git push / .env exposure / rm -rf) | warning rule (human-readable warning) | PreToolUse Bash / permissions.deny |
| External API call | auth / rate-limit warning rule | log / monitor in PostToolUse |

If the skill's logic is **entirely a high-level concept** and "unrelated to file type or command type", the trio is overkill. The skill alone is fine.

## Role of each component (the 4-quadrant matrix, restated)

```
                  rule (paths:)      skill (description)     hook (matcher + exit 2)
                  ────────────────────────────────────────────────────────────────
Injection trigger  path match          description match        tool match (deterministic)
Enforcement        none (probabilistic) none (probabilistic)    yes (blocks with exit 2)
Expression grain   declarative (guide)  procedural (steps)       procedural (pre/post check)
Compliance (study) 43% (AGENTIF)        medium (skill-routing accuracy) 90-100% (AgentSpec)
```

**Selection principles**:
1. **Irreversible / legal impact / security** → hook mandatory (a rule is too weak)
2. **Context meaningful for a specific file** → path-scoped rule (avoid always-on injection)
3. **The procedure itself / multiple steps** → skill (writing it as a rule is verbose)

## scaffold procedure (recommended)

### Step 1: Classify the essence of the skill

```
Questions:
- What does this skill want to keep "unchanged"? (→ hook candidate)
- Which file type / command type is it tied to? (→ path-scope or hook matcher)
- Is there value in writing the description (rule) and the procedure (skill) separately?
```

### Step 2: Generate the 3 files simultaneously

#### rule template (path-scoped recommended)

`templates/rules/{topic}.md`:

```markdown
---
paths:
  - "**/*.{ext1,ext2}"     # relevant file types
  - "src/{domain}/**"      # relevant directory
---

# {Topic} rule

Principles applied when editing {topic} (conditionally injected, path-scoped).

- {principle 1}
- {principle 2}

For the detailed procedure, see the skill (`/skills/{skill}/SKILL.md`).
Deterministic enforcement via hook is `hooks/{topic}-guard.sh`.
```

#### skill template (procedure)

`skills/{skill}/SKILL.md`:

```markdown
---
name: {skill}
description: "..."
allowed-tools: Read Write Edit Bash Agent
---

# {Skill}

## Layer 3 related files
- Behavioral principle: `templates/rules/{topic}.md` (path-scoped)
- Enforcement check: `hooks/{topic}-guard.sh` (PreToolUse)

## Procedure
...
```

#### hook template (PreToolUse / PostToolUse)

`hooks/{topic}-guard.sh`:

```sh
#!/bin/sh
# {Topic} Guard Hook — deterministic enforce
# Reinforces the probabilistic compliance of the rule (templates/rules/{topic}.md).

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# path check
case "$FILE_PATH" in
    *.ext1|*.ext2|src/{domain}/*)
        # violation check
        if {violation condition}; then
            echo "[Hook] {violation detail}" >&2
            exit 2  # block
        fi
        ;;
esac
exit 0
```

Register in `hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/{topic}-guard.sh", "timeout": 3 }
        ]
      }
    ]
  }
}
```

## Judging to avoid an unnecessary trio

The following cases are **fine with a minimal setup (skill alone or rule alone)**:

- Lightweight utility skill (typo fix, format conversion, status display) — neither rule nor hook needed
- A single-file-type skill where making a hook is technically difficult (requires prompt analysis, etc.) — skill + path-scoped rule only
- Conceptual / educational behavioral principles ("conclusion first", etc.) — rule only (cannot be made a hook)

When in doubt, **create the skill only → add rule / hook later if operation demands it** is fine. Don't make the trio mandatory (avoid over-engineering).

## scaffold checklist

When creating a new skill, ask yourself:

- [ ] Is this skill tied to a specific file type? → if YES, co-ship a path-scoped rule
- [ ] Does it contain "always X" / "never Y"? → if YES, consider making a hook
- [ ] Is it a prohibition expressible via permission.deny? → if YES, permissions are lighter than a hook
- [ ] Is the skill description ≤50 words in Use-when form? (Axis 3)
- [ ] Did you attach `paths:` to the rule to avoid always-on injection? (Axis 9)
- [ ] If you make a hook, did you register it in hooks.json?

## Coordination with plugin-audit

After creating the trio, run `/plugin-audit` to verify. The canonical source for the check axes (Axis 9 `rule_should_path_scope` / `rule_hard_constraint`, Axis 5 HeavySkill misapplication, etc.) is `skills/plugin-audit/references/scoring.md`.
