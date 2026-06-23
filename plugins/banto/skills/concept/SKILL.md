---
name: concept
description: |
  Shape and sharpen the ideology of a product / service / feature (philosophy, worldview, why build it) through dialogue, and inject it into CLAUDE.md as the North Star. Upstream of spec (design docs) and implementation (self-driving).
  Triggers: "concept", "philosophy", "ideology", "worldview", "vision", "north star", "why are we building this", "what is the enemy", "who should this resonate with", "shape the concept", "create a concept". Fires before implementation / specs.
  Do not use when: a simple implementation request (just start coding) or a specification document is wanted (use spec).
user-invocable: true
argument-hint: "[product/service/feature name or 'light' (lightweight, for experiments)]"
model: opus
allowed-tools: Read Write Edit Glob Grep Bash(git:*)
compatibility: Claude Code (requires bash, git, jq)
---

# Concept — Ideology Formation (Interactive Product Philosophy)

> **Storage base (store-first)**: the `.ai-context/concept/...` path this skill saves to refers to the ai-context base. Read/Write under the absolute path injected by the SessionStart/PreCompact hooks as 「ai-context ベース: &lt;absolute path&gt;」 — never write to a relative `.ai-context/` (it exists only in grandfathered legacy repos; if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Write the generated document in the user's conversation language (Japanese if they converse in Japanese). Template labels are illustrative.

SDD (requirements → design → tasks → implementation), spec, and implementation all live in the "**how to build (execution)**" layer and start with ideology as a *premise*. This skill sits one step earlier — it actively shapes "**why build it / what worldview to project / whose resonance to win**".

```
concept (ideology, this skill) → spec (design doc) → implementation (self-driving)
   └─ output CONCEPT.md = North Star for every agent (hook-injected each session; optionally @imported into CLAUDE.md — see Intent Engineering)
```

## Foundational stance (design policy)

- **Ideology can be crafted, should be sharpened, and consistency can be constructed retroactively.** That is why it can be systematized as a skill.
- The skill's job is to **elicit → sharpen → burn in as the North Star**. The conviction **originates from the human**. The AI never fabricates an ideology (ethical boundary).
- "As production cost approaches zero, the moat shifts from execution to vision + empathy" ("You cannot commoditize a philosophy").

## When it fires / does not fire

| Situation | Behavior |
|---|---|
| Want to pin down the "why / worldview" of a new product, service, or feature | **Full mode** (6 phases) |
| Contract / large-scale work realizing or sharpening **the client's concept** | Full mode (with the client as the subject) |
| AI experiment / exploration / throwaway | **Light mode** (one to a few lines: only "what belief is being tested") |
| CONCEPT.md already exists and the change is minor | Does not fire (reference the existing one) |
| Pure implementation / spec writing | Does not fire (go to spec / self-driving implementation) |

**Every tier needs at least a minimal ideology.** Even an experiment gets one line (without it, "we tried something and nothing remains").

## Mode decision (Step 0)

- `$ARGUMENTS` starts with `light`, or the context is experimental / throwaway → **Light mode** (only Phase 1 and a minimal Phase 6)
- Anything else (product / service / contract work) → **Full mode** (Phases 1-6)
- When in doubt, start light and upgrade if deeper work is needed

**Run the dialogue as plain text (do not use AskUserQuestion).** Ask one phase at a time and capture the user's raw words.

## Dialogue flow (full mode)

The detailed question script is in [`references/question-bank.md`](references/question-bank.md). Essentials per phase:

### Phase 1: Dig into the WHY from first principles
Socratic method + 5 Whys. **Bracket out industry conventions** and re-ask as human facts.
- "Why should this exist?" "Apart from the laws of physics, what premises are you treating as 'given'?" "What hurts in a world without this?"
- Output: the WHY core (1-2 sentences)

### Phase 2: Archetype identification (12 brand archetypes)
Collect the user's **natural language**, identify one dominant type (70-80%) plus one secondary type, and **sharpen** them. Type list and mapping procedure: [`references/archetypes.md`](references/archetypes.md).
- Examples: Bezos=Sage/Ruler (data) / Jobs=Creator/Magician (design) / Musk=Explorer/Hero (future) / Anthropic=Sage/Caregiver (freedom and robustness)
- Output: dominant archetype + the ideological direction that archetype implies

### Phase 3: Anti-goals declaration (defining what you will NOT do)
**The contour of an ideology is defined by what it refuses** (Basecamp: Do not grow/scale/exit).
- "What would you regret being in 10 years?" "What would you absolutely refuse even if told 'this will sell'?"
- Output: 3-5 anti-goal declarations

### Phase 4: Aesthetic Signal
Semiotics: color, form, and tone encode the ideology. Monochrome = sincerity / exposed structure = transparency / sans-serif = rejection of preconceptions / bezel-less = a worldview where "technology becomes invisible". Details at the end of [`references/archetypes.md`](references/archetypes.md).
- Output: the texture/tone to carry, in one word + the reason

### Phase 5: Retroactive consistency + Tribe
- Weave pivots and the past into **one consistent narrative** (sensemaking, not deception. Amazon: bookstore → cloud)
- Define the Tribe **as a values cluster, not demographics** ("who will feel 'finally, someone gets me'?")
- Output: one consistent-narrative paragraph + Tribe definition

### Phase 6: Crystallization + empathy gate + injection
1. Crystallize into the **5-element CONCEPT.md** (template below)
2. Check against the **7-item empathy gate** ([`references/empathy-and-ethics.md`](references/empathy-and-ethics.md)). If it fails, go back to Phases 2-5
3. Save to the store + offer **@import injection into CLAUDE.md** (opt-in — see Intent Engineering; on "no" the SessionStart hook injects CONCEPT instead)

## Light mode (for experiments)

Ask only Phase 1 (one-line WHY) plus "what belief is being tested" and "what does success look like", then save a minimal version to `.ai-context/concept/CONCEPT.md`. Upgrade to full mode later if the project goes to production.

## CONCEPT.md template (5 elements)

Save to: `.ai-context/concept/CONCEPT.md`

```markdown
# Concept: {product/service name}

> North Star. When in doubt, hold decisions against this. Last updated {YYYY-MM-DD} (review every 3 months)

## ① WHY (reason to exist)
{1-2 sentences. Worldview and belief. Sinek's WHY}

## ② Anti-goals (never do / never become)
- {what you refuse even if it sells}
- ...

## ③ Tribe (whose resonance to win)
{A values cluster, not demographics. "{This kind of person} feels 'finally, someone gets me'"}

## ④ Aesthetic Signal (texture / tone)
{One word + reason. e.g. "silence = a declaration of sincerity"}

## ⑤ North Star (qualitative definition of success)
{Who ends up in what state = success. Quantification comes later}

## Archetypes
Dominant: {type} / Secondary: {type}
```

## Intent Engineering (North Star injection — most important)

Make CONCEPT.md **the decision filter for every agent**. Two pieces — one invariant, one opt-in:

**1. Always save (invariant)**: CONCEPT.md is always saved to the store at `.ai-context/concept/CONCEPT.md` (the ai-context base resolved store-first). This never changes regardless of the choice below.

**2. CLAUDE.md `@import` — ask first (opt-in)**: pinning CONCEPT.md into the repo's CLAUDE.md via `@import` edits a checked-in file, so confirm before doing it. Ask in plain text:

> "Should I pin CONCEPT into CLAUDE.md via @import so it stays resident? (it adds one line to the repo's CLAUDE.md)"

- **yes** → add one line near the top of the project-root CLAUDE.md (Claude Code resolves `@import` up to 5 hops):
  `@<base>/concept/CONCEPT.md` (or the relative `@.ai-context/concept/CONCEPT.md` in grandfathered legacy repos). If there is no CLAUDE.md, propose creating one (native /init integration).
- **no** → **do not touch CLAUDE.md**. CONCEPT still takes effect every session: the SessionStart hook auto-injects the store's `concept/CONCEPT.md` so agents reference it as the North Star — without writing anything into the repo.

So a user who does not want to touch the repo can choose **no** and CONCEPT still self-drives every session (hook injection); choosing **yes** additionally pins it into CLAUDE.md for an explicit, version-controlled record. Either way, agents constantly self-check "does this implementation align with the WHY / does it touch an anti-goal?".

## Ethical boundary (mandatory)

Details: [`references/empathy-and-ethics.md`](references/empathy-and-ethics.md).
- **No fabricated empathy, no dark patterns** (TARES test compliant)
- The skill only **elicits / sharpens** conviction. **The AI never generates an ideology the human does not hold**
- Never cross the line between manipulation and authentic resonance

## Drift countermeasures

- CONCEPT.md is **something you run, not something you pin up**: review every 3 months
- Warning signs: WHY language disappears from decision-making / new members lack the cultural intuition → prompt re-injection

## Pipeline connection (next steps)

Once the ideology is set:
- `/spec {topic}` → translate the ideology into a specification
- After spec, proceed straight into implementation (self-driving: implement + test + review)
- The 5 elements of CONCEPT.md carry over as the spec's decision axes (anti-goals, North Star)

## Prohibited

- ❌ The AI fabricating an ideology the human does not hold (the job is to elicit)
- ❌ Using `AskUserQuestion` (ask in plain text — this plugin's policy)
- ❌ Leaving any of the 5 elements as "later" (fill with an adopted interpretation and disclose at the end)
- ❌ Finalizing CONCEPT.md without passing the empathy gate (ethics included)
