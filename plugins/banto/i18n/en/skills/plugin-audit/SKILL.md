---
name: plugin-audit
description: |
  Audit an existing Claude Code plugin, or a single skill, against official best practices; detect inconsistencies and propose fixes. A plugin path or a skill path can be passed as the argument (per-skill audit).
  Triggers: "audit this plugin", "check this skill's quality", "review the SKILL.md against best practices", "score this skill". Also invocable via /plugin-audit. The audit itself is read-only; applying fixes requires user approval.
  Do not use when: auditing the harness as a whole system (harness-audit), generating / refactoring a plugin (plugin-dev), or auditing a single skill from a context-engineering angle such as information minimality (skill-audit).
user-invocable: true
argument-hint: "[eval|verify|fix|global] [plugin path or skills/<name> (defaults to the current directory)]"
allowed-tools: Read Write Edit Glob Grep Bash Agent
compatibility: Claude Code (requires bash, git, jq)
---

# Plugin Audit — Official Best-Practice Audit for Plugins

Output language: respond in the conversation language (follow `writing-ja.md` for Japanese).

> **Division of meta-audit responsibilities**:
> - **plugin-audit (this skill)** = **quality** audit of a plugin / single skill (official compliance + 15-axis structural evaluation). Pass `skills/<name>` as the argument for a per-skill audit.
> - **skill-audit** = a **context-engineering** audit scoped to a single skill (7 axes: information minimality / leakage of human-only information / division of labor in structure / execution-model directive / context efficiency / stated-AI consistency / division of labor with determinism). Narrower than plugin-audit's 15-axis quality audit — a separate skill focused on whether execution gets only the information it needs.
> - **harness-audit** = **whole-system** audit of the harness (philosophy alignment / dead features / currency / installation policy / Claude feature alignment). A separate layer that catches "skill quality is perfect but the feature is dormant or drifted = still broken".
> - **plugin-dev** = generation and refactoring (audit is delegated to plugin-audit).

The argument `$ARGUMENTS` specifies the plugin path. If omitted, search the current directory or under `plugins/`.

Official basis: https://code.claude.com/docs/en/plugins-reference

## Audit procedure

### Phases 1-8.5: Official compliance checks

See [`references/audit-phases.md`](references/audit-phases.md) for the details of each phase:

- **Phase 1**: Directory structure
- **Phase 2**: plugin.json (including experimental.* placement)
- **Phase 3**: SKILL.md frontmatter (official 18 fields, character caps 1,024/1,536)
- **Phase 4**: SKILL.md body (within 500 lines)
- **Phase 5**: hooks/hooks.json (29 event types, 5 hook types)
- **Phase 6**: .mcp.json (${CLAUDE_PLUGIN_ROOT} / ${CLAUDE_PLUGIN_DATA})
- **Phase 7**: commands/*.md (merged into skills)
- **Phase 8**: Unofficial / experimental components
- **Phase 8.5**: Plugin agent limitations (hooks / mcpServers / permissionMode are ignored)

### Phase 9: 15-axis quality audit

Phases 1-8.5 are official compliance checks for "does it work". Phase 9 is the **15-axis quality audit**: static structural axes (computed by the audit scripts) plus judgment axes (run via independent subagents — Reviewer = Fresh Agent).

Details:
- Evaluation criteria (15-axis definitions): [`references/scoring.md`](references/scoring.md)
- Functional verification (the `verify` subcommand — once a skill fires, does it actually produce what it claims): [`references/verify.md`](references/verify.md)

**The 15 axes** (static = computed by the audit scripts; agent = judged by independent subagents). [`references/scoring.md`](references/scoring.md) is the canonical definition of every axis — not repeated here. Static axes are 1/2/3/7/9/10/11/12/14/15 (plus detection material for 5/6); agent axes are 4/6/7-semantic/8/12b/13/14-semantic. See the command list below for the axis-to-script mapping.

**Static axes — run the scripts**:

```bash
# Static structural audit (Axes 1/2/3/5-detect/7/9/10/14 + material for 6)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-collect.sh <plugin_dir> | \
  ${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-report.sh

# Disambiguation matrix (Axis 6 static, cross-skill computation)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-matrix.sh <plugin_dir>

# Usage (Axis 11, active/mentioned/dormant/likely-trim classification)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh <plugin_dir> [since_days]

# Permission minimality (Axis 12 static candidates: declared allowed-tools vs evidenced usage)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-permissions.sh <plugin_dir>

# Subtree assets (Axis 14 hygiene + Axis 2 slimming, extended to references/ + nested files)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-assets.sh <plugin_dir>

# Interface fidelity (Axis 1: argument-hint surfaces the skill's real subcommands)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-interface.sh <plugin_dir>

# Shape-up triggers (Axis 2 weight + cross-skill near-dup; thresholds = review triggers, not gates)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-shapeup.sh <plugin_dir>

# Cross-skill reference consistency (Axis 15: same store path referenced with divergent spellings)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-consistency.sh <plugin_dir>

# ODD schema lint (Axis 10 extension: odd.yaml structural validity — required / unknown keys / autonomy range / skill match)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-odd.sh <plugin_dir>
```

- `plugin-audit-collect.sh`: scans skills / agents / templates/rules / commands / hooks and outputs TSV
- `plugin-audit-report.sh`: converts the TSV into the Markdown static-audit report
- `plugin-audit-matrix.sh`: cross-skill computation (vocabulary overlap / bidirectional references / one-way references / classification-prefix distribution) as Markdown output
- `plugin-audit-usage.sh`: classifies usage from the past N days of git log + {base} mentions (Axis 11)
- `plugin-audit-permissions.sh`: per-skill `allowed-tools` vs evidenced usage — flags over-grant (declared, unused) and under-declare (used via idiom, not declared). Idiom-based candidates for the Axis 12 agent pass (Axis 12)
- `plugin-audit-assets.sh`: walks each skill's subtree (`references/` + nested) and reports inventory / unnecessary files / orphans / **3b dangling references (pointers to a nonexistent `references/X.md` — not just markdown links but also code spans / prose; cross-references and placeholders are excluded)** / duplicates / Axis 14 hygiene (the Axis 14 + Axis 2 extension that fills the gap where collect.sh only sees SKILL.md; details in scoring.md Axis 14)
- `plugin-audit-interface.sh`: checks whether the argument-hint matches the skill's real subcommands (Axis 1 extension; details in scoring.md Axis 1)
- `plugin-audit-shapeup.sh`: emits leanness triggers (weight + dormancy + near-dup); thresholds are review items, not gates (Axis 2 extension; details in scoring.md Axis 2)
- `plugin-audit-consistency.sh`: clustering-detects "divergence where the same store path is referenced with a different spelling" across all skills (Axis 15). Whereas store-map-lint compares against a manifest, this one **surfaces the spelling mismatch itself without a manifest** (recommends canonicalizing to the `{base}` prefix). `--strict` exits 1 on divergence
- `plugin-audit-odd.sh`: validates every skill's `odd.yaml` against `templates/odd/odd.schema.yaml` (Axis 10 extension) — deterministically detects missing required keys / unknown keys (`additionalProperties:false`) / out-of-range autonomy (L4/L5) / skill-name ↔ directory mismatch / `schema_version`. **Rejects at CI/SessionStart any odd that has decayed into the pre-schema shape via a parallel session's revert or paste-back** (machine-detects structural decay a visual diff would miss). `--strict` exits 1 on violation. Cross-skill drift in path spelling is owned by Axis 15 (division of labor)

**Judgment axes — run via subagents** (Reviewer = Fresh Agent: judgments go to independent `general-purpose` subagents to avoid the main session's self-evaluation bias):

See the corresponding Axis section in scoring.md for the full definition of each judgment axis (Axis 4 routing precision / 5 HeavySkill applicability / 6 boundary ambiguity / 7 semantic generality / 8 rule-externalization / 12 permission minimality / 13 containment / 14 semantic hygiene).

The lightweight default audit runs the static axes plus the cheap single-pass Axes 12/13; `eval` / `verify` / `global` / pre-release audits run all judgment axes.

## Per-skill audit (single-skill mode)

If the argument is not a plugin dir but a **single skill directory** such as `skills/<name>`, audit only that skill:

```bash
# Usage of a single skill
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh --skill skills/<name> [since_days]
```

`collect.sh` / `report.sh` assume a plugin dir, so a per-skill audit substitutes the following procedure:

1. Determine whether the argument is a single skill or a plugin by the presence of a `skills/` subdirectory (present → plugin, absent → single skill)
2. Read the target `SKILL.md` (+ `references/` if present)
3. Run `usage.sh --skill` to get usage (Axis 11)
4. For Axes 1/2/3/5/12, an Agent judges the Read content against each axis's definition in [`references/scoring.md`](references/scoring.md)
5. Compile into the report format (below) in Critical → Warning → Info order

**Subcommands (modes)**:

| Subcommand | Content | Cost |
|-------------|------|-------|
| `plugin-audit` | Axis 1+2+3+5+6+7-local+8-static+12-static (default; the shapeup triggers also appear here) | seconds |
| `plugin-audit eval` | Axis 4 routing (`--tiers haiku,sonnet,opus` for the per-tier sweep) + 7-semantic (parallel Agents) | tens of seconds |
| `plugin-audit verify` | Functional verification — run Tier A/B skills end-to-end in a sandbox against their `verify-cases.yaml` ([`references/verify.md`](references/verify.md)) | minutes |
| `plugin-audit fix` | Agent proposes fixes → interactive approval + Axis 8 rule-externalization + **slimming proposals** (an Agent reviews the default report's shapeup triggers → split / extract / rule-ify / consolidate; a threshold-exceed is a review item, not a failure) | tens of seconds |

The `global` modifier (optional suffix) switches to public-distribution criteria (language / culture / license checks ON). The improvement-proposal dialogue flow is in "Fix flow" below (review-then-fix; never auto-rewrite descriptions; judgment follows the Reviewer = Fresh Agent principle).

## Audit report format

```markdown
# Plugin Audit Report: {plugin-name}

## Critical (affects operation)
- [file]: [issue] → [fix]

## Warning (non-compliant with official docs but works)
- [file]: [issue] → [fix]

## Info (recommendations)
- [file]: [issue] → [fix]

## Statistics
- Skills: N
- Hooks: N
- Average description length: N chars
- SKILL.md over 500 lines: N
- description over 1,024 chars: N / over 1,536 chars: N
- HeavySkill 4-component adopted: N
- skill classification prefix adopted: N
```

(Render the report in the user's conversation language.)

## Fix flow

After running the audit and producing the report (procedure: Phases 1-8 in audit-phases.md), fix via the interactive flow below.

### Step 1: Present results to the user + confirm fixes

```
After displaying the audit report above:

"The following issues were detected:
 - Critical: N
 - Warning: N
 - Info: N

 Fix them in one batch?
 [A] Fix everything
 [B] Fix Critical only
 [C] Review each fix one by one
 [D] Do not fix (report only)"
```

Present the options in text and confirm. (If the user converses in Japanese, present these options in Japanese.)

### Step 2: Apply fixes

Apply the user-approved items in order:

1. Delete the `when_to_use` field → merge into `description`
2. Delete unofficial fields
3. Replace absolute paths with `${CLAUDE_PLUGIN_ROOT}`
4. Split SKILL.md files over 500 lines into `reference.md`
5. Generate `.mcp.json` (if existing mcp-servers are present)
6. Register missing hooks in hooks.json

Show a diff for each fix and get user confirmation (batch for choice A, individual for choice C).

### Step 3: Re-verify after fixes

After all fixes are complete, run the audit again and show remaining issues.

## Determining the audit target

Interpretation of `$ARGUMENTS`:
- Omitted → if the current directory is a plugin, audit it; otherwise audit all of `plugins/*/`
- Path given → audit that path
- Plugin name → audit `plugins/{name}/`

## Prohibited

- **No automatic fixes without user approval** (potentially destructive changes) — the audit itself is read-only, which is what makes natural-language firing safe
- **No fixing without a backup** (warn if the state is not committed to git)

## References

- Plugins (official): https://code.claude.com/docs/en/plugins-reference
- Skills: https://code.claude.com/docs/en/skills
- Hooks: https://code.claude.com/docs/en/hooks
