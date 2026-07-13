---
name: plugin-dev
description: |
  Support creating or refactoring a Claude Code plugin or a single skill. Scaffolds a skill / plugin / hook based on official best practices, or refactors an existing skill (`refactor <skill-path>`). INVOKES: works with the plugin-audit skill for quality scoring.
  Triggers: "create a plugin", "make a skill", "write a hook", "refactor a skill", "plugin", "SKILL.md", "hooks.json", "plugin.json"
  Do not use when: making a simple single-file configuration change — skip this skill, a direct Edit is sufficient.
user-invocable: true
argument-hint: "[plugin description / refactor skills/<name>]"
model: opus
allowed-tools: Read Write Edit Glob Grep Bash(mkdir:*) Bash(chmod:*) Skill
compatibility: Claude Code (requires bash, git, jq)
---

# Plugin Dev — Claude Code Plugin Development Support

Detailed reference material lives in `references/`. Read it only when needed.
Output language: respond in the conversation language (follow `writing-ja.md` for Japanese).

Official basis: https://code.claude.com/docs/en/plugins-reference (see also [`references/sources.md`](references/sources.md)).

## Standalone vs Plugin

| Criterion | Standalone (`.claude/`) | Plugin |
|---------|----------------------|---------|
| Skill name | `/hello` | `/plugin-name:hello` |
| Best for | Personal workflows, experiments | Team sharing, distribution |
| Sharing | Manual copy | `claude plugin install` |

**When in doubt**: experiment in `.claude/` → convert to a plugin.

## Mode detection (new / refactor)

If `$ARGUMENTS` starts with `refactor skills/<name>` or an existing skill path → **refactor mode** (below). Otherwise → new creation (Step 1 onward).

### Refactor mode (per-skill refactor)

Raise the quality of one existing skill:

1. Read the target SKILL.md + check usage with `plugin-audit-usage.sh --skill <path>`
2. Compare against the High criteria in `references/quality-scoring.md` (`USE FOR / DO NOT USE FOR / INVOKES`, ≤50-word routing, progressive loading)
3. Present improvement proposals (description rewrite / split into references/ / minimize allowed-tools = Axis 12)
4. Present the proposals as text and apply with Edit (post-hoc disclosure; stop only on a goal fork, e.g. a change that would alter trigger words / invocation routes)
5. After applying, re-verify with `plugin-audit skills/<name>` (per-skill audit)

Unlike new creation, the top priority is **not breaking existing trigger words and invocation routes** (backward compatibility).

## Step 1: Requirements interview

Confirm in text:
- Plugin name (kebab-case, max 64 characters)
- What it does
- Required components (skill/hook/agent/MCP)
- Distribution target (local / marketplace)

## Step 2: Directory structure

`.claude-plugin/` contains **plugin.json only**. Everything else goes directly under the plugin root.

```
{name}/
├── .claude-plugin/plugin.json   ← only this lives here
├── skills/{skill}/SKILL.md
├── agents/{agent}.md
├── hooks/hooks.json + *.sh
├── templates/rules/{topic}.md   ← path-scoped rule (Layer 3 trio candidate)
├── .mcp.json
├── settings.json                ← agent default settings (optional)
└── README.md
```

## Step 2.2: Layer 3 trio decision (skill + rule + hook)

If the new skill includes any of the following, decide whether to ship a **rule + hook** alongside it. Details: [`references/layer3-trio.md`](references/layer3-trio.md)

**Trio candidate signals**:
- Tied to specific file types (`*.ts` / `*.py` / `.env` / `package.json`, etc.) → add a **path-scoped rule**
- Contains "always X" / "never do Y" / "forbidden" → consider deterministic enforcement via a **hook (PreToolUse)**
- Expressible as a static prohibition (no push to main / no `cat` of `.env`) → **permissions.deny** is enough (lighter than a hook)

**Cases where the trio is unnecessary** (lightweight utility / conceptual behavioral principle / a procedure that completes within a single file type): see "Judging to avoid an unnecessary trio" in [`references/layer3-trio.md`](references/layer3-trio.md) for details.

**When in doubt, build the skill only → add the rest later if operation demands it** (avoid over-engineering).

## Step 2.5: Complexity check → HeavySkill applicability (AI automatic)

If the new skill matches any of the following, propose the **HeavySkill 4-component template**:

**Automatic criteria** (any single match qualifies):
- The description / purpose statement contains words like "complex", "decision", "analysis", "design", "deliberation", "comparison", "trade-off", "torn between", "multi-perspective", "consensus" (JP: 「複雑」「判断」「分析」「設計」「議論」「比較」「トレードオフ」「悩む」「迷う」「多視点」「合議」)
- The skill classification is `**WORKFLOW SKILL**`
- The input involves "choosing the best among multiple options", "satisfying conflicting constraints", or "making design decisions"
- The user explicitly mentions complex branching, multi-angle evaluation, or parallel reasoning (「複雑な分岐がある」「多角的に評価したい」「並列で考えたい」)

**Priority order for the decision**:
1. Explicit user request > automatic keyword match > skill classification
2. For simple utility / analysis skills (e.g. typo fixes, format conversion, status display), HeavySkill is **not applied**

**If it qualifies**: confirm in text:
- A: HeavySkill 4-component (heavier, higher quality, parallel + deliberation) → `references/heavyskill-template.md`
- B: Standard template (lightweight) → `references/skill-md.md`

**If it does not qualify**: proceed with the standard template (adopted interpretation).

Details: `references/heavyskill-template.md` (how to use the HeavySkill 4-component and its applicability criteria)

## Step 3: File generation

See references/ for detailed templates per component:

- plugin.json → [references/plugin-json.md](references/plugin-json.md)
- SKILL.md (standard) → [references/skill-md.md](references/skill-md.md)
- SKILL.md (HeavySkill 4-component) → [references/heavyskill-template.md](references/heavyskill-template.md)
- hooks.json + hook scripts (**common events + full 29 list**) → [references/hooks-json.md](references/hooks-json.md)
- .mcp.json → [references/mcp-json.md](references/mcp-json.md)
- agents/*.md (**plugin agent limitations apply**) → [references/agents.md](references/agents.md)
- commands/ is merged into skills/. Always create new ones in `skills/`.
- **Layer 3 trio (skill + rule + hook)** → [references/layer3-trio.md](references/layer3-trio.md)
- Quality scoring criteria → [references/quality-scoring.md](references/quality-scoring.md)
- Design patterns (invocation control / skill types / loop design) → [references/skill-design-patterns.md](references/skill-design-patterns.md)
- Common mistakes → [references/common-mistakes.md](references/common-mistakes.md)

### When creating a document-generating skill (special case)

When adding a **skill that saves documents** (`[Review] [QA] [Audit] [Status] [Design] [Guide] [Memo] [Index]`, etc.) to the plugin, do not implement it standalone — follow the common pattern:

1. Read `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md`
2. Decide whether it is Pattern A (agent-invoking) or B (fill-in template)
3. State at the top of the SKILL.md: "**Pattern A/B** — see `_common-pattern.md` for the shared skeleton"
4. Describe only skill-specific information (invoked agent / save prefix / mode branching / skill-specific template)
5. If a new prefix is needed, add it to the list in `ai-context/SKILL.md` (reflected in the hook-enforced list)
6. Add one line to the document-generation sections of `kit` / `README.md`

## Steps 4-6: Test / distribute / audit

```bash
# Local test
claude --plugin-dir ./{name}            # single
claude --plugin-dir ./a --plugin-dir ./b  # multiple at once

# Validate
claude plugin validate .

# Distribute
claude plugin install <plugin>[@marketplace] [--scope user|project|local]
```

- Applying changes: `/reload-plugins` (reloads all of skills / agents / hooks / MCP / LSP)
- semver required (`MAJOR.MINOR.PATCH`), document in `CHANGELOG.md`; without a version bump, caching prevents existing users from receiving updates
- Official submission: https://claude.ai/settings/plugins/submit
- Post-development audit: `/plugin-audit` for official compliance (Phases 1-8.5) + the 15-axis quality audit (Phase 9, see [`references/quality-scoring.md`](references/quality-scoring.md))

## Common mistakes

→ [references/common-mistakes.md](references/common-mistakes.md)

## References

For all official documentation and internal research URLs, see [`references/sources.md`](references/sources.md).
