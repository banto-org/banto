# Evidence First Rule

When asked for information, never answer from cutoff knowledge alone. **Always verify the facts in the following order before** answering.

## Lookup order (strict)

1. **Search the local store first** — run the `search` skill (`/search <query>`); it expands the query into tiers, grep-scores `{base}/decisions/` + `{base}/docs/` (existing research lives there too), and Read-verifies the top hits.
2. **Web only if step 1 finds nothing** — delegate to the `research` skill. Its own step 1 *is* literally "run the `search` skill" (same first gate), and it only escalates to the web when `search` returns no confident hit; it launches `research-agent` as a subagent, keeping the parent session's tokens free.

`{base}` is the ai-context base injected at SessionStart. The skills own the mechanics (lexicon expansion, the `Agent(...)` invocation, webread close-reading) — this rule only fixes the order: `search` first, then `research`. WebFetch is blocked deterministically (`webfetch-deny.sh`) because it returns an unverifiable small-model summary; WebSearch is fine for *finding* URLs (a soft `websearch-gate.sh` reminder nudges you to run `search` first; it never blocks — silence with `BANTO_ALLOW_WEBSEARCH=1`), but large investigations go to research-agent.

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
