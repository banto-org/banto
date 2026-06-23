---
name: spec
description: |
  Interactively generate an industry-standard specification document (spec) before implementation. Ideology is upstream (concept skill), implementation is downstream (concept → spec → implementation, self-driving). Order: requirements analysis → template selection → spec generation → adopted-interpretation report.
  Triggers: "spec", "write a spec", "design only first", "show me the design only", "plan", "design without implementing", "organize the spec", "organize the requirements". Fires when only design is requested.
  Do not use when: starting from ideology/concept (use concept), or when both design and implementation are wanted (run spec, then continue straight into implementation, self-driving).
user-invocable: true
argument-hint: "[feature or problem to implement / spec type]"
model: opus
allowed-tools: Read Grep Glob Bash(git:*) Agent Write Edit
compatibility: Claude Code (requires bash, git, jq)
---

# Spec — Interactive Spec-Driven Design (Specification Generation)

> **Position in the pipeline**: `concept (ideology) → **spec (this skill, design doc)** → implementation (self-driving)`. If there is no ideology yet, run `/concept` first. If CONCEPT.md exists, carry over its "anti-goals" and "North Star" as the spec's decision axes.

> **Storage base (store-first)**: the `.ai-context/...` paths this skill saves to refer to the ai-context base. Read/Write under the absolute path injected by the SessionStart/PreCompact hooks as 「ai-context ベース: &lt;absolute path&gt;」 — never write to a relative `.ai-context/` (it exists only in grandfathered legacy repos; if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Generate an **industry-standard specification document** through dialogue before writing any code. Per the `spec-fidelity` rule, confirm in advance only on "goal forks"; otherwise proceed with adopted interpretations.

Write the generated document in the user's conversation language (Japanese if they converse in Japanese). Template labels are illustrative.

## Premise: 6 template types

`${CLAUDE_PLUGIN_ROOT}/templates/specs/` provides 6 industry standards. Claude **decides which to use through dialogue**:

| # | Format | Suited for | Effort |
|---|---|---|---|
| 1 | **Spec Kit** (spec.md + plan.md + tasks.md, 3-file set) | The standard of the AI-agent era, pairs well with Claude Code/Cursor, TDD recommended | Medium |
| 2 | **PRD** (Product Requirements Document) | Business-side view, PM-driven, product feature definition | Medium |
| 3 | **Design Doc** (Google style) | Detailed engineering design, architecture review | Large |
| 4 | **RFC** (HashiCorp style) | Technical change proposals, team consensus, alternatives included | Large |
| 5 | **ADR** (Architecture Decision Record) | Short post-decision record, single file | Small |
| 6 | **Scope Doc** | Project boundary agreement, rework prevention | Medium |

See `${CLAUDE_PLUGIN_ROOT}/templates/specs/README.md` for details.

## Dialogue flow (standard)

### Step 1: Parse the argument

- `$ARGUMENTS` starts with `spec-kit` / `prd` / `design-doc` / `rfc` / `adr` / `scope` → adopt that format directly, go to Step 3
- Anything else (topic name only / empty) → go to the Step 2 dialogue

### Step 2: Format-selection dialogue (**mandatory**)

Present the following in plain text (in the user's conversation language):

```
Which spec format should we use?

1. Spec Kit (3-file set) — recommended for AI coding, TDD-based, Tier 1-4
2. PRD — business requirements doc, PM-driven, Tier 2-4
3. Design Doc — detailed technical design, Google style, Tier 2-4
4. RFC — change proposal, team consensus, alternatives included, Tier 3-4
5. ADR — short post-decision record, Tier 1-4
6. Scope Doc — scope boundary agreement, rework prevention, Tier 3-4

If unsure, "1. Spec Kit" is the recommendation (the standard of the AI-coding era).
Combinations are fine too: you can specify "1 + 5", "2 + 3", etc.
```

Proceed to Step 3 only after the answer.

### Step 3: Requirements analysis (read code only, write nothing)

Read the related code and organize:

```
## Requirements
- What to achieve
- Who uses it
- Where it impacts the existing code

## Constraints
- What must not change (public APIs, DB schema, etc.)
- Technical constraints
- Time constraints

## Adopted interpretations (items the request did not specify)
- Confirm in advance, in plain text, only the items that are goal forks (where option A/B changes the acceptance criteria)
- For everything else, decide an adopted interpretation, proceed, and disclose it in the Step 7 final report
```

**Delegate heavy analysis to the `architect` subagent** (avoid bloating the parent context):

```
Agent(
  subagent_type="architect",
  description="Design impact analysis",
  prompt="ai-context base: {resolved absolute base path}. First Grep {base}/decisions/ for prior decisions conflicting with this theme. Then investigate the existing-code impact surface, constraints, and trade-offs for implementing {feature name}. Do not change any code; return a list of related files + impact assessment + pros/cons of candidate options A/B/C."
)
```

**Always resolve and pass the ai-context base in the prompt** (subagents do not receive the SessionStart injection; without the base the architect cannot check `decisions/`).

Criteria: more than **5 related files** / spans multiple modules / possible conflict with existing design decisions → delegate to architect. For a small spec confined to 1-2 files, read directly in the main session.

### Step 4: If UI is involved, Claude Design handoff

Detailed steps: [`references/claude-design-handoff.md`](references/claude-design-handoff.md)

Essentials: prototype in Claude Design (claude.ai/design) → "Hand off to Claude Code" produces a bundle ZIP (README.md + prototype.html + assets/). Pro/Max only / Research Preview / powered by the latest Opus. Fallbacks: v0.dev / Figma + Figma MCP / textual UI in a Design Doc.

### Step 5: Apply the template

Read the selected format's template from `templates/specs/`, fill in the `{{variables}}`, and generate the spec under `docs/specs/`:

- Save to: `docs/specs/{YYYY-MM-DD}_{topic-slug}_{type}.md`
  - e.g. `docs/specs/2026-04-20_auth-redesign_spec.md`
  - e.g. `docs/specs/2026-04-20_auth-redesign_plan.md`
  - e.g. `docs/specs/2026-04-20_auth-redesign_tasks.md`
- ADR only goes to `decisions/ADR-{NNNN}_{topic}_{user}.md` (sequential numbering)

When Spec Kit is selected, **generate the 3 files in order** (spec → plan → tasks).

### Step 6: Explicit AI boundaries (**mandatory**)

Every generated spec must include the three-level ✅ Always / ⚠️ Ask first / 🚫 Never section:

```
## Scope boundaries

### ✅ Always (always do this)
- ...

### ⚠️ Ask first (confirm with the user before judging)
- ...

### 🚫 Never (absolutely never)
- ...
```

Without this, the AI fills the gaps by inference (`spec-fidelity` rule).

### Step 7: Adopted-interpretation report (final report, no approval wait)

When spec generation completes, present:

```
## Adopted-interpretation report: {topic}

- Saved to: docs/specs/{filename}
- Format: {selected format}
- Key decisions (3-5 line summary):
  - ...

### Adopted interpretations (items the request did not specify)
- Ambiguity N: {what was ambiguous}
  - Adopted: {how it was interpreted}
  - Alternative: {the option not taken, and why}

### Verification
- Spec consistency check results

→ "The spec was created with adopted interpretations. If you dislike any, we can roll back."
```

**If only design was requested, stop here.** Write no code until implementation is instructed.

### Step 8: Next-step guidance

If the user says "go ahead and implement" / "continue", **proceed straight into self-driving implementation without invoking another skill** (Claude drives design → implementation → tests → review):
- `/ai-context next` → implement from the first incomplete task in tasks.md, in order
- If multiple independent tasks exist, launch multiple Agents in a single message (self-driving fan-out)

## Combined formats

When the user selects multiple (e.g. "1 + 5" = Spec Kit + ADR):

- Generate the Spec Kit 3-file set + extract important technical decisions into ADRs
- PRD + Design Doc are often combined on large projects
- RFC + ADR records the "proposal → decision" flow

## Recommendation by tier

| Tier | Scale | Recommendation |
|---|---|---|
| 1 | Personal / prototype | Spec Kit + ADR (for important decisions) |
| 2 | Small team | + PRD |
| 3 | Mid-size company | + Design Doc + RFC + Scope |
| 4 | Enterprise | All formats + Threat Model + Runbooks |

If no tier is specified, recommend Spec Kit and ask for the user's call.

## Prohibited

- ❌ Touching implementation code while writing the spec (design and implementation are strictly separated)
- ❌ Leaving template variables `{{...}}` unfilled as "later" (fill with adopted interpretations and disclose in Step 7)
- ❌ Proceeding on goal-fork-level ambiguity with an adopted interpretation (advance confirmation is mandatory)
- ❌ Proceeding to implementation when only design was requested (stop at design)

## Related

- Template index: `${CLAUDE_PLUGIN_ROOT}/templates/specs/README.md`
- `spec-fidelity` rule: `~/.claude/rules/spec-fidelity.md`
