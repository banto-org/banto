---
name: spec
description: |
  Interactively generate an industry-standard specification document (spec) before implementation. Ideology is upstream (concept skill), implementation is downstream (concept → spec → implementation, self-driving).
  Triggers: "spec", "write a spec", "design only first", "show me the design only", "plan", "design without implementing", "organize the spec", "organize the requirements". Fires when only design is requested.
  Do not use when: starting from ideology/concept (use concept), or when both design and implementation are wanted (run spec, then continue straight into implementation, self-driving).
user-invocable: true
argument-hint: "[feature or problem to implement / spec type]"
model: opus
allowed-tools: Read Grep Glob Bash(git:*) Agent Write Edit
compatibility: Claude Code (requires bash, git, jq)
---

# Spec — Interactive Spec-Driven Design (Specification Generation)

> **Position in the pipeline**: `concept (ideology) → **spec (this skill, design doc)** → implementation (self-driving)`. If there is no ideology yet, run `/concept` first. If CONCEPT.md exists, carry over its "anti-goals" and "North Star" as the spec's decision axes. If a screen or UI is involved, build a design brief with the design-brief skill first.

> **Storage base (store-first)**: saves go to `{base}/docs/specs/...` (ADRs only to `{base}/decisions/`). `{base}` is the absolute ai-context base path injected by the SessionStart/PreCompact hooks (if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Generate an **industry-standard specification document** through dialogue before writing any code. Per the `spec-fidelity` rule, confirm in advance only on "goal forks"; otherwise proceed with adopted interpretations.

Write the generated document in the user's conversation language (Japanese if they converse in Japanese). Template labels are illustrative.

## Premise: 6 template types

`${CLAUDE_PLUGIN_ROOT}/templates/specs/` provides 6 industry standards (Spec Kit / PRD / Design Doc / RFC / ADR / Scope Doc). Each format's fit, effort, and tier is canonically defined by the Step 2 option text and `${CLAUDE_PLUGIN_ROOT}/templates/specs/README.md`. Claude **decides which to use through dialogue**.

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

Minimal procedure when UI is involved:
1. Confirm in text whether Claude Design (claude.ai/design, Pro/Max only, Research Preview) is available
2. Yes → have the user fill in the 4 elements (Goal / Layout / Content / Audience) and build a prototype in Claude Design
3. Once the prototype is done, "Hand off to Claude Code" produces a bundle ZIP (README.md + prototype.html + assets/) → save it under `docs/specs/designs/{topic}/`
4. Read the bundle's README.md and implement following the existing codebase conventions
5. No / below Pro → fall back (v0.dev / Figma + Figma MCP / textual UI in a Design Doc)

### Step 5: Apply the template

Read the selected format's template from `templates/specs/`, fill in the `{{variables}}`, and generate the spec under `docs/specs/`:

- Save to: `docs/specs/{YYYY-MM-DD}_{topic-slug}_{type}.md`
  - e.g. `docs/specs/2026-04-20_auth-redesign_spec.md`
  - e.g. `docs/specs/2026-04-20_auth-redesign_plan.md`
  - e.g. `docs/specs/2026-04-20_auth-redesign_tasks.md`
- ADR only goes to `decisions/ADR-{NNNN}_{topic}_{user}.md` (sequential numbering)

When Spec Kit is selected, **generate the 3 files in order** (spec → plan → tasks).

> **Ledger roles**: `_tasks.md` is the **planning ledger** (phase structure, dependencies, acceptance criteria).
> The live execution ledger is the WS `tasks.md` (`workspaces/<author>/<topic>/tasks.md`); sync `_tasks.md`
> only at milestones (phase completion, design changes). Always include this one-liner at the top of the
> generated `_tasks.md` as well (prevents double-ledger drift).

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
- If multiple independent tasks exist, launch multiple Agents in a single message (self-driving fan-out). Implementation Agents use `model: "sonnet"` (the `implement` default in `templates/model-policy.json`)

## Combined formats

When the user selects multiple (e.g. "1 + 5" = Spec Kit + ADR):

- Generate the Spec Kit 3-file set + extract important technical decisions into ADRs
- PRD + Design Doc are often combined on large projects
- RFC + ADR records the "proposal → decision" flow

## Recommendation by tier

The recommended combination per tier (personal through enterprise) is canonically defined in `${CLAUDE_PLUGIN_ROOT}/templates/specs/README.md`. If no tier is specified, recommend Spec Kit and ask for the user's call.

## Prohibited

- ❌ Touching implementation code while writing the spec (design and implementation are strictly separated)
- ❌ Leaving template variables `{{...}}` unfilled as "later" (fill with adopted interpretations and disclose in Step 7)
- ❌ Proceeding on goal-fork-level ambiguity with an adopted interpretation (advance confirmation is mandatory)
- ❌ Proceeding to implementation when only design was requested (stop at design)

## Related

- Template index: `${CLAUDE_PLUGIN_ROOT}/templates/specs/README.md`
- `spec-fidelity` rule: `~/.claude/rules/spec-fidelity.md`
