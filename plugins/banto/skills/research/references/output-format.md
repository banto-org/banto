# research output format

> The template headings are a structural skeleton. Write the target document in the conversation language (English headings may be translated into the target language).

Save the result under the ai-context base at `{base}/docs/research/{YYYY-MM-DD}_{topic-slug}.md` (`{base}` is the absolute path resolved by the steps in the agent body. Don't write to a relative `.ai-context/`).

## Required: always keep URLs in `## Sources` (verification path)

Every research you save **without exception** must have a `## Sources` section listing the URLs of the primary sources you referenced (information without a source has no value). At the top of each Sources section, add a one-line affordance so a human/agent can re-verify the body text:

```markdown
## Sources

> Verify: re-check each source's body with `/webread <url>` (trafilatura full-text fetch, no LLM summary).

- [Source 1](URL)
- [Source 2](URL)
```

## Template

```markdown
---
date: YYYY-MM-DD
topic: {one-line summary}
status: active        # flip to stale / superseded when it rots (search auto-demotes it)
sources: {number of primary URLs}
---

# {topic} research results

- **Date**: YYYY-MM-DD
- **Researcher**: AI (Claude)
- **Media used**: {official docs / GitHub / arxiv / X (Chrome) / WebSearch}

## TL;DR
{3-5 line summary}

## Details

### {subtopic 1}
{content}
- Source: [title](URL)

### {subtopic 2}
...

## Information obtained via Claude in Chrome (if applicable)
{information obtained from login-required sites, capture summaries, etc.}

## Sources
> Verify: re-check each source's body with `/webread <url>`.
- [Source 1](URL)
- [Source 2](URL)

## Confidence
- **High**: official docs, README/CHANGELOG of major projects
- **Medium**: well-known technical blogs, Stack Overflow answers (accepted)
- **Low**: personal opinions on social media, old blogs
```

## Template for saving the deep-research (high-verification path) return value

Because deep-research (Workflow) **saves nothing**, format its return object (`summary` / `findings[]` / `caveats` / `sources` / `refuted[]` / `stats`) into the form below and save it to `{base}/docs/research/{YYYY-MM-DD}_{slug}.md` (this is the core of the banto integration = persistence).

```markdown
# {topic} research results (deep-research high-verification)

- **Date**: YYYY-MM-DD
- **Media used**: deep-research (5 phases, 3-vote adversarial verification)
- **Verification stats**: sources {stats.sourcesFetched} / extracted claims {stats.claimsExtracted} / confirmed {stats.confirmed} / killed {stats.killed}

## TL;DR
{summary as-is, or summarized}

## Verified findings
### {finding.claim}
- Confidence: {finding.confidence} / votes: {finding.vote}
- Evidence: {finding.evidence}
- Sources: {finding.sources as a bullet list}

## Caveats
{caveats}

## Rejected claims (for transparency)
- {refuted[].claim} (votes {refuted[].vote} / {refuted[].source})

## Sources
> Verify: re-check each source's body with `/webread <url>` (especially since deep-research can hallucinate URLs, confirm important citations against the actual body with webread).
- {sources listed as URL + quality}

## Confidence
- Adopt deep-research's confidence (high/medium/low) as-is. Since URLs may contain hallucinations, check link health for important citations
```

After saving, check and report consistency against past `decisions/` / existing research (store-first integration).

## Report the key findings

After creating the document, report **3-5** key findings to the user. Always communicate the save path too.
