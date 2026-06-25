---
name: kit
description: |
  **UTILITY SKILL** — Display all skills / agents / hooks / rules provided by the banto plugin as a formatted catalog. A natural-language discovery hub: users don't need to know which commands exist (intent-first).
  Triggers: /kit, "what can banto do", "list the features", "list the commands", "what skills are there", "how do I ... (when looking for a banto feature)".
  Do not use when: checking the details of an individual skill (Read its SKILL.md directly), auditing a plugin (plugin-audit), or creating a new plugin (plugin-dev).
user-invocable: true
compatibility: Claude Code (requires bash, git, jq)
---

# Banto Kit — Full Feature Catalog

Display the following **as-is** (without editing). If the user is conversing in Japanese, you may display the same catalog in Japanese (keep commands and trigger phrases intact).

## Commands (deterministic aliases — all reachable from natural language too)

> Commands are an escape hatch for power users / routines / CI. You don't need to know they exist: each skill auto-fires from natural language (see the next section for example phrases). Intent-first.

### Search & research
| Command | Description |
|---------|------|
| `/search {query}` | **Internal search**. The search skill (query expansion + grep ranking) searches across `{base}/` (+ any directories added via `extra_docs_dirs` in config.json). Never touches the web |
| `/research {topic}` | **External research**. Investigates the web / GitHub / arxiv / X / official docs in parallel and saves to `docs/research/`. Uses Claude in Chrome as appropriate for the medium |

### Context management
| Command | Description |
|---------|------|
| `/save-checkpoint` | Save session state as a checkpoint. Recommends compact/clear |
| `/ai-context [bootstrap/local/doctor/sort/ignore/migrate/memo/knowledge]` | Management commands for `{base}/` (subsumes store creation & registration / local pinning / health check / tidy-up / suppression / migration / memo / knowledge. `init` and `status` are legacy-name aliases kept for one release of backward compatibility) |

### Document creation
Pattern shared by the document-creation skills: `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` (Pattern A: agent-launching / Pattern B: fill-in-the-blank template)

| Command | Description | Pattern |
|---------|------|----------|
| `/ai-context memo [content]` | No args: save a conversation summary. With args: turn the given content into a memo (the old `/memo` is kept for one release of backward compatibility) | B |
| `/ai-context knowledge [list/promote]` | Review / promote / create knowledge drafts (the old `/knowledge` is kept for one release of backward compatibility)| B (exception: no prefix) |

> Code review and security audit are **delegated to the official Anthropic plugins** (`code-review` / `security-guidance` / `/security-review`).

### Development flow
| Command | Description |
|---------|------|
| `/ai-context next` | Run the next incomplete task |
| `/ai-context phase-done [N]` | Phase completion check + archive |
| `/ws [switch/new/ship/...]` | Workspace + git-town orchestrator for the 3-tier branch model (main ← epic ← task worktree). Drives switching, parallel work, scope carve-out, completion merge, and ship to main via intent detection |

### Tooling
| Command | Description |
|---------|------|
| `/init` + `harness-setup.sh` | First-time setup of CLAUDE.md (native /init) + rules / settings / store (deterministic script) |
| `/plugin-dev {description}` | Scaffold a new plugin / refactor an existing skill |
| `/plugin-audit [path]` | Audit an existing plugin / single skill against official best practices |
| `/set-language [ja/en]` | Switch Banto's language between Japanese and English. The choice persists (survives plugin updates). A Claude Code restart is required to apply it |
| `/ai-context sort project` | Tidy up documents scattered across the whole project |
| `/kit` | Display this catalog |

> Security audit and code review are delegated to the official Anthropic plugins (`security-guidance` / `code-review` / `/security-review`).

## Skills that auto-fire from natural language

| Skill | Example triggers |
|-------|-----------|
| `ai-context` | "decision", "adopt", "design decision", "save", "compact", "clear", "task", "TODO", "Phase" |
| `search` | "we talked about this before", "remind me", "recall", "history", "background", "find" (internal search; `/search` works too) |
| `research` | "look into this", "the latest ...", "best practice", "compare", "paper", "research" (external research; `/research` works too) |
| `ai-context` (next) | "continue", "what's next", "next task", "keep going", "do it" |
| `concept` | "ideology", "concept", "worldview", "vision", "philosophy", "north star", "why build this" |
| `spec` | "spec", "write a spec", "just do the design", "plan", "don't implement it" |
| `dev-loop` | "develop autonomously", "break the big item down and run it", "develop in a loop", "dev loop", "learning loop" (one-off implementation goes directly via self-driving) |
| `ai-build` | "I want to build a RAG", "build an agent", "set up evals", "improve the prompt", "which model should I use" (AI-feature build flow; an AI-specialized version of dev-loop, through eval) |
| `model-lab` | "train a model", "pretrain", "fine-tune this", "distill", "pruning", "run ablations", "write the paper", "publish to HF" (model-building research flow; verification-centered, through paper/HF/GitHub publishing — the research layer to ai-build's application layer) |
| `ai-context` (memo) | "make a memo", "jot this down", "summarize and save the conversation" (subsumed into ai-context; the old `memo` kept for backward compatibility) |
| `ai-context` (knowledge) | "turn this into knowledge", "promote it", "record this as a lesson" (subsumed into ai-context) |
| `plugin-audit` | "check this skill's quality", "review it on the 14 axes", "compare SKILL.md against best practice" |
| `ws` | "workspace", "switch work", "run in parallel", "split off a branch", "worktree", "epic", "this work is done", "merge it", "release it" |
| `set-language` | "set the language to Japanese", "switch to English", "language settings", "make banto japanese/english" (persistent; applied on restart) |

> **Intent-first applied across the board**: the skills above have had the old `disable-model-invocation` lifted so they can be discovered and launched from natural language (north star: "humans never think about invocation"). Commands are kept as deterministic aliases.

> **Self-driving harness principle**: for **one-off requests** like "implement this", "build this", "in parallel", "think hard", **there is no dedicated skill** — Claude handles them via self-driving: concept→spec→**self-driven implementation** (driving design→implementation→test→review) / independent tasks run as **multiple Agents in parallel within a single message** / hard judgments use deep reasoning on demand. Only when **breaking a big item into small tasks and running implementation→verification→fix in a self-driving loop until green** does the `dev-loop` skill orchestrate that self-driving. The subject of invocation is Claude's self-driving, not a human's skill call.

## Custom agents

| Agent | Purpose | Invocation path |
|------------|------|------|
| `architect` | Design / architecture analysis (no code changes) | From `spec` via `Agent(subagent_type="architect", ...)`, or directly |
| `debugger` | Debug errors / test failures | On an error, the AI autonomously launches `Agent(subagent_type="debugger", ...)` |
| `qa-tester` | E2E testing for web/desktop/mobile | Directly via `Agent(subagent_type="qa-tester", ...)` |
| `research-agent` | Web research (parallel launch) | Launched in parallel from `/research` / the research skill |
| `search-agent` | Mechanical execution of internal search (haiku, lightweight) | From the search skill's deep path: 3–5 in parallel, `Agent(subagent_type="search-agent", model="haiku", ...)` |
| `context-keeper` | Consistency check / regeneration of the search text layer (combined.txt) | Fallback when the combined-rebuild hook fails, or directly |

> Code review and security audit are delegated to the official Anthropic plugins (`code-review` / `security-guidance`).

## Subagent delegation rubric — when to delegate

The Layer-3 harness-engineering principle of "isolating exploration / audit / evaluation". To avoid crowding the parent context, delegate to a subagent whenever one of the following applies:

| Situation | Delegate to | Why |
|------|--------|------|
| File exploration spanning 5+ files / a simple "where is X?" | built-in `Explore` | Prevents excerpts from polluting the parent context |
| Multi-step internal investigation / open-ended analysis | built-in `general-purpose` | Explore returns only excerpts and is ill-suited to open-ended work |
| External web / GitHub / arxiv research | `research-agent` | Don't run large WebSearch directly in the parent / WebFetch is forbidden (use webread; evidence-first rule) |
| Design / architecture analysis | `architect` | No code changes. Returns proposals only |
| Root cause of errors / test failures | `debugger` | Isolates the reproduce → fix → rerun loop |
| Code quality review | Anthropic `code-review` plugin | Avoids self-review bias (Reviewer = Fresh Agent principle). Delegated to Anthropic |
| Security audit | Anthropic `security-guidance` / `/security-review` | Automatic 3 layers + explicit review. Delegated to Anthropic |
| E2E / UI verification | `qa-tester` | Isolates the context weight of browser tools |

**When not to delegate**:
- Minor single-file fixes / typos (direct Edit)
- Just opening a known path (direct Read)
- Simple confirmation questions / things fine to proceed on an adopted interpretation
- A request to run all skills / all agents at once (handle sequentially on main; for independent tasks, consider parallel Agents / Workflow)

**Parallel-launch principle**: for K independent tasks, issue **K Agent tool calls within a single message**. Faster than launching sequentially. The parent waits unless `run_in_background=true` is needed. The `research` skill is the canonical example.

## User global rules

| Rule | Description |
|-------|------|
| `evidence-first` | When answering information questions, verify in order: search skill → docs → research-agent |
| `dependencies` | Version selection (choose the latest stable with no known vulnerabilities) + package-manager selection (follow the project's manifest / lockfile, respect the existing PM, don't cross ecosystems) |
| `quality` | Code quality (no unnecessary abstraction, stay within scope) |
| `safety` | Safety (no force-push, secret protection, no raw `.env` output, no debug traces) |
| `spec-fidelity` | Don't guess behavior that isn't in the spec — ask (Ambiguity Questionnaire) |
| `testing` | Testing conventions (one assertion per test, minimal mocks) |
| `code-editing` | Code-editing constraints (edit guards for lockfiles / specific file types, applied path-scoped) |
| `pii-protection` | PII / internal-name protection (forbids writing internal names, other companies' names, or personal info into client deliverables; enforced deterministically by egress-guard) |
| `writing-ja` | Japanese writing conventions (lead with the point, one idea per sentence, don't end sentences with だ/である/です/ます, reduce katakana English) |
