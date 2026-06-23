# HeavySkill 4-component template

A template that turns the "parallel reasoning + sequential deliberation" structure of [arXiv 2605.02396 (HeavySkill)](https://arxiv.org/abs/2605.02396) into a Markdown skill.

plugin-audit shows info on the presence of these 4 blocks (Activation Conditions / Parallel Protocol / Deliberation / Output Constraints).

**Applies to**: a **WORKFLOW SKILL** that involves complex judgment / trade-off organization / multi-perspective analysis.
**Does not apply**: a simple utility / analysis skill (too heavy, becomes noise instead).

---

## SKILL.md skeleton

```markdown
---
name: {skill-name}
description: "{What it does}. Structured analysis of {problem domain} via the HeavySkill-style 4 stages. Triggers: \"{T1}\", \"{T2}\". INVOKES: launches K=3-5 independent analyses in parallel via Agent (Task tool) → re-derives via deliberation. Does not fire for {simple cases} (use {alternative})."
user-invocable: true
argument-hint: "[{input}]"
model: opus
allowed-tools: ["Read", "Grep", "Glob", "Agent"]
---

# {Skill Name} — HeavySkill 4-component structured reasoning

## 1. Activation Conditions

Fire only when **ALL** of the following hold:

- [ ] {user-intent condition}
- [ ] The problem has a **real fork** (cannot proceed with an adopted interpretation)
- [ ] {domain-specific precondition}
- [ ] There is a goal fork (acceptance criteria change, the order of magnitude of the impact surface differs)

**Does not fire**: {alternative skill / criteria for simple cases}

## 2. Parallel Protocol

With the `Task tool`, **launch K=3-5 independent analysis agents in parallel in a single message**.

Each worker holds a **different perspective** (not the same prompt run in parallel):

```
[independent perspective X / Y]
Problem: {the user's input}

Analyze only from the following angles (ignore other perspectives):
- Perspective 1: {name and scope of perspective 1}
- Perspective 2: {name and scope of perspective 2}
- Perspective 3: {name and scope of perspective 3}
- (up to 4-5 perspectives if needed)

Output:
## Recommended option
## Rationale (3 points)
## Rejected alternatives + reasons

Ignore conflicts with other perspectives; draw a conclusion from your own perspective only.
```

**Key principles**:
- Each worker does not reference other workers' output (ensures independence)
- Higher temperature (diversity)
- Assign by different perspectives (not the same prompt run in parallel)

## 3. Deliberation Prompt

Deliberate over the K outputs in the main session. **Re-derive, do not take a majority vote**:

```
[Deliberation]
The K=N independent analyses are now in. Do the following:

1. Extract the conflicts between perspectives
2. Decide whether each conflict is a "real trade-off" or "one side takes priority"
3. Re-derive a **new solution** that satisfies all perspectives (it is OK even if it was not among them)
4. If re-derivation is impossible, pick the option that satisfies the most perspectives
5. State risks and unverified items explicitly with "Unverified:"
```

The core of HeavySkill: not a majority vote (Vote@K), but **generating a new solution (HP@K > Pass@K)**.

## 4. Output Constraints

The final output **must** have the following structure:

\`\`\`markdown
## Conclusion
{a clear recommendation in one sentence}

## Rationale (3 at most, in priority order)
1. ...
2. ...
3. ...

## Options considered (aggregation of the parallel analysis)
| Option | Pros | Cons | Reversibility |
|----|----------|------------|--------|
| A  | ... | ... | high/medium/low |

## Rejected options and reasons

## Unverified / risks
- Unverified: ...
- Risk: ...

## Next actions
- [ ] {concrete step}
\`\`\`

### Forbidden

- Do not dodge with "it depends"
- Do not just lay out all options in parallel and stop
- Do not punt with "please consider it"
- When uncertain, use the "Unverified:" prefix
```

---

## Whether to co-ship a lightweight mode

If the problem is of "medium complexity", K=1 is often enough. If the Activation Conditions also pick up "medium complexity", co-ship a lightweight mode:

```markdown
## Lightweight mode (K=1, skip deliberation)

If the problem is of medium complexity, K=1 is fine. Confirm in text:
- "Parallel analysis (heavier, 5 workers)" vs "Single analysis (lightweight)"
- Default: single analysis
```

---

## Application examples

- `research` skill — parallel fan-out of external research (5-10 research-agent in parallel)
- `spec` skill — large-scale design (formerly design-first)
- `architect` agent — complex architecture review
- (the former `deep-think` was the representative example, but it was abolished by the v5.21.0 self-driving harness principle. Hard judgments reason deeply via self-driving)

Propose it when the AI judges in `plugin-dev`'s Step 2.5 that "the 4-component is appropriate for this skill".
