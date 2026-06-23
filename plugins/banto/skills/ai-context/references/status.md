# /ai-context status — state display details

## Purpose
Display what is stored in the current `.ai-context/` by **only reading**.

> store-first: resolve BASE as described at the top of SKILL.md. Read each `.ai-context/` below as the resolved `$BASE/`.

## Execution procedure

Get the various counts with Glob and `wc -l`, etc.:

```bash
test -d .ai-context && echo "✓" || echo "✗ .ai-context/ does not exist"

find .ai-context/decisions -maxdepth 1 -name "*.md" 2>/dev/null | wc -l
find .ai-context/decisions -maxdepth 1 -name "$(date +%Y-%m-%d)_*.md" 2>/dev/null | wc -l

find .ai-context/docs/research -maxdepth 1 -name "*.md" 2>/dev/null | wc -l

find .ai-context/sessions -maxdepth 1 -name "*.md" 2>/dev/null | wc -l

test -f .ai-context/tasks/active.md && {
    grep -c "^- \[ \]" .ai-context/tasks/active.md
    grep -c "^- \[x\]" .ai-context/tasks/active.md
}

test -f .ai-context/WORKSPACE.md && head -1 .ai-context/WORKSPACE.md
find .ai-context/workspaces -maxdepth 1 -name "*.md" 2>/dev/null | wc -l

ls .ai-context/*-combined.txt >/dev/null 2>&1 && echo "✓ generated" || echo "✗ not generated"
```

## Output format

```
## .ai-context/ state

### Basics
- root: {exists / missing}
- .gitignore: {AI Context registered / unregistered}

### Content
| Area | Count | Notes |
|---|---|---|
| decisions/ | N (today: M) | latest: YYYY-MM-DD_... |
| docs/research/ | N | latest: ... |
| sessions/ | N | (transient) |
| tasks/active.md | open X / done Y | Phase: ... |

### Workspaces
- WORKSPACE.md: {present / absent} → {current WS name}
- workspaces/: N

### Search text layer (combined.txt)
- *-combined.txt: {generated / not generated. A hook auto-regenerates it on save}

### Recommended actions
(show only the ones that apply)
- not generated → recommend /ai-context init
- no WS set → recommend /ws new
- inconsistencies → recommend /ai-context doctor
- active.md bloated (>200 lines) → recommend /ai-context tasks split
```
