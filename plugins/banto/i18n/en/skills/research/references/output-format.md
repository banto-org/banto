# research output format

> The template headings are a structural skeleton. Write the target document in the conversation language (the English headings may be translated into the target language).

Save the result to `{BASE}/docs/research/{YYYY-MM-DD}_{topic-slug}.md` under the ai-context base (`{BASE}` is the absolute path resolved by the steps in the agent body. Do not write to a relative `.ai-context/`).

## Template

```markdown
# {topic} research results

- **Research date**: YYYY-MM-DD
- **Researcher**: AI (Claude)
- **Medium used**: {official docs / GitHub / arxiv / X (Chrome) / WebSearch}

## TL;DR
{3-5 line summary}

## Details

### {subtopic 1}
{content}
- Source: [title](URL)

### {subtopic 2}
...

## Information obtained via Claude in Chrome (if applicable)
{information from login-required sites, capture summaries, etc.}

## Sources
- [Source 1](URL)
- [Source 2](URL)

## Confidence
- **High**: official docs, README/CHANGELOG of major projects
- **Medium**: well-known tech blogs, Stack Overflow answers (accepted)
- **Low**: personal opinions on social media, old blogs
```

## Template for saving the deep-research (high-verification path) return value

Since deep-research (the Workflow) **does not save**, format the return-value object (`summary` / `findings[]` / `caveats` / `sources` / `refuted[]` / `stats`) as below and save it to `{BASE}/docs/research/{YYYY-MM-DD}_{slug}.md` (this is the body of the banto integration = persistence).

```markdown
# {topic} research results (deep-research, high-verification)

- **Research date**: YYYY-MM-DD
- **Medium used**: deep-research (5 phases, 3-vote adversarial verification)
- **Verification stats**: sources {stats.sourcesFetched} / claims extracted {stats.claimsExtracted} / confirmed {stats.confirmed} / killed {stats.killed}

## TL;DR
{summary as-is, or summarized}

## Verified findings
### {finding.claim}
- Confidence: {finding.confidence} / Vote: {finding.vote}
- Evidence: {finding.evidence}
- Sources: {finding.sources as a bullet list}

## Caveats
{caveats}

## Refuted claims (for transparency)
- {refuted[].claim} (vote {refuted[].vote} / {refuted[].source})

## Sources
- {sources listed as URL + quality}

## Confidence
- Adopt deep-research's confidence (high/medium/low) as-is. URLs may be hallucinated, so verify link health for important citations
```

After saving, check and report consistency against past `decisions/` / existing research (store-first integration).

## Report the key findings

After creating the document, report **3-5** key findings to the user. Always tell them the saved path too.
