---
name: save-checkpoint
description: |
  Save the current session state as a checkpoint under .ai-context/sessions/ and recommend compact or clear.
  Triggers: "save checkpoint", "save the session state", "checkpoint before clear", "checkpoint before compact". Also invocable via /save-checkpoint.
  Do not use when: the user merely mentions compact/clear without asking to save state, or when recording a design decision (use the ai-context skill's decisions/). This skill never runs /compact or /clear itself.
user-invocable: true
allowed-tools: Read Write Glob Bash
compatibility: Claude Code (requires bash, git, jq)
---

> **Storage base (store-first)**: every `.ai-context/...` path in this skill refers to the ai-context base. Read/Write under the absolute path injected by the SessionStart/PreCompact hooks as 「ai-context ベース: &lt;absolute path&gt;」 — never write to a relative `.ai-context/` (it exists only in grandfathered legacy repos; if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Save the current working state as a checkpoint file.

Write the generated document in the user's conversation language (Japanese if they converse in Japanese). Template labels are illustrative.

## Step 1: Collect diagnostics

Check the following in parallel:
- Decision logs: `find .ai-context/decisions -name "*.md" | wc -l` (total)
- Today's decisions: `find .ai-context/decisions -name "$(date +%Y-%m-%d)_*.md" | wc -l`
- Existing checkpoints: `find .ai-context/sessions -name "checkpoint-*.md" | wc -l`
- Research: `find .ai-context/docs/research -name "*.md" | wc -l`
- Spec documents: `docs/requirements.md`, `docs/design.md`, `docs/tasks.md`

## Step 2: Create the checkpoint file

Save to: `.ai-context/sessions/checkpoint-{YYYY-MM-DD}-{HHMM}.md`

Save with the Write tool in this format:

```markdown
# Checkpoint - YYYY-MM-DD HH:MM

## What is being worked on now
{concrete description including file/component names. 3-5 lines.
 Write so that a post-compaction AI can understand "why this work was being done"}

## How this work got here
{key turning points from the user's initial request to now. Chronological. 2-4 lines}

## Confirmed design decisions
{what was decided in this session. If already saved to decisions/, reference the filename;
 otherwise include the content. Bullet list}

## Open issues
{what is still undecided, what needs the user's confirmation. Bullet list}

## Recently changed files
{list of changed/created files}

## Next steps
{what to do next to continue this work. 1-2 lines}
```

## Step 3: Recommend exactly one of compact / clear

**Never present both sides. Always recommend exactly one.**

Decide from the diagnostics:

**Recommend clear** (when all conditions hold):
- Decision logs are saved (total > 0 and today > 0)
- Checkpoint created (in Step 2)
- No unsaved important information

→ "**Recommend clear**: decision logs and checkpoint are saved, so it is safe to clear and resume. You regain the full 1M context."

**Recommend compact** (when the clear conditions are not met):

→ "**Recommend compact**: {concrete reason}. Use compact to avoid information loss."

## Step 4: Confirm with the user

After presenting the diagnostics and recommendation, always confirm in this format:

```
## Checkpoint created

### Diagnostics
- Decision logs: N (M today)
- Checkpoint: created ✓
- Research: N
- Specs: {requirements.md ✓/✗}, {design.md ✓/✗}, {tasks.md ✓/✗}

### Recommendation: [clear / compact]
{1-2 lines of reasoning}

Does this match your understanding? Tell me if anything is off.
If not, I will proceed with the recommended [clear / compact].
```

## Step 5: Follow the user's instruction

- "OK" / "looks right" → wait for the user to run compact/clear themselves (the AI does not run it)
- "that's off" / "fix it" → update the checkpoint file, then confirm again
- "do the other one" → flip the recommendation and present it again

## Notes

- The PreCompact hook auto-injects the checkpoint and then deletes it, so the next session resumes automatically
- The AI never runs /compact or /clear itself. Wait for the user's decision
