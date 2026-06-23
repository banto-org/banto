# Saving decisions (auto-save rules / format / secrets)

<!-- merged from auto-save-rules.md -->
## Auto-save rules

Save **immediately** when a design decision occurs. No waiting for a commit. Auto-create `.ai-context/` if absent. Do not ask for permission.

## What to save

- Decisions on design policy ("let's go with B instead of A")
- Technology choices
- Architecture changes
- Trade-off discussions and conclusions
- Root causes of problems

## What not to save

Simple implementation work, typo fixes, plain factual answers only.

## Destination

`.ai-context/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md`

## Naming rule (second-precision timestamp, v5.21.4+)

- The file name is made unique with a second-precision time (`YYYY-MM-DD-HHMMSS_topic_author`). It avoids same-day collisions even with parallel teams / offline (the NNN sequence number is abolished)
- The recommended name is injected into context by the `ai-context-decisions-numbering.sh` hook at PreToolUse
- Existing files in the old `YYYY-MM-DD_NNN_` (sequence) format remain valid (no rename needed)

## Procedure for deciding the file name

1. The PreToolUse hook displays the "recommended file name (second-precision timestamp)"
2. Write `YYYY-MM-DD-HHMMSS_{topic}_{user}.md` with that name
3. The PostToolUse hook verifies the naming rule (if it starts with a date but violates the convention, it suggests a `git mv`)

The GitHub account name is `gh api user --jq '.login'`, falling back to `git config user.name` on failure.

<!-- merged from decision-log-format.md -->
## Decision Log format

## Lightweight (small decision)

```markdown
## {title}

- **Date**: YYYY-MM-DD
- **Tags**: architecture, security, performance, etc.

## Decision
{what was decided and why. 2-3 lines}
```

## Full (large decision, including Glaser friction)

```markdown
## {title}: {one-line summary of the decision}

- **Date**: YYYY-MM-DD
- **Tags**: architecture, security, performance, etc.

## Starting point
{why this decision became necessary}

## Options considered

| Option | Pros | Cons |
|---------|----------|------------|
| A | ... | ... |
| B | ... | ... |

## Deciding factor
{which one was ultimately chosen, and why}

## Why the rest were dropped
{the reasons the other options were not adopted}

## Friction (the unease / detours before & during the work — Glaser-style)
{record failures, detours, "I got stuck here", "it differed from what I expected". This is the heart of the learning}

## What was learned
{insights to carry into next time, reusable patterns, pitfalls to avoid}
```

## Why leave friction in (from Robert Glaser, "When Everyone Has AI")

> "By the time the story is cleaned up enough to become a best-practice slide, the important learning has often lost its teeth. What made it useful was the friction: the missing context, the test that failed, the weird API behavior, the moment where the agent sprawled into nonsense and someone had to pull it back."

"The reasons for adoption" alone hollow out explicit knowledge. Leaving friction (failures, frictions) in is the essence of organizational learning.

Details: https://www.robert-glaser.de/when-everyone-has-ai-and-the-company-still-learns-nothing/

<!-- merged from secrets.md -->
## Handling secrets

## When saving (decisions/, checkpoints, etc.)

**Do not write** tokens like the following into design decision logs or checkpoints:
`sk-*`, `ghp_*`, `Bearer *`, values inside `.env`, API keys, connection strings, etc.
When needed, replace them with a placeholder like `{SECRET}` or `[MASKED]`.

## When displaying (terminal / chat output)

The risk of remaining in chat history is the same as when saving. Always mask when outputting values via Bash too:

- **Forbid raw output** like `cat .env` / `diff .env .env.old` / `grep = .env`
- When values are needed, print only key names with `sed 's/=.*/=***/' .env`
- For diffs, mask both sides before `diff`
- Restrict `grep` to prefixes (e.g. `grep "^AWS_"`), without sweeping in token-family (`*_TOKEN`, `*_API_KEY`, `*_SECRET`, `Bearer *`)
- **Forbid debug traces**: `bash -x` / `set -x` / `env` / `printenv` / `declare -p` leak `.env`-derived values into the trace and they remain in chat. Print only the length of individual variables with `echo "KEY=[${#VAR} chars]"`, or substitute with a stub like `LAMBDA_API_KEY=dummy bash script.sh`

For details, see `~/.claude/rules/safety.md` (deployed by harness-setup.sh).

## When exposed

If a value remains in chat history / logs / files, immediately notify the user and **strongly recommend revoke / rotation**. Deleting from history alone is insufficient (external caches may remain).

