---
name: research
description: |
  Research external sources (Web / GitHub / arxiv / X, etc.) from scratch and document the results (external research / going out to fetch new information). If you only want to look over an existing .ai-context/, use the search skill. Always check the local store first with the `search` skill, and escalate to the web only when there is no confident hit (store-first).
  Triggers: "look this up", "the latest ...", "what's the current state of", "best practices", "papers", "trends", "compare these libraries/technologies", "which is better", "research". Also invocable via /research <topic>.
  Do not use when: you only need to search an existing local AI Context (.ai-context/ decisions / docs / past conversations) — that's the search skill (no web access). A bare "tell me about" regarding the project's own code is answered directly or with the search skill.
user-invocable: true
argument-hint: "[research topic]"
model: opus
allowed-tools: Read Write Glob Agent WebSearch Bash Workflow
compatibility: Claude Code (requires bash, git, jq)
---

# Research — External Research Skill

> **Storage base (store-first)**: the `.ai-context/docs/research/...` path this skill saves to points at the ai-context base. Read/Write under the absolute path that the SessionStart/PreCompact hook injects as "ai-context base: &lt;absolute path&gt;" — never write to a relative `.ai-context/` (it only exists in old legacy repos; when unsure, resolve it with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Write in the user's conversation language (Japanese if the user is conversing in Japanese): this applies to your replies, the findings you report, **and the research documents you save**. Pass that language to research-agent in the launch prompt (subagents do not inherit the conversation language).

## search vs research

| | `/search` | `/research` (this skill) |
|---|---|---|
| Scope | **Internal**: `.ai-context/` (decisions/ + docs/ + past conversation history) | **External**: Web, GitHub, arxiv, X, official docs |
| Web access | **None** | Yes |
| Result | Returns references / summaries of existing files | Saves a new file under `.ai-context/docs/research/` |
| Time | Seconds | Minutes (launches research-agent in parallel) |

**Mnemonic**: do you already have it, or not? If you don't have it, use `research`.

## Principles

1. **Parallel execution**: run each research item with the Agent tool (research-agent), **5–10 in parallel at once**
2. **Always look for the latest**: don't rely on the knowledge cutoff — always go fetch the latest with WebSearch
3. **Choose the right medium**: pick the best research tool per topic (table below)
4. **Confirm login-required research in advance**: for media that require authentication (X/Twitter, etc.), get the user's approval first
5. **Always cite the source URL**: information without a source has no value
6. **Document the results**: save to `.ai-context/docs/research/{YYYY-MM-DD}_{topic}.md` (don't leave it in conversation only)

## Choosing the research medium

Classify the topic before choosing a tool. Picking the wrong medium drops quality sharply:

> **Don't use WebFetch to fetch a URL's contents** (a small model summarizes the page, so you can't verify the full text).
> To read a URL, use `webread` (`sh "$CLAUDE_PLUGIN_ROOT/scripts/webread.sh" "<URL>"`, full-text extraction via trafilatura).
> WebSearch is for *finding* URLs (no summarization problem), so use it as usual.

| Topic type | First choice | Second choice | Notes |
|---|---|---|---|
| Official specs / API docs | `webread` (direct URL) | `research-agent` (WebSearch) | Static and stable. Fastest if you already know the URL |
| GitHub Issues / Releases / PRs | `research-agent` (WebSearch) | `gh` CLI (via Bash, if permitted) | |
| GitHub code contents | clone with `gh` CLI | `webread` raw URL | |
| X / Twitter (community reactions) | **Claude in Chrome** (login required) | `WebSearch` (public info only) | If login is required, confirm with the user |
| Slack / Discord / internal tools | **Claude in Chrome** (login required) | — | Always confirm with the user |
| Academic papers / peer-reviewed journals / preprints (by field) | `research-agent` (field-specific academic venues) | `webread` (direct paper URL) | Field-specific references and site: filters are in [`references/academic-sources.md`](references/academic-sources.md). Don't mix with engineering sources |
| SPA / dynamic sites / JS rendering required | **Claude in Chrome** → `webread --html` | — | trafilatura handles static pages only. Pass the post-render HTML |
| Stack Overflow / technical blogs | `WebSearch` → `webread` | `research-agent` | |
| Japanese sources (Qiita / Zenn / Hatena) | `WebSearch` (ja query) | `research-agent` | |
| **Critical / contested / claims need refutation** (truth drives business/safety decisions) | **`deep-research`** (high-verification path → see below) | `research-agent` (WebSearch) | Adversarial 3-vote verification. High cost → confirm before launching |

### When to use Claude in Chrome

If any of the following apply, `webread` / `WebSearch` is not enough:
- Login required (X, Slack, internal tools, paywalled docs)
- JS dynamic rendering is required (SPA, comment sections, interactive UI)
- Scrolling / clicking / form submission needed

→ Use the `mcp__claude-in-chrome__*` tools (load the schema first with `ToolSearch`).

## High-verification path: `deep-research` (adversarial verification for critical topics)

For topics where the accuracy of a claim drives a real decision, delegate to Claude Code's built-in **`deep-research`** Workflow — a deterministic 5-phase harness (Scope → Search → Fetch → **3-vote adversarial Verify** → Synthesize) that *refutes* each claim before adopting it. This is the layer of rigor that `research-agent` (cross-check only) lacks. **banto's job is to add what deep-research is missing: persistence + project-context integration** (deep-research only returns an object and saves nothing).

### When to route here (lean yes only when it's critical)

- The truth of a claim drives a business / safety / compliance decision
- The field is contested, sources disagree, or marketing/PR claims dominate
- Citation accuracy matters (deep-research agents hallucinate URLs ~10% of the time — the adversarial Verify pass kills those)

### When not to route here (default is `research-agent`)

- Normal research — deep-research is **heavy** (~100 agents / ~4M tokens / ~20 min per run; far beyond the usual $2 cap)
- Speed-first / light fact-check (a single `webread` / `WebSearch` is enough)
- Context integration is the main goal (already covered by `research-agent` + store-first)

### How (orchestrator level only — this skill runs in the main loop)

1. **Cost gate (required)**: confirm with the user before launching — it's expensive (~4M tokens / ~20 min). This is the odd.yaml `deep-research launch` gate, a declared exception to the $2 budget.
2. **Sharpen the question first**: if it's unclear, ask 2–3 clarifying questions (deep-research's own contract). Weave the answers into args.
3. **Launch** (from the main loop — a `research-agent` *subagent* *cannot* call Workflow):
   ```
   Workflow({ name: "deep-research", args: "<精緻化した問い>" })
   ```
4. **Graceful fallback**: if the environment lacks `deep-research` (older Claude Code), the Workflow call fails on name resolution → fall back to the normal parallel `research-agent` path. Never hard-fail.
5. **Persistence wrapper (this is the heart of the integration — required)**: deep-research **saves nothing**. It returns `{ summary, findings[], caveats, sources, stats }`. You **must** format that object into a standard research document and save it to `{BASE}/docs/research/{YYYY-MM-DD}_{slug}.md` (the deep-research template is in [`references/output-format.md`](references/output-format.md)). Keep per-finding confidence + votes and the list of rejected claims (transparency).
6. **store-first integration**: after saving, check and report consistency against past `decisions/` and existing research (same as the normal path). This turns a one-off report into accumulated knowledge.

## Pre-context check (always run before external research)

### Step 0: run the `search` skill first (the first store-first gate)

Before starting external research, **first launch the `search` skill to check the local store** (lookup order 1 of the evidence-first rule. Call `search`, not manual Glob/Read — `search` is what owns lexicon expansion and ranking):

1. **Launch the `search` skill** (equivalent to `/search <research topic>`; pass the topic as the query). `search` tier-expands and ranks `{base}/decisions/` `{base}/docs/` (including past research) + conversation history, then Read-verifies and returns the top hits
2. The `search` results contain a **confident hit** that answers the question → **skip** external research and answer with that
3. There are **only some** confident hits → settle the answerable parts with the store results and send only the remaining subtopics to external research (narrowed)
4. `search` returns **zero confidence** (confident: false) → proceed to external research (Step 1 onward)

Supplementary checks (for context `search` may miss — optional, can run in parallel):
- **WS related documents**: check whether `{base}/WORKSPACE.md`'s `## 関連ドキュメント` section has a URL that could serve as a primary source for the topic (if so, use it as that subtopic's primary source in Step 1)
- **active.md**: Read the current task file to understand how the research topic relates to the current task

**Decision rules**:
- `search` surfaces existing research **within 14 days** → ask "I found existing research ({filename}, {date}). Update it?"
- `search` surfaces existing research but it's **older than 14 days** → note that it's stale and switch to differential research (don't redo everything)
- WS related documents contain a URL → use that URL as the primary source for that subtopic in Step 1
- `search` surfaces a relevant design decision → mention the consistency between your findings and the past decision in the final report

## Plan disclosure flow (self-driving)

Detailed steps: [`references/approval-flow.md`](references/approval-flow.md)

Key steps:
1. Break the research into 3–10 subtopics, specify the medium for each, and **present the plan as text and continue** (post-hoc disclosure — don't wait for approval; advance confirmation is limited to the odd.yaml-declared gates)
2. **Always** confirm login-required items (❗) with the user (odd.yaml gate)
3. Run the research in parallel (launch multiple Agents in one message, `run_in_background=true` required. 8 or more in parallel needs confirmation — odd.yaml gate). Run Claude in Chrome directly in the parent session (subagents don't have the Chrome tools). **Include `conversation language: {lang}` (the user's conversation language) in every research-agent launch prompt** — so the saved documents match it. Subagents do not inherit the conversation language.

## Search rules

- Don't include version numbers ("React 18" → "React latest")
- Prefer English sources (the latest info appears in English first)
- Include the current year (e.g. `2026`) in the search query to fetch the latest
- Cross-check multiple sources (don't conclude from a single source)
- Keep academic topics separate from engineering sources, and pass the field-specific venues from [`references/academic-sources.md`](references/academic-sources.md) (arXiv / alphaXiv / OpenReview for AI/CS, bioRxiv / medRxiv / PubMed / Nature for life sciences) into the research-agent launch prompt
- Don't answer from cutoff knowledge alone (follow `~/.claude/rules/evidence-first.md`)

## Output format

Detailed template: [`references/output-format.md`](references/output-format.md)

Save to: `.ai-context/docs/research/{YYYY-MM-DD}_{topic-slug}.md`

Elements: TL;DR / details / Sources / confidence (high/medium/low).
After saving, report **3–5** key findings to the user along with the save path.
