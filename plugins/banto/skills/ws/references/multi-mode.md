# /ws multi mode (parallel reference of multiple WS)

A mode for **referencing multiple research topics or experiments at the same time on the same branch** (single-checkout only — note that `WORKSPACE-refs.md` lives at the store root and is therefore shared across parallel worktrees). The first argument is the primary (write target), the rest are references (read-only).

## /ws multi <ws1> <ws2> ...: parallel reference of multiple WS

### Step 1: parse arguments

```
primary="<ws1>"
references="<ws2> <ws3> ..."
```

### Step 2: rewrite the primary's WORKSPACE.md (lightweight pointer)

Same procedure as `/ws switch <ws1>` (pointer Write + branch auto-switch), but **only warn even if there are uncommitted changes** (multi is draft-centric, so it is allowed).

### Step 3: write the reference WS info into `{base}/WORKSPACE-refs.md`

```markdown
# Workspace References (multi mode)

**primary**: [research] topic-a (write target)

## Reference WS (read-only)

### [model] example-model-24b
(summary of that workspaces/ entry's "related documents" section)

### [research] topic-b
(...)

## Write rules

- Tie new decision logs / docs/ to the **primary**
- Reference WS related documents are "for reference only, do not edit directly"
- Before writing, decide "which WS does this content belong to"

## Return to single mode with /ws solo
```

### Step 4: report

```
✓ Multi mode enabled
  Primary:    [research] topic-a (write target)
  References: [model] example-model-24b, [research] topic-b (reference only)

Tie your writes to the primary.
To return to single mode, /ws solo.
```

## /ws solo: leave multi mode

```bash
rm -f "{base}/WORKSPACE-refs.md"
```

The pointer WORKSPACE.md (primary) stays as is, only references are deleted. Report: "Returned to single mode. primary: [scope] topic".

## multi-mode hook integration (design note)

The `ai-context-workspace-check.sh` hook decides the following:
- `{base}/WORKSPACE-refs.md` exists → multi mode
- On new file creation, asks the AI whether it ties to primary or reference
- When writing to the reference side, confirms "shouldn't this be tied to primary?"

(The hook-side implementation is the next round as a separate task T3.10.)
