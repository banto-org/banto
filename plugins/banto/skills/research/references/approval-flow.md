# Plan disclosure flow (research)

Prior approval is limited to the 4 gates declared in odd.yaml (login-required medium / 8+ parallel / **deep-research launch** / overwriting an existing file).
The plan itself is **presented as text and proceeds** (post-hoc disclosure. CONCEPT "approvals stay minimal").

## When routing to the deep-research path (high-cost gate)

When a subtopic is high-risk / refutation-required and gets routed to **deep-research** (the high-verification Workflow), mark it with ❗ just like a login-required medium, and **always confirm with the user before launching** (an odd.yaml gate. High cost of ~4M tokens / ~20 min):

> "{topic} is a critical topic that needs refutation verification, so I'll investigate it with deep-research (high-verification, high-cost: ~4M tokens / ~20 min). Is that OK? If the normal research-agent parallel path is fine, I'll go with that instead."

- **Yes** → launch `Workflow({ name: "deep-research", args: "<refined question>" })` **from the parent (main loop)** → save the return value with the deep-research template in output-format.md to `{base}/docs/research/`
- **No** → switch to the research-agent parallel path (Step 3)
- deep-research not present in the environment → the Workflow fails to resolve → automatic fallback to the research-agent path (report that)

## Step 1: Decompose the research items and present the plan (do not wait for approval)

Based on the result of Step 0, decompose `$ARGUMENTS` into 3-10 subtopics, and clearly state the **medium to use** for each subtopic. For information already found in Step 0, append "already have info" and target only the missing parts for external research:

```
I will research the following (tell me if you want to change any item — otherwise I'll proceed):

1. {subtopic 1} — medium: official docs (webread)
2. {subtopic 2} — medium: GitHub Issues (research-agent + WebSearch)
3. {subtopic 3} — medium: X (Claude in Chrome, login required) ← ❗ confirmation needed (odd.yaml gate)
4. {subtopic 4} — medium: arxiv (research-agent)
5. {subtopic 5} — medium: tech blogs (WebSearch)

* When using Claude in Chrome, the Chrome extension must be logged in.
* Without a logged-in state, the matching items fall back to public information only.
```

If there is not a single ❗ item, proceed straight to Step 3 (skip Step 2).

## Step 2: User confirmation for login-required items

For the items marked ❗ above, **always** ask the user:

> "To investigate {subtopicX}, access while logged in to {service name} is required. May I proceed with Claude in Chrome?"

- **Yes** → investigate with Claude in Chrome
- **No** → switch that item to WebSearch public info only (note that result quality drops)
- **Skip** → drop that item from the research targets

## Step 3: Parallel research execution

**The parent resolves this once before launch (a mandatory contract)**: since subagents have neither the SessionStart injection nor `$CLAUDE_PLUGIN_ROOT`,
the parent (research skill) resolves `BASE` (the ai-context base. The SessionStart injection value or `_ai-context-paths.sh --resolve`) and
`WEBREAD` (the absolute path of `$CLAUDE_PLUGIN_ROOT/scripts/webread.sh`), and **always embeds them in each prompt**.

**Send multiple Agent tool calls simultaneously within a single message** to run them in parallel:

```
// Always call them all simultaneously in a single message (sequential execution is forbidden)
// Each prompt must include the "save destination" and the "webread path"
Agent(subagent_type="research-agent", run_in_background=true,
  prompt="Research subtopic 1, centered on official docs. Save to: {base}/docs/research/{YYYY-MM-DD}_{slug1}.md. webread: sh {WEBREAD} <URL>")
Agent(subagent_type="research-agent", run_in_background=true,
  prompt="Research subtopic 2 via GitHub Issues. Save to: {base}/docs/research/{YYYY-MM-DD}_{slug2}.md. webread: sh {WEBREAD} <URL>")
// launch 5-10 simultaneously
```

**Important**: always specify `run_in_background=true`, and integrate the results only after waiting for the completion notifications of all agents.

Items that need Claude in Chrome are **executed directly in the parent session** (subagents do not have Chrome tools):

```
// Load the schemas first with ToolSearch
ToolSearch(query="select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__get_page_text")
// Then research with the Chrome tools
```
