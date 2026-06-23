---
name: research
description: |
  Investigate external sources (Web, GitHub, arxiv, X, etc.) anew and document the findings (external research / go fetch new information). If you only need to look through the existing .ai-context/, use the search skill instead.
  Triggers: "research", "investigate", "look into", "what's the latest", "what's the current state of", "best practices", "papers", "trends", "compare libraries/tools", "which is better". Also invocable via /research <topic>.
  Do not use when: only searching the existing local AI Context (.ai-context/ decisions / docs / past conversations) — that is the search skill (no web access). A bare "tell me about" about the project's own code is answered directly or via the search skill.
user-invocable: true
argument-hint: "[research topic]"
model: opus
allowed-tools: Read Write Glob Agent WebSearch Bash Workflow
compatibility: Claude Code (requires bash, git, jq)
---

# Research — External Research Skill

> **Storage base (store-first)**: the `.ai-context/docs/research/...` path this skill saves to refers to the ai-context base. Read/Write under the absolute path injected by the SessionStart/PreCompact hooks as 「ai-context ベース: &lt;absolute path&gt;」 — never write to a relative `.ai-context/` (it exists only in grandfathered legacy repos; if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Write in the user's conversation language (Japanese if they converse in Japanese): this covers your responses, the reported findings, **and the saved research document**. Pass that language to the research-agent in the launch prompt (subagents do not inherit the conversation language).

## search vs research

| | `/search` | `/research` (this skill) |
|---|---|---|
| Target | **Internal**: `.ai-context/` (decisions/ + docs/ + past conversation history) | **External**: Web, GitHub, arxiv, X, official docs |
| Web access | **None** | Yes |
| Result | Returns references / summaries of existing files | Saves a new file to `.ai-context/docs/research/` |
| Duration | Seconds | Minutes (parallel research-agent launches) |

**Mnemonic**: do we already have it, or not? If we don't have it, use `research`.

## Principles

1. **Parallel execution**: run research items via the Agent tool (research-agent), **5-10 in parallel at once**
2. **Always search for the latest**: never rely on knowledge cutoff; always fetch the latest via WebSearch
3. **Pick the right medium**: choose the best research tool per topic (table below)
4. **Confirm before login-required research**: get the user's approval first for media that require authentication (X/Twitter etc.)
5. **Always cite source URLs**: information without sources is worthless
6. **Document the results**: save to `.ai-context/docs/research/{YYYY-MM-DD}_{topic}.md` (never let it end as conversation only)

## Choosing the research medium

Classify the topic before choosing a tool. Picking the wrong medium hurts quality significantly:

> **Do not use WebFetch to fetch URL contents** (a small model summarizes the page, so the full text cannot be verified).
> To read a URL, use `webread` (`sh "$CLAUDE_PLUGIN_ROOT/scripts/webread.sh" "<URL>"`, full-text extraction via trafilatura).
> WebSearch is for *finding* URLs (no summarization problem), so use it as usual.

| Topic type | First choice | Second choice | Notes |
|---|---|---|---|
| Official specs / API docs | `webread` (direct URL) | `research-agent` (WebSearch) | Static and stable; fastest when the URL is known |
| GitHub Issues / Releases / PRs | `research-agent` (WebSearch) | `gh` CLI (via Bash, if permitted) | |
| GitHub code contents | clone via `gh` CLI | `webread` raw URL | |
| X / Twitter (community reactions) | **Claude in Chrome** (login required) | `WebSearch` (public info only) | Confirm with the user if login is needed |
| Slack / Discord / internal tools | **Claude in Chrome** (login required) | — | Always confirm with the user |
| Academic papers / peer-reviewed journals / preprints (by field) | `research-agent` (field-specific academic venues) | `webread` (direct paper URL) | Field-specific venues and site: filters in [`references/academic-sources.md`](references/academic-sources.md). Do not mix with engineering sources |
| SPA / dynamic sites / JS rendering required | **Claude in Chrome** → `webread --html` | — | trafilatura handles static pages only; pass the post-render HTML |
| Stack Overflow / tech blogs | `WebSearch` → `webread` | `research-agent` | |
| Japanese sources (Qiita / Zenn / Hatena) | `WebSearch` (ja query) | `research-agent` | |
| **High-stakes / contested / claims must be refuted** (truth affects a business/safety decision) | **`deep-research`** (high-verification path → below) | `research-agent` (WebSearch) | Adversarial 3-vote verification. Expensive → confirm before launch |

### When to use Claude in Chrome

`webread` / `WebSearch` are insufficient when any of the following apply:
- Login required (X, Slack, internal tools, paywalled docs)
- JS dynamic rendering is mandatory (SPA, comment sections, interactive UI)
- Scrolling / clicking / form submission is needed

→ Use the `mcp__claude-in-chrome__*` tools (load their schemas first via `ToolSearch`).

## High-verification path: `deep-research` (adversarial verification for high-stakes topics)

For topics where claim accuracy drives a real decision, delegate to Claude Code's built-in **`deep-research`** Workflow — a deterministic 5-phase harness (Scope → Search → Fetch → **3-vote adversarial Verify** → Synthesize) that *refutes* each claim before keeping it. This is the rigor layer `research-agent` (cross-check only) lacks. **banto's job is to add what deep-research lacks: persistence + project-context integration** (deep-research returns an object and saves nothing).

### When to route here (weigh toward yes only if high-stakes)

- The truth of the claims affects a business / safety / compliance decision
- The field is contested, sources disagree, or marketing/PR claims dominate
- Citation accuracy matters (deep-research agents hallucinate URLs at ~10% — the adversarial Verify pass is what kills those)

### When NOT to (default to `research-agent`)

- Routine research — deep-research is **heavy** (~100 agents / ~4M tokens / ~20 min per run; well past the normal $2 cap)
- Speed-sensitive or light fact-checks (one `webread` / `WebSearch` is enough)
- Context-integration is the main goal (`research-agent` + store-first already covers it)

### How (orchestrator level only — this skill runs in the main loop)

1. **Cost gate (required)**: confirm with the user before launching — high cost (~4M tokens / ~20 min). This is the odd.yaml `deep-research launch` gate and a declared exception to the $2 budget.
2. **Sharpen the question first**: if underspecified, ask 2-3 clarifying questions (deep-research's own contract), then weave the answers into the args.
3. **Invoke** (from the main loop — `research-agent` *subagents cannot* call Workflow):
   ```
   Workflow({ name: "deep-research", args: "<refined question>" })
   ```
4. **Graceful fallback**: if the environment has no `deep-research` (older Claude Code), the Workflow call fails on name resolution → fall back to the normal parallel `research-agent` path. Never hard-fail.
5. **Persistence wrapper (this is the integration — required)**: deep-research **saves nothing**; it returns `{ summary, findings[], caveats, sources, stats }`. You **must** reshape that object into the standard research doc and save it to `{BASE}/docs/research/{YYYY-MM-DD}_{slug}.md` (deep-research template in [`references/output-format.md`](references/output-format.md)). Preserve per-finding confidence + vote and the refuted-claims list (transparency).
6. **Store-first integration**: after saving, check consistency against past `decisions/` and existing research, and report it (same as the normal path). This is what turns a one-off report into accumulated knowledge.

## Pre-research context check (always run before external research)

### Step 0: Check existing context

Before starting external research, check the following **in parallel**. If what we already have answers the question, skip or shrink the external research:

1. **WS related documents**: Read the `## 関連ドキュメント` (related documents) section of `.ai-context/WORKSPACE.md` for file paths or URLs related to the research topic
2. **Existing research**: Glob `.ai-context/docs/research/` for prior research on the topic (if found, Read it and judge freshness / coverage)
3. **Decision logs**: Glob `.ai-context/decisions/` for past decisions related to the topic
4. **active.md**: Read `.ai-context/tasks/active.md` to understand how the research topic relates to the current task

**Decision rules**:
- Existing research exists and is **within 14 days** → ask "Existing research found ({filename}, {date}). Update it?"
- Existing research exists but is **older than 14 days** → note that it is stale and switch to delta research (do not redo everything)
- WS related documents contain URLs → use those URLs as the primary sources for the matching subtopics in Step 1
- Related design decisions exist → mention the consistency between the findings and the past decisions in the final report

## Plan disclosure flow (self-driving)

Detailed steps: [`references/approval-flow.md`](references/approval-flow.md)

Key steps:
1. Decompose the research into 3-10 subtopics, state the medium for each, **present the plan as text and proceed** (post-hoc disclosure — no approval wait; prior confirmation is reserved for the gates declared in odd.yaml)
2. Login-required items (❗) **must** be confirmed with the user (odd.yaml gate)
3. Run the research in parallel (launch multiple Agents in a single message, `run_in_background=true` required; 8+ parallel agents needs confirmation — odd.yaml gate). Claude in Chrome runs in the parent session directly (subagents have no Chrome tools). **Every research-agent launch prompt must include `会話言語: {lang}`** (the user's conversation language) so the saved document matches it — subagents do not inherit the conversation language.

## Search rules

- Do not include version numbers ("React 18" → "React latest")
- Prefer English sources (the latest information appears in English first)
- Include the current year (e.g. `2026`) in search queries to get the latest
- Cross-check multiple sources (never conclude from a single source)
- Keep academic topics separate from engineering sources, and pass the field-specific venues from [`references/academic-sources.md`](references/academic-sources.md) (arXiv / alphaXiv / OpenReview for AI/CS; bioRxiv / medRxiv / PubMed / Nature for life sciences) into the research-agent launch prompt
- Never answer from cutoff knowledge alone (per `~/.claude/rules/evidence-first.md`)

## Output format

Detailed template: [`references/output-format.md`](references/output-format.md)

Save to: `.ai-context/docs/research/{YYYY-MM-DD}_{topic-slug}.md`

Elements: TL;DR / details / Sources / confidence (high/medium/low).
After saving, report **3-5** key findings to the user along with the saved path.
