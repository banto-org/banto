---
name: kit
description: |
  **UTILITY SKILL** — Display a formatted catalog of every skill / agent / hook / rule the banto plugin provides. The natural-language discovery hub: users never need to know a command exists (intent-first).
  Triggers: /kit, "what can banto do", "what can this plugin do", "list all banto features", "what commands are there", "how do I do X with banto".
  Do not use when: inspecting a single skill in detail (Read its SKILL.md directly), auditing a plugin (plugin-audit), or creating a new plugin (plugin-dev).
user-invocable: true
compatibility: Claude Code (requires bash, git, jq)
---

# Banto Kit — Full Feature Catalog

Display the following **as-is** (no editing). If the user converses in Japanese, you may render the same catalog in Japanese (keep commands and trigger words verbatim).

## Commands (deterministic aliases — every one is also reachable by natural language)

> Commands are escape hatches for power users / routines / CI. You never need to know a command exists: each skill auto-fires from natural language (see the next section for example phrases). Intent-first.

### Search & research
| Command | What it does |
|---------|------|
| `/search {query}` | **Internal search**. The search skill (query expansion + grep ranking) searches across `.ai-context/` (+ directories added via `extra_docs_dirs` in config.json). Never touches the Web |
| `/research {topic}` | **External research**. Investigates Web / GitHub / arxiv / X / official docs in parallel and saves to `docs/research/`. Uses Claude in Chrome as appropriate per medium |

### Context management
| Command | What it does |
|---------|------|
| `/save-checkpoint` | Save the session state as a checkpoint. Recommends compact/clear |
| `/ai-context [init/status/doctor/sort/ignore]` | Management commands for `.ai-context/` (`ignore` manages scaffold-suppression paths) |

### Document creation
Shared pattern across the document-creation skills: `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` (Pattern A: agent-invoking / Pattern B: fill-in template)

| Command | What it does | Pattern |
|---------|------|----------|
| `/memo [content]` | No argument: save a conversation summary. With argument: memo the given content | B |
| `/knowledge [promote]` | Review / promote / create knowledge drafts | B (exception: no prefix) |

> Code review and security audit are **delegated to the official Anthropic plugins** (`code-review` / `security-guidance` / `/security-review`).

### Development flow
| Command | What it does |
|---------|------|
| `/ai-context next` | Run the next incomplete task |
| `/ai-context phase-done [N]` | Phase completion check + archive |

### Tooling
| Command | What it does |
|---------|------|
| `/init` + `harness-setup.sh` | CLAUDE.md (native /init) + rules / settings / store first-time setup (deterministic script) |
| `/plugin-dev {description}` | Scaffold a new plugin / refactor an existing skill |
| `/plugin-audit [path]` | Audit an existing plugin / single skill against official best practices |
| `/banto-port [target]` | Port changes into the public Banto tree (allowlist → gates → export → NDA sweep; publishing stays a human gate) |
| `/ai-context sort project` | Tidy up scattered documents across the project |
| `/kit` | Display this catalog |

> Security audits and code reviews are delegated to the official Anthropic plugins (`security-guidance` / `code-review` / `/security-review`).

## Skills that auto-fire from natural language

| Skill | Example triggers |
|-------|-----------|
| `ai-context` | "decision", "adopt", "design decision", "save", "compact", "clear", "task", "TODO", "Phase" |
| `search` | "talked about before", "recall", "history", "backstory", "find it" (internal search; also `/search`) |
| `research` | "look into", "what's the latest", "best practices", "compare", "papers", "research" (external research; also `/research`) |
| `ai-context` (next) | "continue", "what's next", "next task", "proceed", "do it" |
| `concept` | "philosophy", "concept", "worldview", "vision", "ideology", "north star", "why build it" |
| `spec` | "spec", "write a spec", "design only", "plan", "don't implement" |
| `dev-loop` | "self-drive the development", "decompose this big task and run it", "loop the development", "dev loop", "training loop" (a single-shot implementation is plain self-driving) |
| `memo` | "memo this", "jot this down", "summarize the conversation and save" (not "decision" / "save" → ai-context) |
| `knowledge` | "make this a knowledge entry", "promote it", "keep this as a lesson" |
| `plugin-audit` | "check this skill's quality", "review on 14 axes", "match SKILL.md against best practices" |
| `banto-port` | "reflect into the public tree", "run the public export" (NOT "ship it" / "release" → ws ship) |

> **intent-first applied across the board**: the skills above had the legacy `disable-model-invocation` lifted so they can be discovered and fired from natural language (north star: "humans never think about invocation"). Commands are kept as deterministic aliases.

> **Self-driving harness principle**: for **single-shot** requests like "implement it", "develop it", "in parallel", "think deeply", etc., **there are no dedicated skills** — Claude handles them by self-driving: concept→spec→**self-driven implementation** (drives design→implementation→test→review) / independent tasks run as **multiple Agents in parallel within one message** / hard judgments get deep reasoning on demand. Only when **decomposing a big task into a self-driving implement→verify→fix loop until green** does the `dev-loop` skill orchestrate that self-driving. The actor that initiates is Claude self-driving, not a human invoking skills.

## Custom agents

| Agent | Purpose | Invocation route |
|------------|------|------|
| `architect` | Design / architecture analysis (no code changes) | From `spec` via `Agent(subagent_type="architect", ...)`, or directly |
| `debugger` | Debugging errors / test failures | The AI autonomously launches `Agent(subagent_type="debugger", ...)` when errors occur |
| `qa-tester` | E2E testing for web/desktop/mobile | Directly via `Agent(subagent_type="qa-tester", ...)` |
| `research-agent` | Web research (parallel launches) | Launched in parallel from `/research` / the research skill |
| `search-agent` | Mechanical execution of internal search (haiku, lightweight) | From the search skill's deep path: 3–5 parallel `Agent(subagent_type="search-agent", model="haiku", ...)` |
| `context-keeper` | Integrity check / regeneration of the search text layer (combined.txt) | Fallback when the combined-rebuild hook fails, or directly |

> Code review and security audit are delegated to the official Anthropic plugins (`code-review` / `security-guidance`).

## Subagent Delegation Rubric — when to delegate

The Layer-3 harness-engineering principle of "isolating exploration / audit / evaluation". To avoid pressuring the parent context, delegate to a subagent when any of the following applies:

| Situation | Delegate to | Why |
|------|--------|------|
| File exploration over 5+ files / a simple "where is X?" | Built-in `Explore` | Keeps excerpts from polluting the parent context |
| Multi-step internal investigation / open-ended analysis | Built-in `general-purpose` | Explore only returns excerpts, unfit for open-ended work |
| External Web / GitHub / arxiv research | `research-agent` | Don't run large WebSearch directly in the parent / WebFetch is banned (use webread; evidence-first rule) |
| Design / architecture analysis | `architect` | No code changes; returns proposals only |
| Root cause of errors / test failures | `debugger` | Isolates the reproduce → fix → rerun loop |
| Code quality review | Anthropic `code-review` plugin | Avoids self-review bias (Reviewer = Fresh Agent principle). Delegated to Anthropic |
| Security audit | Anthropic `security-guidance` / `/security-review` | Automatic 3-layer + explicit review. Delegated to Anthropic |
| E2E / UI verification | `qa-tester` | Isolates the context weight of browser tools |

**When not to delegate**:
- Minor single-file fixes / typos (direct Edit)
- Just opening a known path (direct Read)
- Simple confirmation questions / things to proceed on with an adopted interpretation
- Requests to run every skill / every agent at once (handle sequentially in main; consider parallel Agents / a Workflow for independent tasks)

**Parallel-launch principle**: for K independent tasks, issue **K Agent tool calls within one message**. Faster than sequential launches; the parent waits unless `run_in_background=true` is required. The `research` skill is the canonical example.

## User-global rules

| Rule | Contents |
|-------|------|
| `evidence-first` | When answering informational questions, verify in order: search skill → docs → research-agent |
| `dependencies` | Version selection (pick the newest that is stable AND free of known vulnerabilities) + PM selection (follow the project's manifest / lockfile; respect the existing PM, never cross ecosystems) |
| `quality` | Code quality (no unnecessary abstraction, stay in scope) |
| `safety` | Safety (no force-push, secret protection, no raw `.env` output, no debug tracing) |
| `spec-fidelity` | Don't infer behavior absent from the spec — ask (Ambiguity Questionnaire) |
| `testing` | Test conventions (one assertion per test, minimal mocks) |
