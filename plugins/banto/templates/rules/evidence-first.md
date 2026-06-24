# Evidence First Rule

This is a **work default, not just a reply rule**. It applies *during any task* — implementation, design, fixes, reviews — not only when someone explicitly asks an information question. **Never act on cutoff knowledge alone when that knowledge may be stale or missing.** The moment you would lean on a remembered fact (a version, an API shape, a past project decision, a "best practice"), verify it in the order below **before** you rely on it.

## Trigger (when this kicks in, mid-task included)

During any task, the instant you notice you are about to rely on knowledge that **might be stale or missing** — e.g. "I think the latest is vX", "the API works like Y", "we decided Z before", "the idiom here is W" — stop and run the lookup order first. Don't wait to be asked; this is the default working posture.

## Lookup order (strict)

1. **Search the local store first** — run the `search` skill (`/search <query>`); it expands the query into tiers, grep-scores `{base}/decisions/` + `{base}/docs/` (existing research lives there too), and Read-verifies the top hits. This covers prior decisions, past research, and project history.
2. **Escalate to the web for freshness-critical domains** — when `search` returns no confident hit **and** the fact is freshness-sensitive (AI / LLM behavior, library or framework versions, release notes, "best practice", trends, comparisons), delegate to the `research` skill. Its own step 1 *is* literally "run the `search` skill" (same first gate), and it only escalates to the web when `search` returns no confident hit; it launches `research-agent` as a subagent, keeping the parent session's tokens free.

For non-freshness-critical, purely-internal questions ("what did we decide", "why is it this way"), step 1 alone is the whole order — don't escalate to the web; if `search` finds nothing, say so plainly.

`{base}` is the ai-context base injected at SessionStart. The skills own the mechanics (lexicon expansion, the `Agent(...)` invocation, webread close-reading) — this rule only fixes the order: `search` first, then (for freshness-critical gaps) `research`. WebFetch is blocked deterministically (`webfetch-deny.sh`) because it returns an unverifiable small-model summary; WebSearch is fine for *finding* URLs (a soft `websearch-gate.sh` reminder nudges you to run `search` first; it never blocks — silence with `BANTO_ALLOW_WEBSEARCH=1`), but large investigations go to research-agent.

## Forbidden

- ❌ Answering from your own cutoff knowledge alone
- ❌ Running large WebSearch investigations directly from the main Claude session (delegate to research-agent)
- ❌ Answering on vague grounds like "it is generally said that..."
- ❌ Asserting with "probably" / "maybe"

## Scope

**Applies to** (whether asked directly *or* surfacing mid-task):
- Technical information questions ("What's the latest React?")
- Best-practice questions ("What's the best practice for ...?")
- Library / tool comparisons
- Version / release information
- Trends and current developments
- **Mid-implementation reliance on stale/missing knowledge** — about to write code against a remembered API/version, or a remembered past decision, that you have not verified. Verify (step 1, and step 2 if freshness-critical) before committing to it; the `dependencies` rule still governs the implementation itself.

**Does not apply to**:
- Mechanical file edits / fixes that rely on no external or remembered fact
- Questions answerable purely from the code in front of you (project-local code search suffices)
- Simple greetings or chit-chat
