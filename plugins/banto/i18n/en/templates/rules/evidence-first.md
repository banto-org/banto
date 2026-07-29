# Evidence First Rule

This is a **work default, not just a reply rule**. The moment — mid-implementation, mid-design, mid-fix, mid-review — you would lean on a remembered fact that may be stale or missing (a version, an API shape, a past project decision, a "best practice") — "I think the latest is vX", "this API works like Y", "we decided Z before" — is the moment to verify it in the order below, **before** you rely on it. Run the order without waiting to be asked.

## Lookup order (strict)

1. **Search the local store first** — the `search` skill (`/search <query>`). This covers prior decisions, past research, and project history.
2. **Escalate to the web only for freshness-critical domains** — when `search` returns no confident hit **and** the fact is freshness-sensitive (AI / LLM behavior, library / framework versions, release notes, "best practice", trends, comparisons), delegate to the `research` skill. Its own step 1 is also "search first", so the store-first order is preserved.

For purely internal questions where freshness doesn't matter ("what did we decide", "why is it this way"), step 1 alone is the whole order — don't escalate to the web. If `search` finds nothing, say so plainly.

WebFetch is blocked deterministically (`webfetch-deny.sh` — it would return an unverifiable small-model summary). Read URL content with `webread` instead. WebSearch may be used to *find* URLs (`websearch-gate.sh` nudges you to run `search` first, but never blocks). Large investigations are delegated to research-agent.

## Forbidden

- Answering, or writing code, from cutoff knowledge alone
- Asserting with "it is generally said..." / "probably" / "maybe" (use "Unverified:" / 「未確認:」 when uncertain)
- Running large WebSearch investigations directly from the main session (delegate to research-agent)

Out of scope: mechanical file edits that don't rely on external or remembered facts, questions answerable purely from the code in front of you, and simple greetings or small talk.
