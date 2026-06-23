---
name: knowledge
description: |
  **UTILITY SKILL** — Review, promote, and organize knowledge drafts (drafts/) into formal knowledge entries.
  Triggers: "promote the draft", "list knowledge drafts", "make this a knowledge entry", "add this to the knowledge base". Also invocable via /knowledge. (The draft-saved hook says "review via /knowledge" — natural language reaches it too.)
  Do not use when: saving design decisions (ai-context skill's decisions/ — don't fire on "decision"), external research (research skill), plain memo saving (memo skill), or a simple single-file copy (direct Bash `mv`).
  Depends on: Read (list drafts), Write (promotion target .ai-context/docs/knowledges/), Glob, Bash (git mv).
user-invocable: true
argument-hint: "[omit: list drafts / 'promote': promotion mode / topic: create new]"
allowed-tools: Read Write Glob Bash
compatibility: Claude Code (requires bash, git, jq)
---

# Knowledge — Knowledge Management

> **Storage base (store-first)**: the promotion target `.ai-context/docs/knowledges/...` refers to the ai-context base. Read/Write under the absolute path injected by the SessionStart/PreCompact hooks as 「ai-context ベース: &lt;absolute path&gt;」 — never write to a relative `.ai-context/` (it exists only in grandfathered legacy repos; if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

**Pattern**: B (fill-in template, but with the **no-prefix exception**) — see `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` §3 "knowledge exception" for the shared skeleton
**Save to**: `.ai-context/docs/knowledges/{topic}.md` (promoted) + `drafts/{topic}.md` (drafts)

Respond and write the knowledge entry in the user's conversation language (Japanese if they converse in Japanese).

## Directory structure

```
.ai-context/docs/knowledges/
├── drafts/              # drafts (auto-saved when a hook detects them)
│   ├── posttooluse-json-shell-expansion.md
│   └── search-query-expansion-tuning.md
├── posttooluse-json-shell-expansion.md   # promoted knowledge
└── search-query-expansion-tuning.md
```

## Step 1: Determine the mode

- **No argument** → list `drafts/`
- **Number or `promote`** → promotion mode
- **Topic string** → create a new knowledge entry

## Step 2: Per-mode processing

### 2a. List drafts

1. `Glob(".ai-context/docs/knowledges/drafts/*.md")`
2. Read the first 3 lines of each file (title)
3. Show the list:

```
## Knowledge drafts

1. **PostToolUse JSON shell expansion issue** (drafts/posttooluse-json-shell-expansion.md)
2. **search query expansion tuning** (drafts/search-query-expansion-tuning.md)

Pick the ones to promote (number, or "all").
```

### 2b. Promote

1. Read and show the selected file in full; ask the user for edits
2. Once confirmed, move from `drafts/` to the top of `knowledges/`:
   ```bash
   git mv .ai-context/docs/knowledges/drafts/{file} .ai-context/docs/knowledges/{file}
   ```
3. combined.txt is regenerated automatically by the PostToolUse hook on Write to docs

### 2c. Create new

Save `$ARGUMENTS` as the topic directly under `knowledges/`:

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

## Step 3/4: Save + report

Follow the common pattern (`_common-pattern.md` §2 Pattern B / §4 report format). Naming follows the knowledge exception (no prefix; the title is the filename).

## Searching knowledge

Promoted knowledge is searchable via the search skill:
- `/search {query}` searches across `.ai-context/` (+ directories added via config.json `extra_docs_dirs`)
- Natural-language triggers also fire it (e.g. "recall" / 「思い出して」 → `search` skill)

## Automatic draft saving by hook

`ai-context-auto.sh` prompts to save a draft when it detects these keywords:

- 「ハマった」「原因は」「解決した」「パターン」「分かった」「判明」
- 「発見した」「気づ」「gotcha」「workaround」「notice」
