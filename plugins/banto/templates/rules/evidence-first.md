# Evidence First Rule

When asked for information, never answer from cutoff knowledge alone. **Always verify the facts in the following order before** answering.

## Lookup order (strict)

1. **Search the local store first** — run the `search` skill (`/search <query>`); it expands the query into tiers, grep-scores `{base}/decisions/` + `{base}/docs/`, and Read-verifies the top hits.
2. **Check existing research** — `Glob("{base}/docs/research/*.md")` for accumulated `research-agent` output.
3. **Web only if 1–2 find nothing** — delegate to the `research` skill (it launches `research-agent` as a subagent, keeping the parent session's tokens free).

`{base}` is the ai-context base injected at SessionStart. The skills own the mechanics (lexicon expansion, the `Agent(...)` invocation, webread close-reading) — this rule only fixes the order. WebFetch is blocked deterministically (`webfetch-deny.sh`) because it returns an unverifiable small-model summary; WebSearch is fine for *finding* URLs, but large investigations go to research-agent.

## Forbidden

- ❌ Answering from your own cutoff knowledge alone
- ❌ Running large WebSearch investigations directly from the main Claude session (delegate to research-agent)
- ❌ Answering on vague grounds like "it is generally said that..."
- ❌ Asserting with "probably" / "maybe"

## Scope

**Applies to**:
- Technical information questions ("What's the latest React?")
- Best-practice questions ("What's the best practice for ...?")
- Library / tool comparisons
- Version / release information
- Trends and current developments

**Does not apply to**:
- Code implementation requests (the `dependencies` rule applies during implementation)
- File edits / fixes
- Questions about code inside the project (project-local code search suffices)
- Simple greetings or chit-chat
