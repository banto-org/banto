# Memo / knowledge templates

Fill-in Markdown templates written by the `memo` and `knowledge` subcommands. SKILL.md itself only
covers mode detection and the destination paths; the scaffolds live here.

## Memo (`memo`)

### Mode 1: no arguments (summarize the conversation)

Summarize the current conversation into a memo. Items to extract: topics discussed / decisions made / open issues / key findings & insights.
Destination: `{base}/docs/[Memo] session-summary-{YYYY-MM-DD}.md`

```markdown
# [Memo] Session Summary

- **Date**: {today's date}
- **Author**: AI

## Topics discussed
- {topic 1}
- {topic 2}

## Decisions made
-

## Open issues
-

## Key findings / insights
-
```

In Mode 1, **present the summary as text and then save** (after-the-fact disclosure — saving to the store is a non-destructive "run freely" operation per safety.md; the user can request edits afterward).

### Mode 2: with an argument (memoize the given content)

Record the content of `$ARGUMENTS` as a memo.
Destination: `{base}/docs/[Memo] {slugified argument}-{YYYY-MM-DD}.md`

```markdown
# [Memo] {title from the argument}

- **Date**: {today's date}
- **Author**: AI

## Content

{structured write-up of $ARGUMENTS}
```

Saving and reporting follow the common pattern (`${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` §2 pattern B / §3 naming convention / §4 report format / §1.6 style conventions). A Japanese memo body follows `~/.claude/rules/writing-ja.md`.

## Knowledge (`knowledge`)

Structure: see [`directory-structure.md`](directory-structure.md) for details. Promotion target = `{base}/docs/knowledges/{topic}.md`, draft = `{base}/docs/knowledges/drafts/{topic}.md`.

### Determine the mode (the first token of `$ARGUMENTS`)

- **No argument / `list`** → list drafts
- **A number / `promote`** → promotion mode
- **A topic string** → create a new knowledge entry

#### list (list drafts)

1. `Glob("{base}/docs/knowledges/drafts/*.md")`
2. Read the first 3 lines (the title) of each file
3. Display the list and ask for the number(s) to promote (or "all"):

```
## Knowledge drafts

1. **PostToolUse JSON shell expansion issue** (drafts/posttooluse-json-shell-expansion.md)
2. **search query expansion tuning** (drafts/search-query-expansion-tuning.md)

Pick the ones to promote (number, or "all").
```

#### promote (promotion)

1. Read the selected file in full, display it, and ask the user for edits
2. Once confirmed, move it from `drafts/` directly into `knowledges/`:
   ```bash
   git mv "{base}/docs/knowledges/drafts/{file}" "{base}/docs/knowledges/{file}"
   ```
   (use `mv` if the store is not under git)
3. search ranking scans decisions/docs directly, so the file is searchable right after the move (the FTS5 section index auto-follows the Write via the PostToolUse hook)

#### Create new

Save `$ARGUMENTS` as the topic directly into `knowledges/`:

```markdown
# {topic}

## Problem
{what happened}

## Cause
{why it happened}

## Solution
{how it was solved}

## Lesson
{how to prevent the same problem}

## Related
- {related decisions/ files}
- {related research/ files}
```

Naming follows the knowledge exception (no prefix; the title becomes the filename) (`_common-pattern.md` §3 "knowledge exception"). Promoted knowledge is searchable across the store via the `search` skill (`/search <query>`).

> **Auto-saving drafts (hook)**: when `ai-context-auto.sh` detects "got stuck", "the cause is", "solved it", "pattern", "figured it out", "turned out", "discovered", "noticed", "gotcha", "workaround", "notice", it prompts to save a draft. Accumulated drafts are surfaced by the SessionStart hook (`knowledge-draft-review.sh`) once they exceed a threshold, and handled by this `knowledge` procedure.
