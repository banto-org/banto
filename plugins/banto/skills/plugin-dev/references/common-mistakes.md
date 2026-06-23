# Common mistakes

## Structure (from the official Warning)

Quote of the official Plugins page Warning:
> "Do not place `commands/`, `agents/`, `skills/`, or `hooks/` inside the `.claude-plugin/` directory. Only `plugin.json` goes inside `.claude-plugin/`."

1. **Placing under `.claude-plugin/skills/`** → not loaded. Put it directly under the plugin root
2. **`rules/` inside the plugin** → outside the official spec. banto's choice is to put it in `templates/rules/` and distribute it via an install script
3. **Creating new ones under commands/** (not officially recommended) → new plugins should use `skills/`. Existing commands keep working (if a skill with the same name exists, the skill takes priority). To migrate: `mkdir -p skills/{name}` → `mv commands/{name}.md skills/{name}/SKILL.md` → `/reload-plugins`
4. **Top-level `themes` / `monitors`** → warned (deprecated in the future). Use `experimental.themes` / `experimental.monitors`
5. **A `CLAUDE.md` at the plugin root** → **not loaded** from a plugin (officially stated). Provide context via skills / agents / hooks

## SKILL.md frontmatter

Official spec:

6. **description over 1,024 chars** (Open Standard limit) → shorten, or split with when_to_use (up to 1,536 chars combined)
7. **description + when_to_use combined over 1,536 chars** → display truncation occurs; Claude cannot auto-fire its decision
8. **First-person description** → "I can help..." ❌, third person "Helps users..." ✓
9. **allowed-tools comma-separated** → outside the official spec. Use space-separated or a YAML array
10. **`version` field** → not in the official spec for SKILL.md frontmatter (plugin.json only)

### Items that were mistakenly written in old versions (corrected)

- ❌ Old: "`when_to_use` is officially unsupported, Claude ignores it"
  → ✓ **Officially supported**. Counts toward the 1,536-char cap combined with description
- ❌ Old: "Delete `license` / `metadata` / `compatibility`"
  → ✓ **Open Standard core fields**. Keep them for 30+ tool compatibility
- ❌ Old: "description 250-char limit"
  → ✓ **1,024 chars (Open Standard) / 1,536 chars (combined)**

## Hooks

From the official plugins-reference Common issues:

11. **`echo "$INPUT" | jq`** (PostToolUse) → risk of shell expansion via `$()` inside content. **A temp file is mandatory**
12. **Blocking with `exit 1`** → use **`exit 2`** to block. `exit 1` is a non-blocking error
13. **Absolute path in a hook script** → use `${CLAUDE_PLUGIN_ROOT}`
14. **Lowercase matcher** → `bash` ❌, `Bash` ✓ — tool names and event names are all case-sensitive
15. **A matcher on an event that does not support matchers** → `UserPromptSubmit`, `Stop`, `PostToolBatch`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `CwdChanged`, `WorktreeCreate/Remove`, etc. take no matcher
16. **No execute permission on the hook script** → `chmod +x hooks/*.sh` is mandatory
17. **Secret exposure via `bash -x` / `set -x` / `env`** → `.env` values appear in the trace and remain in chat history. `echo` only the individual variable with explicit masking

## .mcp.json

18. **Specifying command with an absolute path** → stops working on plugin update. Use `${CLAUDE_PLUGIN_ROOT}/...`
19. **Writing persistent data to `${CLAUDE_PLUGIN_ROOT}`** → erased on plugin update. Use `${CLAUDE_PLUGIN_DATA}` for persistence
20. **Specifying `command` while using something other than `type: stdio` (default)** → http/sse/ws use `url`

## Plugin Agent

21. **Writing `hooks` / `mcpServers` / `permissionMode` in a plugin agent** → **completely ignored** for security (official sub-agents Note). If they are needed, distribute to `~/.claude/agents/` or `.claude/agents/`

## Distribution

22. **Updating a plugin without bumping version** → does not reach existing users due to caching (official: "follow semantic versioning when using an explicit version")
23. **An unknown key in `plugin.json`** → ignored without warning
24. **Not running `claude plugin validate`** → miss syntax errors and schema violations
25. **No CHANGELOG.md** → the official recommendation is "document changes in `CHANGELOG.md`"

## Design anti-patterns

26. **Not using the HeavySkill 4-component for a complex workflow skill** → complex judgment degrades with a simple list-form procedure (source: arxiv 2605.02396)
27. **Making a side-effect workflow auto-fireable** → for truly irreversible, outward side effects (`push` / `deploy` / `send`, etc.), consider `disable-model-invocation: true` (official Skills page).
    **But intent-first takes priority** (the North Star "every feature is reachable in natural language"): DMI is an **exception**, not the default. A workflow that can be made non-destructive (read-only audit / requiring `--refresh` for overwrites / built-in human gate / approval-based) should be **published via "narrow intrinsic NL triggers + safety boundaries", not DMI**, as a principle. When attaching/keeping DMI, an explicit reason of "irreversibility OR inseparable collision with high-frequency vocabulary" is mandatory (a reasonless DMI produces an H-1-type undiscoverable defect)
28. **`context: fork` on reference content** → official Warning:
    > "`context: fork` is only meaningful for skills that contain explicit instructions. If a skill contains guidelines such as 'use these API conventions' with no task, the subagent receives the guidelines but has no executable prompt and returns with no meaningful output."
