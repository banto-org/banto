# Saving decisions (auto-save rules / format / secrets)

<!-- merged from auto-save-rules.md -->
## Auto-save rules

Save **immediately** when a design decision occurs. Don't wait for a commit. If the base (store / provisional local side) hasn't been created yet, scaffold creates it automatically (don't write to a relative `.ai-context/`). Don't ask for permission.

## Style — no verbatim quotes

- Never transcribe conversational remarks verbatim. **Round them to their substance**
  - ✗ owner said: "handle this one together too"
  - ✓ owner instruction (summary): handle issue #109 in the same PR
- If colloquial phrasing survives inside quotation marks, rewrite it. A decision is an artifact —
  the canon that later sessions search and learn from — and colloquial residue lowers its quality
- The `ja-lint` hook warns on colloquial quotes in writes under decisions/ (deterministic backstop)

## What to save

- Decisions on design direction ("let's go with B instead of A")
- Technology selection
- Architecture changes
- Trade-off discussions and conclusions
- Root causes of problems

## What not to save

Simple implementation work, typo fixes, and plain factual answers only.

## Where to save

`{base}/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md`

## Naming convention (second-precision timestamp, v5.21.4+)

- Filenames are made unique with a second-precision time (`YYYY-MM-DD-HHMMSS_topic_author`). No same-day collisions even under team concurrency or offline work (the NNN sequence number is retired)
- The recommended name is injected into context at PreToolUse by the `ai-context-decisions-numbering.sh` hook
- Existing files in the old `YYYY-MM-DD_NNN_` (sequence-number) format stay valid (no rename needed)

## Procedure for deciding the filename

1. The PreToolUse hook shows the "recommended filename (second-precision timestamp)"
2. Write `YYYY-MM-DD-HHMMSS_{topic}_{user}.md` under that name
3. The PostToolUse hook validates the naming convention (if it starts with a date but is otherwise off-convention, it suggests a recommended `git mv`)

For the GitHub account name use `gh api user --jq '.login'`, falling back to `git config user.name` on failure.

<!-- merged from decision-log-format.md -->
## Decision Log format

## Lightweight (small decisions)

```markdown
## {タイトル}

- **日付**: YYYY-MM-DD
- **タグ**: architecture, security, performance, etc.

## 判断
{何を決めたか、なぜか。2〜3行}
```

## Full (large decisions — fixed skeleton, checked by the section hook)

```markdown
---
status: accepted        # accepted | provisional
date: YYYY-MM-DD
topic: {one-line summary}
supersedes: []          # older decisions this replaces (optional; freshness truth is the filename date — this is a traversal link)
relates: []
---

# {Title}: {one-line summary of the decision}

## Background
{Why this decision became necessary (the starting point)}

## Decision
{What was decided. One decision per file, assertive}

## Rationale
{The deciding factor. Why this option won}

## Considered Alternatives

| Option | Summary | Rejection reason |
|---|---|---|
| A | ... | ... |
| B | ... | ... |

## Consequences and Limits
{Impact of this decision, known limits and trade-offs}

## Friction (pre/mid-work detours and surprises, per Glaser)
{Keep the failures, detours, "stuck here", "not what I expected". This is the real learning. Optional}

## Lessons
{Reusable insights and pitfalls for next time. Optional}

## Verification
{How it was confirmed / what counts as green. Optional}
```

**Why a fixed skeleton** (decision 2026-07-17): (1) search queries like "why didn't we do X" hit "Considered Alternatives + rejection reason" directly; (2) for future training-data export ([B-03] export skill), the section headings become the mechanical extraction units for decision-context pairs / synthetic QA generation. **Required 4 sections = Background / Decision / Rationale / Considered Alternatives** (the rest are optional). Missing sections are warned by the `ai-context-decisions-numbering.sh` hook (warn-only; small decisions in the lightweight format below are exempt).

## Why leave friction in (from Robert Glaser's "When Everyone Has AI")

> "By the time the story is cleaned up enough to become a best-practice slide, the important learning has often lost its teeth. What made it useful was the friction: the missing context, the test that failed, the weird API behavior, the moment where the agent sprawled into nonsense and someone had to pull it back."

Recording only "the reason it was adopted" hollows out the explicit knowledge. Leaving friction (failures, things that felt off) is the essence of organizational learning.

Details: https://www.robert-glaser.de/when-everyone-has-ai-and-the-company-still-learns-nothing/

<!-- merged from secrets.md -->
## Handling secrets

## When saving (decisions/, checkpoints, etc.)

Do **not** write tokens like the following into decision logs or checkpoints:
`sk-*`, `ghp_*`, `Bearer *`, values inside `.env`, API keys, connection strings, and the like.
When needed, replace them with a placeholder like `{SECRET}` or `[MASKED]`.

## When displaying (terminal / chat output)

The risk of it staying in chat history is the same as when saving. Always mask values when printing them via Bash too:

- **Forbid raw output** like `cat .env` / `diff .env .env.old` / `grep = .env`
- When values are needed, print key names only with `sed 's/=.*/=***/' .env`
- For diffs, mask both sides before running `diff`
- Restrict `grep` to prefixes (e.g. `grep "^AWS_"`) so token-like values (`*_TOKEN`, `*_API_KEY`, `*_SECRET`, `Bearer *`) aren't swept in
- **No debug traces**: `bash -x` / `set -x` / `env` / `printenv` / `declare -p` leak `.env`-derived values into the trace, which then stays in chat. Print only the length of an individual variable with `echo "KEY=[${#VAR} chars]"`, or substitute a stub like `LAMBDA_API_KEY=dummy bash script.sh`

See `~/.claude/rules/safety.md` (deployed by harness-setup.sh) for details.

## If a secret gets exposed

If a value ends up in chat history, logs, or files, notify the user immediately and **strongly recommend revoke / rotation**. Deleting it from history alone isn't enough (external caches may remain).
