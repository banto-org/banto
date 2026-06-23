---
name: status
description: "Save a status report as a [Status] document. With no argument, auto-generate from tasks.md + recent work; with an argument, produce a report for the given period (Phase completion rates are auto-injected by SessionStart, so the manual subcommand is removed). Triggers: \"status\", \"status report\", \"progress\", \"progress update\", \"where do things stand\", \"how's it going\". Also invocable via /status. Do not use when: recording design decisions (ai-context's decisions/), saving a conversation memo (memo), saving session state (save-checkpoint), or external research (research)."
user-invocable: true
argument-hint: "[period (auto-generate when omitted)]"
allowed-tools: Read Write Glob Bash
compatibility: Claude Code (requires bash, git, jq)
---

# [Status] Status Report

Output language: write the report in the user's conversation language; the template labels are illustrative — translate them to match.

> **Storage base (store-first)**: every `.ai-context/...` path in this skill refers to the ai-context base. Read/Write under the path injected by the SessionStart/PreCompact hooks as 「ai-context ベース: &lt;absolute path&gt;」 — never write to a relative `.ai-context/` (it exists only in grandfathered legacy repos; if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

**Pattern**: B (template-fill) — see `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` for the shared skeleton
**Save prefix**: `[Status]`

## Step 1: Determine the mode

- **No argument** → auto-generate mode (saves)
- **Period specified** (e.g. "this week", "March", "Sprint 5") → report for the given period (saves)

## Step 2: Per-mode processing

### 2a. No argument (auto-generate)

1. Read the effective tasks file (the path under the SessionStart "in-progress tasks" heading; new layout=`workspaces/<author>/<topic>/tasks.md`, legacy=`tasks/active.md`) to check task status
2. Check recent commits with `git log --oneline -10`
3. Check the most recent files in `.ai-context/decisions/`
4. From the above, generate "completed work", "in progress", and "next actions"

### 2b. Period specified

Generate a report based on the `$ARGUMENTS` period and proceed to Step 3.

## Step 3/4: Save + report (2a / 2b only)

Skill-specific template:

```markdown
# [Status] {period}

- **Date**: YYYY-MM-DD
- **Author**: AI

## Period
{target period}

## Completed work
-

## Work in progress
-

## Blockers / issues
-

## Next actions
-
```

Follow the common pattern (`_common-pattern.md` §2 Pattern B / §3 naming rules / §4 report format).
