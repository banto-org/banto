---
name: memo
description: |
  **UTILITY SKILL** — Save conversation content as a [Memo] document under .ai-context/docs/.
  Triggers: "memo this", "save a memo", "jot this down", "summarize this conversation as a memo". Also invocable via /memo.
  Do not use when: recording design decisions (ai-context skill's decisions/), saving session state (save-checkpoint), promoting knowledge drafts (knowledge), external research (research), or status reports (status). Do NOT fire on "decision", "adopt", "save", "checkpoint", "progress" (those belong to ai-context / save-checkpoint / status). A trivial one-line memo is fine with a direct `echo > file`.
  Depends on: Read, Write, Glob (duplicate check). No argument = summarize the conversation; with an argument = memo the given content.
user-invocable: true
argument-hint: "[content to memo (omit = summarize the conversation)]"
allowed-tools: Read Write Glob
compatibility: Claude Code (requires bash, git, jq)
---

# [Memo] Create a Memo

> **Storage base (store-first)**: every `.ai-context/...` path in this skill refers to the ai-context base — the absolute path injected at SessionStart as 「ai-context ベース: &lt;absolute path&gt;」. Never write to a relative `.ai-context/` (if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

**Pattern**: B (fill-in template) — see `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` for the shared skeleton
**Filename prefix**: `[Memo]`

Write the memo *content* in the user's conversation language (Japanese if they converse in Japanese). Keep the section headings exactly as in the templates below (e.g. `## Content`, `## Topics discussed`) — they are fixed structural markers, do not translate them.

## Step 1: Determine the mode

### Mode 1: No argument (conversation summary)

Summarize the current conversation into a memo. Extract:
- Topics discussed
- Decisions made
- Open issues
- Key findings / insights

Save to: `.ai-context/docs/[Memo] session-summary-{YYYY-MM-DD}.md`

### Mode 2: With argument (memo the given content)

Record the content of `$ARGUMENTS` as a memo.
Save to: `.ai-context/docs/[Memo] {slugified argument}-{YYYY-MM-DD}.md`

## Step 2: Skill-specific template (fill in, then Write)

### For Mode 1

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

### For Mode 2

```markdown
# [Memo] {title from the argument}

- **Date**: {today's date}
- **Author**: AI

## Content

{structured write-up of $ARGUMENTS}
```

## Step 3/4: Save + report

Follow the common pattern (`_common-pattern.md` §2 Pattern B / §3 naming rules / §4 report format).
For Mode 1, **show the summary as text and save** (post-hoc disclosure — saving into .ai-context is a non-destructive "run freely" operation per safety.md; the user can ask to amend afterwards).
