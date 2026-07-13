---
name: skill-audit
description: |
  **Analysis skill** — audits a single skill from a context-engineering angle (vs plugin-audit, which scores an entire plugin across 15 axes). 7 axes: information minimality / leakage of human-only information / division of labor in structure / appropriateness of the execution model directive / context efficiency / stated-AI disclosure and consistency / division of labor with determinism.
  Triggers: "audit this skill", "skill audit", "context-engineering audit", "check this skill's quality". Also invocable via /skill-audit.
  Do not use when: auditing a plugin's overall structure (plugin-audit), auditing the whole harness as a system (harness-audit), generating or refactoring a skill (plugin-dev).
user-invocable: true
argument-hint: "[skill path (defaults to inferring the skill from the current directory)]"
allowed-tools: Read Grep Glob Bash Agent
compatibility: Claude Code (requires bash, jq)
---

# Skill Audit — context-engineering audit of a single skill

Output language: write the response in the conversation language (Japanese follows `writing-ja.md`).

**Division of labor with plugin-audit**: plugin-audit scores an entire plugin (or a single skill via the `skills/<name>` argument) against official compliance and 15 quality axes. skill-audit narrows to one skill and looks only at **context engineering** — whether the skill hands the model only the information it needs to execute. Where plugin-audit's evidence centers on official field coverage, usage, and permissions, skill-audit focuses on information density, leakage of human-only information, execution-model consistency, and stated-AI consistency.

Target: `$ARGUMENTS` (if omitted, use the current directory when it is `skills/<name>/`; otherwise ask the user). Referred to as `TARGET` below.

Stated AI: if the skill body carries no explicit statement ("general-purpose", "ChatGPT", "another AI", etc.), audit it under the assumption that the target is Claude (Claude Code) — see A6 in [`references/axes.md`](references/axes.md).

## Execution

1. Run `scripts/skill-audit-metrics.sh` per [`references/procedure.md`](references/procedure.md) to get the mechanical measurements.
2. Judge each of the 7 axes in [`references/axes.md`](references/axes.md) against the measurements plus what you Read from TARGET.
3. Delegate axes with a subjective judgment call (e.g. A6, stated-AI consistency) to an Agent (general-purpose, model: opus) — the Reviewer = Fresh Agent principle, the same one plugin-audit and harness-audit use.
4. Report each axis as PASS / WARN / FAIL with a supporting line number and a one-sentence fix proposal (report format in procedure.md).

Applying any fix requires user approval — the audit itself is read-only.

## Forbidden

- Auto-applying fixes without user approval
- Substituting for a whole-plugin audit (that is plugin-audit's job)

## References

- Skills (official): https://code.claude.com/docs/en/skills
- model-policy: `templates/model-policy.json` (audit=opus / audit_alt=fable)
