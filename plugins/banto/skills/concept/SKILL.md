---
name: concept
description: |
  Form and sharpen the ideology of a product, service, or feature (philosophy, worldview, why you build it) through dialogue, and inject it into CLAUDE.md as the North Star. Upstream of spec (the design doc) and implementation (self-driving).
  Triggers: "ideology", "concept", "worldview", "vision", "philosophy", "North Star", "why build it", "what is the enemy", "who does it resonate with", "pin down the ideology", "create a concept". Fires before implementation / spec.
  Do not use when: a simple implementation request (just start writing code), or when you want a spec (use spec).
user-invocable: true
argument-hint: "[product/service/feature name or 'light' (lightweight, for experiments)]"
model: opus
allowed-tools: Read Write Edit Glob Grep Bash(git:*)
compatibility: Claude Code (requires bash, git, jq)
---

# Concept — ideology formation (product philosophy through dialogue)

> **Store-first**: saves to `{base}/concept/CONCEPT.md`. `{base}` is the absolute ai-context base path injected by the SessionStart/PreCompact hook (when unknown, resolve it with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Write the generated document in the user's conversation language (Japanese if conversing in Japanese). The template labels are merely illustrative.

SDD (requirements → design → tasks → implementation), spec, and implementation all sit at the "**how to build (execution)**" layer and start by *presupposing* an ideology. This skill sits one step before that, actively shaping "**why build it / what worldview to project / whose resonance to win**".

```
concept (ideology, this skill) → spec (design doc) → implementation (self-driving)
   └─ output CONCEPT.md = North Star for every agent (hook-injected each session; optionally @imported into CLAUDE.md — see Intent Engineering)
```

## Foundational stance (design policy)

- **Ideology can be crafted, should be sharpened, and consistency can be built retroactively.** That is exactly why it can be systematized as a skill.
- The skill's job is to **elicit → sharpen → burn in as the North Star**. The **origin of conviction is the human**. The AI does not fabricate ideology (ethical boundary).
- "As production cost approaches zero, the moat moves from execution to vision + empathy" ("philosophy cannot be commoditized").

## When it fires / when it does not

| Situation | Behavior |
|---|---|
| Want to pin down the "why / worldview" of a new product, service, or feature | **Full mode** (6 Phases) |
| A contract / large-scale engagement realizing and sharpening **the client's ideology** | Full mode (with the client as the subject) |
| AI experiment / exploration / throwaway | **Light mode** (1 to a few lines: just "what belief to test") |
| CONCEPT.md already exists and the change is minor | Does not fire (reference the existing one) |
| Pure implementation / writing a spec | Does not fire (go to spec / self-driving implementation) |

**Every stage needs at least a minimal ideology.** Even an experiment leaves one line (without it, you get "tried something but nothing remains").

## Mode decision (Step 0)

- `$ARGUMENTS` starts with `light`, or the context is an experiment / throwaway → **Light mode** (Phase 1 and a minimal Phase 6 only)
- Otherwise (product / service / contract engagement) → **Full mode** (Phases 1-6)
- When unsure, start with light and upgrade if deeper work is needed

**Conduct the dialogue in plain text (do not use AskUserQuestion).** Ask one Phase at a time and pick up the user's raw words.

## Dialogue flow (full mode)

The detailed question script is in [`references/question-bank.md`](references/question-bank.md). The gist of each Phase:

### Phase 1: Dig out the WHY from first principles
Socratic + 5 Whys. **Bracket the industry's conventions** and re-ask as human facts.
- "Why should this exist?" "Aside from the laws of physics, what are you treating as a 'given' premise?" "In a world without this, what hurts?"
- Output: the core WHY (1-2 sentences)

### Phase 2: Archetype identification (12 brand archetypes)
Collect the user's **natural language**, identify one dominant type (70-80%) + one secondary type, and **sharpen** it. The type list and mapping procedure: [`references/archetypes.md`](references/archetypes.md).
- e.g. Bezos=Sage/Ruler (data) / Jobs=Creator/Magician (design) / Musk=Explorer/Hero (the future) / Anthropic=Sage/Caregiver (freedom and robustness)
- Output: the dominant type + the ideological direction it indicates

### Phase 3: Anti-goals declaration (define what you will not do)
**The contour of an ideology is defined by what it refuses** (Basecamp: don't grow / don't scale / don't exit).
- "Ten years from now, what state would make you regret it?" "What would you absolutely refuse even if told 'this will sell'?"
- Output: 3-5 anti-goals

### Phase 4: Aesthetic Signal
Semiotics: color, form, and tone encode the ideology. Monotone = sincerity / exposing internal structure = transparency / sans-serif = refusal of preconception / bezel-less = a "technology becomes transparent" worldview. Details at the end of [`references/archetypes.md`](references/archetypes.md).
- Output: the texture / tone to carry, in one word + the reason

### Phase 5: Retroactive consistency + Tribe
- Weave pivots and the past into **one consistent story** (sensemaking, not deception. Amazon: bookstore → cloud)
- Define the Tribe **as a values cluster, not demographics** ("Who feels 'finally, someone gets me'?")
- Output: one paragraph of the consistent story + the Tribe definition

### Phase 6: Crystallization + empathy gate + injection
1. Crystallize into a **5-element CONCEPT.md** (template below)
2. Check against the **7-item empathy gate** ([`references/empathy-and-ethics.md`](references/empathy-and-ethics.md)). If it does not pass, return to Phases 2-5
3. Save to the store + propose **@import injection into CLAUDE.md** (opt-in — see Intent Engineering. On "no", the SessionStart hook injects CONCEPT instead)

## Light mode (for experiments)

Ask only Phase 1 (a one-line WHY) plus "what belief are you testing" and "what is success", and save a minimal version to `{base}/concept/CONCEPT.md`. Promote to full mode later once the project goes to production.

## CONCEPT.md template (5 elements)

Save to: `{base}/concept/CONCEPT.md`

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

Make CONCEPT.md **the judgment filter for every agent**. Two elements — one invariant, one opt-in:

**1. Always saved (invariant)**: CONCEPT.md is always saved to the store's `{base}/concept/CONCEPT.md` (the ai-context base resolved store-first). This does not change regardless of the choice below.

**2. CLAUDE.md `@import` — confirm first (opt-in)**: pinning CONCEPT.md into the repo's CLAUDE.md via `@import` edits a checked-in file, so confirm before doing it. Ask in plain text:

> "Shall I keep CONCEPT resident in CLAUDE.md via @import? (one line goes into the repo's CLAUDE.md)"

- **yes** → add one line near the top of the project-root CLAUDE.md (Claude Code resolves `@import` up to 5 hops):
  `@{base}/concept/CONCEPT.md`. If there is no CLAUDE.md, propose creating one (native /init integration).
- **no** → **do not touch CLAUDE.md**. CONCEPT takes effect every session: the SessionStart hook auto-injects the store's `concept/CONCEPT.md` and agents reference it as the North Star — nothing is written to the repo.

In short, a user who does not want to touch the repo chooses **no**, and CONCEPT self-drives every session via hook injection. Choosing **yes** additionally pins it into CLAUDE.md, making it an explicit, version-controlled record. Either way, agents always self-check "is this implementation aligned with the WHY / does it violate the anti-goals".

## Ethical boundary (mandatory)

Details: [`references/empathy-and-ethics.md`](references/empathy-and-ethics.md).
- **No fake empathy, no dark patterns** (per the TARES test)
- The skill only **elicits / sharpens** conviction. **The AI does not generate an ideology the human does not hold**
- Never cross the line between manipulation and genuine resonance

## Drift countermeasures

- CONCEPT.md is **something to run, not to pin**: review every 3 months
- Warning signs: the language of the WHY disappears from decisions / new members lack the cultural instincts → prompt a re-injection

## Pipeline connection (next steps)

Once the ideology is set:
- If a screen or UI is involved, build a design brief with the design-brief skill first
- `/spec {topic}` → translate the ideology into a spec
- After the spec, proceed straight to implementation (self-driving: implement + test + review)
- The 5 elements of CONCEPT.md carry over as the spec's judgment axes (anti-goals, North Star)

## Forbidden

- ❌ The AI fabricating an ideology the human does not hold (the job is to elicit)
- ❌ Leaving any of the 5 elements as "later" (fill with an adopted interpretation and disclose at the end)
- ❌ Finalizing CONCEPT.md without passing the empathy gate (including ethics)
