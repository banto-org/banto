---
name: save-checkpoint
description: |
  Save the current session state as a checkpoint under {base}/sessions/, and recommend either compact or clear.
  Triggers: "save a checkpoint", "save the state", "save before clear", "save before compact". Also invocable via /save-checkpoint.
  Do not use when: the user merely mentions compact/clear without asking to save state, or for recording a design decision (the ai-context skill's decisions/). This skill never runs /compact or /clear itself.
user-invocable: true
allowed-tools: Read Write Glob Bash
compatibility: Claude Code (requires bash, git, jq)
---

> **Store-first**: saves go to `{base}/sessions/...`. `{base}` is the absolute ai-context base path injected by the SessionStart/PreCompact hook (when unknown, resolve it with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

Save the current work state as a checkpoint file.

Write the generated document in the user's conversation language (Japanese if the user is conversing in Japanese). The template labels are illustrative.

## Step 1: Collect diagnostic information

Check the following in parallel:
- Decision logs: `find {base}/decisions -name "*.md" | wc -l` (total count)
- Today's decisions: `find {base}/decisions -name "$(date +%Y-%m-%d)_*.md" | wc -l`
- Existing checkpoints: `find {base}/sessions -name "checkpoint-*.md" | wc -l`
- Research: `find {base}/docs/research -name "*.md" | wc -l`
- Spec documents: `find {base}/docs/specs -name "*_spec.md"` (the SDD trio `{date}_{slug}_{spec,plan,tasks}.md`)

## Step 2: Create the checkpoint file

Save to: `{base}/sessions/checkpoint-{YYYY-MM-DD}-{HHMM}.md`

Save with the Write tool in the following format:

Put a workspace address marker on the first line (reuse the value of the injected
"# Workspace: <topic>" line verbatim; omit the line if there is none). SessionStart uses this
marker to deliver only checkpoints addressed to this workspace on /clear, preventing
misdelivery to an unrelated session (decision 2026-07-08 idle-checkpoint-delivery).

```markdown
<!-- banto-ws: <current workspace topic; omit this whole line if none> -->
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

Decide from the diagnostic information:

**Recommend clear** (when all conditions hold):
- Decision logs are saved (total > 0 and today > 0)
- A checkpoint has been created (in Step 2)
- No unsaved important information

→ "**Recommend clear**: the decision logs and checkpoint are saved, so it is safe to clear and resume. You reclaim the full 1M context."

**Recommend compact** (when the clear conditions are not met):

→ "**Recommend compact**: {specific reason}. Use compact to avoid information loss."

## Step 4: Confirm with the user

After presenting the diagnostic information and recommendation, always confirm in the following format:

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

- "OK" / "that's right" → wait for the user to run compact/clear themselves (the AI does not run it)
- "wrong" / "fix it" → update the checkpoint file and confirm again
- "use the other one" → flip the recommendation and re-present it

## Notes

- The PreCompact hook auto-injects the checkpoint and then deletes it, so the next session resumes automatically
- The AI never runs /compact or /clear itself. Wait for the user's decision
