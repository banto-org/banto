# skill design patterns

A collection of design patterns for creating a skill / agent.

## 1. Invocation control patterns (from the table on the official Skills page)

| Frontmatter | User invocation | Claude invocation | Context loading |
|---|:---:|:---:|---|
| (default) | ✓ | ✓ | description always, full on invocation |
| `disable-model-invocation: true` | ✓ | ✗ | description not in context, full on invocation |
| `user-invocable: false` | ✗ | ✓ | description always, full on invocation |

### Bidirectional (default)

```yaml
---
name: search-codebase
description: |
  **ANALYSIS SKILL** — Search the codebase semantically.
  USE FOR: codebase exploration, finding similar implementations.
  INVOKES: Read, Grep, Glob.
---
```

The user can call it with `/search-codebase`. Claude can also auto-fire it.
**Use**: general information retrieval, search, analysis.

### User only (side-effect workflow)

```yaml
---
name: deploy
description: |
  **WORKFLOW SKILL** — Deploy the application to production.
  Explicit invocation only via /deploy.
  INVOKES: Bash(gcloud:*), Bash(kubectl:*).
disable-model-invocation: true
allowed-tools: Read Bash(gcloud:*) Bash(kubectl:*)
---
```

Runs only when the user calls `/deploy`. Claude does not fire it on its own mid-conversation.
**Use**: side-effect workflows such as commit / deploy / send.

### Claude only (background knowledge)

```yaml
---
name: legacy-system-info
description: |
  **ANALYSIS SKILL** — Background knowledge about the legacy XYZ system.
  use proactively when: discussing legacy XYZ behavior or migration.
user-invocable: false
---
```

Not shown in the `/` menu. Auto-referenced when Claude judges it necessary in the conversation context.
**Use**: domain knowledge, legacy-system information, convention sets.

## 2. Skill types (official Skills page)

### Reference content

Official definition:
> "Knowledge Claude applies to current work. Conventions, patterns, style guides, domain knowledge. Used alongside conversation context"

```yaml
---
name: api-conventions
description: API design patterns for this codebase
---

When writing API endpoints:
- Use RESTful naming conventions
- Return consistent error formats
```

Characteristics:
- **Do not** attach `context: fork` (official Warning: meaningless since there is no executable prompt)
- Usually the default invocation setting or `user-invocable: false`
- Referenced in the normal conversation context

### Task content

Official definition:
> "Step-by-step instructions for a specific action (deploy, commit, etc.). Invoked directly via `/skill-name`"

```yaml
---
name: deploy
description: Deploy the application to production
context: fork
disable-model-invocation: true
allowed-tools: Bash(gcloud:*) Bash(kubectl:*)
---

## Steps
1. Run pre-deploy checks
2. Build the artifact
...
```

Characteristics:
- `disable-model-invocation: true` is **an exceptional operation** (intent-first priority): only for truly irreversible/outward side effects, or when it inseparably collides with high-frequency vocabulary. A non-destructive workflow (read-only / requiring `--refresh` / built-in human gate / approval-based) is **published via narrow intrinsic NL triggers + safety boundaries**, with no DMI (the North Star "every feature is reachable in natural language" / decision `2026-06-10-114006`). When keeping it, write the explicit reason in the description
- Subagent separation is possible with `context: fork`
- Has clear steps

## 3. Loop design (from the Glaser Elastic Loop)

Applying Glaser's Elastic Loop concept to skill design:

### Tight Loop (synchronous co-driving)

Characteristics: the user and Claude proceed while verifying behavior back and forth
- User confirmation at each step
- High control, also high cognitive load
- Suited to complex spec branching, first-time attempts, uncertain requirements

```yaml
---
name: spec
description: |
  **WORKFLOW SKILL** — Interactively generate a spec in an industry-standard format.
  Triggers: "spec", "show me the design only", "write a spec" / 「設計だけ見せて」「仕様書作って」「spec」
  Do not use when: going all the way to implementation in one shot — after spec, self-drive the implementation directly.
  INVOKES: confirms requirements via a text dialogue.
---
```

### Loose Loop (asynchronous delegation, Dark Factory)

Characteristics: hand off intent and delegate in a loose loop, course-correct with backpressure, evaluate the result
- Centered on subagent delegation (`context: fork` + `Agent` tool)
- Suppresses the parent session's token consumption
- Suited to established patterns, routine tasks, research / analysis

```yaml
---
name: research
description: |
  **WORKFLOW SKILL** — Newly investigate external information and document it.
  Triggers: "research", "investigate", "what's the latest" / 「調べて」「最新の〜」「リサーチ」
  Do not use when: only an internal search is needed — use search.
  INVOKES: launches research-agent in parallel via Agent(subagent_type=research-agent).
  For a simple fact check, a single webread is enough.
context: fork
agent: general-purpose
---
```

Design questions (Glaser):
- Which loop size should this skill be used at?
- Where is backpressure (evaluation / course-correction points) needed?
- Which artifacts should remain out of the loop?
- How does learning propagate to the organization?

## 4. Subagent execution patterns

### context: fork + agent specification

```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:
1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

Built-in agent types:
- **Explore**: read-only, for codebase exploration
- **Plan**: research agent for plan mode
- **general-purpose**: complex tasks needing both exploration and modification

### Dark-Factory-ized delegation (Glaser)

```
intent (clarified in the skill description)
  ↓
loose loop (launch research-agent in the background)
  ↓
backpressure (specify the save location `.ai-context/docs/research/`)
  ↓
evaluate (evaluate the returned result against strong scenarios)
```

Use `run_in_background=true` to suppress the parent session's token consumption.

## 5. Dynamic context injection

Run a shell command before the skill loads with the `` !`command` `` syntax:

```yaml
---
name: pr-summary
description: Summarize the PR changes
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---

## PR context
- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`

Summarize based on the above.
```

Multiple lines use a ``` ```! ``` block.
Disable: `"disableSkillShellExecution": true`

## 6. Permission control examples

```
# Allow specific skills only
Skill(commit)
Skill(review-pr *)

# Deny a specific skill
Skill(deploy *)

# Deny all skills
Skill
```

## 7. HeavySkill 4-component (for complex workflow skills)

Skills involving complex reasoning adopt the HeavySkill 4-component (Activation Conditions / Parallel Protocol / Deliberation / Output Constraints). See `references/heavyskill-template.md` for the canonical template and applicability criteria (a skill containing complex / decision / analysis / design / deliberation / comparison / trade-off, etc.).

## 8. Intent-first (the principle of command design)

**Do not make the user decide "which command to use".** When giving a skill a command system (`/skill sub <args>`):

1. **Start design from intent detection** — place a table of "which natural-language utterance triggers which operation" at the very top of SKILL.md. The command table comes after (as an alias list)
2. **Reachability rule** — every command must have a path reachable via natural language even when the user does not know it exists. Include utterance examples in the description's trigger words
3. **Split autonomy by intent type** — bookkeeping type (sync / cleanup / state update) = silent automatic (L3) / structure-building type (new branches / new file sets) = proposal with adopted interpretation (L2) → promote based on false-fire rate seen via telemetry / irreversible-outward (PR / publish / send) = human gate
4. **Write false-fire guards** — clearly state in SKILL.md the "this utterance does not fire" boundaries (preventing bureaucratization)
5. Keep commands — deterministic, callable from routine/CI, for power users. What is bad is "making it the main interface", not its existence

Real example: `skills/ws/SKILL.md` (intent-detection table + epic/task/done/ship aliases).

## 9. Flowchart for design decisions

```
Create a new skill
    │
    ▼
Has side effects? (commit / deploy / send / write)
    ├─ Yes → disable-model-invocation: true
    └─ No
        │
        ▼
    Background knowledge? (reference only)
        ├─ Yes → user-invocable: false
        └─ No → default (bidirectional)
            │
            ▼
        Involves complex reasoning?
            ├─ Yes → HeavySkill 4-component
            └─ No → standard template
                │
                ▼
            tight loop or loose loop?
                ├─ Tight → user dialogue, step-by-step confirmation
                └─ Loose → subagent delegation (context: fork)
```

## 10. Bilingual triggers (EN canonical + Japanese triggers co-listed)

A skill's auto-fire depends on matching the keywords in the description against natural language.
To fire for both Japanese and English users, write the description by the following convention
(source: banto-public-release spec T2.1. The Japanese trigger words are tuned in production, so **keep them unchanged**):

```yaml
description: |
  <English prose, canonical: what this skill does and when it should fire. 1-3 sentences.>
  Triggers: "research", "investigate", "what's the latest", 「調べて」「最新の〜」「リサーチ」「比較して」
  Do not use when: <exclusions, EN. e.g. searching local context only (use `search`).>
```

Rules:
- **The body is canonically English** (Claude responds in the user's language even with EN instructions, so the JP user's experience does not degrade)
- **Co-list EN and JP trigger words on the `Triggers:` line**. Move the JP words verbatim from the existing description (do not paraphrase)
- Also state the exclusion conditions (responsibility boundary) in English to prevent false fires
- If there is a command alias (`/xxx`), follow §8 intent-first to keep "the same place reachable in natural language"

## Related

- quality scoring → `references/quality-scoring.md`
- HeavySkill 4-component → `references/heavyskill-template.md`
- all frontmatter fields → `references/skill-md.md`
