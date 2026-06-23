# Academic source venues (by field)

> A venue catalog for when research / research-agent investigates academic topics.
> Keep it separate from engineering sources (GitHub / Stack Overflow / technical blogs / official docs) — mixing them lowers search precision.
> The parent skill classifies the field and passes the matching cluster's venues into the research-agent launch prompt.

## Field clusters

### AI / machine learning / computer science

| venue | site: filter | role |
|---|---|---|
| arXiv | `site:arxiv.org` | First choice for preprints |
| alphaXiv | `site:alphaxiv.org` | Discussion / trends on arXiv papers; gauge community attention |
| OpenReview | `site:openreview.net` | NeurIPS / ICLR / ICML reviews and acceptances |
| Papers with Code | `site:paperswithcode.com` | Implementations / SOTA tracking |
| Semantic Scholar | `site:semanticscholar.org` | Citation graph / cross-field search |

### Life sciences / medicine / biology

| venue | site: filter | role |
|---|---|---|
| bioRxiv | `site:biorxiv.org` | Biology preprints |
| medRxiv | `site:medrxiv.org` | Medical preprints |
| PubMed | `site:pubmed.ncbi.nlm.nih.gov` | Peer-reviewed medicine / life sciences |
| Nature | `site:nature.com` | Peer-reviewed journal; prefer the latest issue |
| Science | `site:science.org` | Peer-reviewed journal |

### Cross-field / general

| venue | site: filter | role |
|---|---|---|
| Semantic Scholar / Google Scholar | `site:semanticscholar.org` / `site:scholar.google.com` | Cross-field search / citation tracking |
| Major peer-reviewed journals (PNAS / Cell / IEEE / ACM, etc.) | each journal's domain | Per field, with `{current_year}` |

## Rules for getting the latest

- For preprints (arXiv / bioRxiv / medRxiv), sort by date and add `{current_year}` to get the latest.
- For peer-reviewed journals (Nature / Science / PNAS), fetch the latest issue with "latest issue" / "`{current_year}`".
- Use alphaXiv / Papers with Code (trending / SOTA) to supplement with community attention.
- For each paper, always record the title, authors, date, abstract summary, and (if any) GitHub / Papers with Code links.

## When not to use

- Engineering / implementation topics → use GitHub / Stack Overflow / official docs, not this catalog.
- Mixed topics (e.g. implementing an ML library) → use both clusters, but clearly separate **papers → academic venues, implementation → GitHub**.
