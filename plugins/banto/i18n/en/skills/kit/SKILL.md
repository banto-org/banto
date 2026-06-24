---
name: kit
description: |
  **UTILITY SKILL** — Displays every skill / agent / hook / rule the banto plugin provides as a pre-formatted catalog. A natural-language discovery hub: users never need to know a command exists (intent-first).
  Triggers: /kit, "what can banto do", "list of features", "list of commands", "what skills are there", "how do I do ~ (when looking for a banto feature)".
  Do not use when: checking the details of an individual skill (Read its SKILL.md directly), auditing a plugin (plugin-audit), or creating a new plugin (plugin-dev).
user-invocable: true
compatibility: Claude Code (requires bash, git, jq)
---

# Banto Kit — Full Feature Catalog

Display the following **as-is** (without editing). If the user is conversing in Japanese, you may show the same catalog in Japanese (keep the commands and trigger phrases intact).

## Commands (deterministic aliases — all are also reachable from natural language)

> Commands are an escape hatch for power users / routines / CI. You don't need to know a command exists: each skill auto-fires from natural language (see the next section for example phrases). Intent-first.

### Search & research
| Command | Description |
|---------|------|
| `/search {query}` | **Internal search**. The search skill (query expansion + grep ranking) searches across `.ai-context/` (plus any directories added via `extra_docs_dirs` in config.json). Never touches the web |
| `/research {topic}` | **External research**. Investigates the Web / GitHub / arxiv / X / official docs in parallel and saves to `docs/research/`. Uses Claude in Chrome where appropriate for the medium |

### Context management
| Command | Description |
|---------|------|
| `/save-checkpoint` | Saves the session state as a checkpoint. Recommends compact/clear |
| `/ai-context [init/status/doctor/sort/ignore]` | Management commands for `.ai-context/` (`ignore` manages scaffold-suppression paths) |

### Documentation
Shared pattern for the documentation skills: `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` (Pattern A: agent-launched / Pattern B: fill-in template)

| Command | Description | Pattern |
|---------|------|----------|
| `/memo [content]` | No argument: save a summary of the conversation. With argument: turn the given content into a memo | B |
| `/knowledge [promote]` | Review / promote / create knowledge drafts | B (exception: no prefix) |

> Code review and security audit are **delegated to the official Anthropic plugins** (`code-review` / `security-guidance` / `/security-review`).

### Development flow
| Command | Description |
|---------|------|
| `/ai-context next` | Run the next unfinished task |
| `/ai-context phase-done [N]` | Phase completion check + archive |
| `/ws [switch/new/ship/...]` | Workspace + git-town orchestrator for the 3-tier branch model (main ← epic ← task worktree). Drives switching, parallel runs, scope carve-outs, completion merges, and ship to main via intent detection |

### Toolkit
| Command | Description |
|---------|------|
| `/init` + `harness-setup.sh` | First-time setup of CLAUDE.md (native /init) + rules / settings / store (deterministic script) |
| `/plugin-dev {description}` | Scaffold a new plugin / refactor an existing skill |
| `/plugin-audit [path]` | Audit an existing plugin / a single skill against the official best practices |
| `/set-language [ja/en]` | Switch Banto's language between Japanese and English. The choice is persistent (survives plugin updates). A Claude Code restart is required to apply it |
| `/ai-context sort project` | Tidy up documents scattered across the whole project |
| `/kit` | Display this catalog |

> Security audit and code review are delegated to the official Anthropic plugins (`security-guidance` / `code-review` / `/security-review`).

## Skills that auto-fire from natural language

| Skill | Example triggers |
|-------|-----------|
| `ai-context` | "decision", "adopt", "design decision", "save", "compact", "clear", "task", "TODO", "Phase" |
| `search` | "we talked about this before", "recall", "history", "background", "find it" (internal search; `/search` also works) |
| `research` | "look this up", "the latest ~", "best practice", "compare", "papers", "research" (external research; `/research` also works) |
| `ai-context` (next) | "continue", "what's next", "next task", "go ahead", "do it" |
| `concept` | "ideology", "concept", "worldview", "vision", "philosophy", "north star", "why are we building this" |
| `spec` | "spec", "write a spec", "just design it", "plan", "don't implement" |
| `dev-loop` | "develop autonomously", "break the big item down and run it", "develop in a loop", "dev loop", "learning loop" (one-off implementation goes straight through self-driving) |
| `memo` | "make a memo", "jot this down", "summarize the conversation and save it" ("decision" / "save" → not ai-context) |
| `knowledge` | "turn this into knowledge", "promote it", "record this as a lesson" |
| `plugin-audit` | "quality-check this skill", "review it on the 14 axes", "check SKILL.md against best practices" |
| `ws` | "workspace", "switch tasks", "run in parallel", "split off a branch", "worktree", "epic", "this work is done", "merge it", "release it" |
| `set-language` | "set the language to Japanese", "switch to English", "language settings", "make banto japanese/english" (persistent; applied on restart) |

> **Intent-first applied across the board**: the skills above have had the old `disable-model-invocation` removed so they can be discovered and launched from natural language (north star: "humans never think about invocation"). The commands remain as deterministic aliases.

> **Self-driving harness principle**: for **one-off requests** like "implement it", "develop it", "in parallel", or "think deeply", **there is no dedicated skill** — Claude handles them via self-driving: concept→spec→**self-driven implementation** (drives design→implementation→test→review) / independent tasks run as **multiple Agents in parallel within a single message** / hard judgments get on-demand deep reasoning. The `dev-loop` skill orchestrates that self-driving **only** when you need to break a big item into small tasks and run an implementation→verification→fix loop autonomously until green. The subject of invocation is Claude's self-driving, not a human's skill call.

## Custom agents

| Agent | Purpose | Launch path |
|------------|------|------|
| `architect` | Design / architecture analysis (no code changes) | From `spec` via `Agent(subagent_type="architect", ...)`, or directly |
| `debugger` | Debug errors / test failures | When an error occurs, the AI autonomously launches `Agent(subagent_type="debugger", ...)` |
| `qa-tester` | E2E testing for web/desktop/mobile | Directly via `Agent(subagent_type="qa-tester", ...)` |
| `research-agent` | Web research (launched in parallel) | Launched in parallel from `/research` / the research skill |
| `search-agent` | Mechanical execution of internal search (haiku, lightweight) | From the search skill's deep path: 3–5 parallel `Agent(subagent_type="search-agent", model="haiku", ...)` |
| `context-keeper` | Consistency check / regeneration of the search text layer (combined.txt) | Fallback when the combined-rebuild hook fails, or directly |

> Code review and security audit are delegated to the official Anthropic plugins (`code-review` / `security-guidance`).

## Subagent delegation rubric — when to delegate

A Layer-3 harness-engineering principle of "isolate exploration / audit / evaluation." To avoid bloating the parent context, delegate to a subagent when any of the following applies:

| Situation | Delegate to | Reason |
|------|--------|------|
| File exploration spanning 5+ files / a simple "where is X?" | Built-in `Explore` | Prevents excerpts from polluting the parent context |
| Multi-step internal investigation / open-ended analysis | Built-in `general-purpose` | Explore returns only excerpts and is unsuited to open-ended work |
| External Web / GitHub / arxiv research | `research-agent` | Don't run large WebSearch directly in the parent / WebFetch is forbidden (use webread. evidence-first rule) |
| Design / architecture analysis | `architect` | No code changes. Returns proposals only |
| Root cause of an error / test failure | `debugger` | Isolates the reproduce → fix → rerun loop |
| Code quality review | Anthropic `code-review` plugin | Avoids self-review bias (Reviewer = Fresh Agent principle). Delegated to Anthropic |
| Security audit | Anthropic `security-guidance` / `/security-review` | Automatic 3-layer + explicit review. Delegated to Anthropic |
| E2E / UI verification | `qa-tester` | Isolates the context weight of browser tooling |

**When NOT to delegate**:
- Minor single-file fixes / typos (Edit directly)
- Just opening a known path (Read directly)
- Simple confirmation questions / things you can proceed on with an adopted interpretation
- A request to run all skills / all agents at once (process serially on main. For independent tasks, consider parallel Agents / Workflow)

**Parallel-launch principle**: for K independent tasks, issue **K Agent tool calls within a single message**. It's faster than launching serially. The parent waits unless `run_in_background=true` is needed. The `research` skill is the canonical example.

## User global rules

| Rule | Description |
|-------|------|
| `evidence-first` | When answering information questions, verify in order: search skill → docs → research-agent |
| `dependencies` | Version selection (pick the latest, stable, no-known-vulnerabilities version) + PM selection (follow the project's manifest / lockfile, respect the existing PM, don't cross ecosystems) |
| `quality` | Code quality (no unnecessary abstraction, stay within scope) |
| `safety` | Safety (no force-push, secret protection, no raw `.env` output, no debug traces) |
| `spec-fidelity` | Don't guess at behavior not in the spec — ask (Ambiguity Questionnaire) |
| `testing` | Test conventions (1 assertion per test, minimal mocks) |
| `code-editing` | Code-editing constraints (edit guards for lockfiles / specific file types, path-scoped application) |
| `pii-protection` | PII / internal-name protection (forbids writing internal names, other companies' names, or personal info into client deliverables. Enforced deterministically by egress-guard) |
| `writing-ja` | Japanese writing conventions (lead with the point, one idea per sentence, no だ/である/です/ます at sentence end, reduce katakana English) |
