# Writing for the audience level (L1 / L2 / L3)

For a Japanese document, "who reads it" fixes the form before "what to write" does. Before writing,
pin the audience to one of L1 (non-technical: executives, sales, clients), L2 (semi-technical: PMs,
IT staff, procurement), or L3 (technical: engineers), and never mix levels within one document.

## How to decide

If the reader writes code, it's L3. If they don't write code but judge system architecture, it's
L2. If they only judge cost and impact, it's L1. When unsure, drop one level (if torn between L3
and L2, pick L2).

## The same fact, three ways

Fact to convey: "Replaced the search index with SQLite FTS5; search went from an average 1.8s to 0.3s."

L1 (non-technical) — impact and cost only, no technical nouns:
> Document search wait time cut from an average 1.8 seconds to 0.3 seconds. No added cost, existing data unchanged.

L2 (semi-technical) — what changed, without the internal mechanism:
> Replaced the search mechanism with a full-text search database (SQLite FTS5); average response
> time went from 1.8s to 0.3s. No additional server needed, and the existing search screen is unchanged.

L3 (technical) — down to the rationale and how to reproduce it:
> Replaced sequential grep scanning with SQLite FTS5 (trigram tokenizer). 1.8s → 0.3s average over
> 100,000 documents (bench/search-bench.sh, n=30). The index updates incrementally via a commit
> hook; a full rebuild takes 40 seconds.

## What each level forbids

L1 never uses technical nouns or English abbreviations (if unavoidable, describe it by function,
e.g. "the full-text search mechanism"). L2 never goes into implementation internals (tokenizer
names, algorithm names). L3 does the opposite — never omit the rationale (measurement conditions,
sample size, the reproduce command); an L3 document without evidence isn't trusted.

Common to every level: use exact numbers ("1.8 seconds", never "about 2 seconds"), and always show
impact as a before → after pair.
