# /ai-context doctor — diagnostic details (status integration + health lint)

## Purpose
Detect structural anomalies in `{base}/` **plus store health (health lint) plus the overall project health**, and report only — **also doubling as the status display (formerly status)**. Performs no fixes (routes to sort or guidance).

> store-first: BASE resolution is as described at the top of SKILL.md. The `{base}/` under diagnosis refers to the area beneath the resolved base. The canonical source for bucket names and prefix definitions is [`directory-structure.md`](directory-structure.md).

> **status integration (0.1.4+)**: the old `/ai-context status` (a read-only display of what exists) has been merged into doctor. Ahead of the diagnosis it emits a count summary (the "Status summary" below), then reports the diagnostic items. Even when invoked as `status`, it runs as doctor (a backward-compatible alias with a 1-line warning).

## Status summary (formerly status — read-only)

Obtain various counts via Glob, `wc -l`, and the like, and display what is stored (reads only under base; no writes):

```bash
BASE=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD")
find "$BASE/decisions" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l
find "$BASE/decisions" -maxdepth 1 -name "$(date +%Y-%m-%d)*.md" 2>/dev/null | wc -l
find "$BASE/docs/research" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l
find "$BASE/docs/knowledges/drafts" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l
find "$BASE/sessions" -type f -name "*.md" 2>/dev/null | wc -l
```

If an effective tasks file exists (the path under the SessionStart "in-progress tasks" heading; new layout = `workspaces/<author>/<topic>/tasks.md`, legacy = `tasks/active.md`), display the incomplete / complete counts and the Phase name.

Output example:
```
### Status summary (base: {BASE})
| Area | Count | Notes |
|---|---|---|
| decisions/ | N (today: M) | latest: YYYY-MM-DD-HHMMSS_... |
| docs/research/ | N | latest: ... |
| docs/knowledges/drafts/ | N | promote via `/ai-context knowledge` |
| sessions/ | N | (transient) |
| effective tasks | incomplete X / complete Y | Phase: ... |
```

## store health lint (broken links / orphans / contradiction candidates / staleness)

Call the health lint that **only detects** broken links / orphans / contradiction candidates / staleness in decisions/ (no fixes; provided by WT-C):

```bash
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-lint.sh" "$PWD" 2>/dev/null || echo "(lint not available / jq missing → skip)"
```

Report the lint output verbatim as the "health" section. In environments lacking the lint script or jq, fail open and skip it, while the other diagnostic items continue.

> **interface (WT-C)**: `scripts/ai-context-lint.sh [cwd]` resolves base from cwd (defaults to $PWD) and **only detects and enumerates** high-confidence unhealthiness in decisions/ (broken links / orphans / contradiction candidates / staleness); it does not auto-fix.

## Diagnostic items (base scope)

**A. Missing directories**
Enumerate the expected buckets that do not exist (the canonical bucket list is [`directory-structure.md`](directory-structure.md)).

**B. Suspected misplacement**

1. An unexpected directory directly under base
2. Directly under `docs/`, in a directory other than `research/` / `knowledges/`, a file lacking a `[Prefix]` tag / a prefix violation
3. A file inside `decisions/` whose name does not match the `YYYY-MM-DD*.md` pattern (timestamp / legacy NNN forms)
4. Stale (30+ days old) checkpoints inside `sessions/`
5. A file directly under `docs/` that lacks a fixed prefix (see [`directory-structure.md`](directory-structure.md)) (README.md is an exception)
6. An empty file (<100 bytes) in `decisions/`

**C. .gitignore inconsistency**
Whether the store-side `.gitignore` (`sessions/` / `*-combined.txt` etc.) categorization has broken down (the canonical categorization is [`directory-structure.md`](directory-structure.md)).

**D. hooks registration**
If no ai-context hooks are registered in `.claude/settings.json` (project level), present an informational note.

## Diagnostic items (project-wide)

**E. Git status**
```bash
git status --porcelain 2>/dev/null | wc -l
git branch --show-current 2>/dev/null
```
- 20+ uncommitted changes → warning
- Working directly on the main/master branch → warning

**F. CLAUDE.md**
- Whether `CLAUDE.md` or `.claude/CLAUDE.md` exists at the project root
- If absent → guide with "you can generate it with the native `/init`"

**G. .claude/rules/**
- Check for the directory and the md files inside it
- If absent → guide with "you can generate the rules with `harness-setup.sh --project`"

**H. Test configuration**
- Check for a `test` script in `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod`
- If absent → warning

**I. Linter / formatter**
- Check for `biome.json` / `.eslintrc*` / `.prettierrc*` / `ruff.toml`
- If absent → recommendation note

**J. Health of the effective tasks file**
- Line count > 200 → "split recommended" (`/ai-context tasks split`)
- `## Phase:` header count ≥ 4 → "multiple Phases mixed, tidy-up recommended"

## Output format

```
## Diagnostic results

### Status summary (base: {BASE})
(the "Status summary" table above)

### health (store lint)
(output of ai-context-lint.sh / or "lint skipped")

### base scope
#### A. Missing directories
✓ / ⚠ list

#### B. Suspected misplacement
| # | Path | Kind | Recommended action |
|---|------|------|---------------|
| 1 | docs/note.md | no prefix | `/ai-context sort` |

#### C. .gitignore
- {OK / append recommended}

#### D. hooks registration
- {OK / registration missing}

### Project-wide
| Item | Status | Detail |
|------|------|------|
| E. Git | ✓/⚠ | branch name / uncommitted count |
| F. CLAUDE.md | ✓/⚠ | path or missing |
| G. .claude/rules/ | ✓/⚠ | md file count |
| H. Test config | ✓/⚠ | package.json / pyproject / Cargo etc. |
| I. Linter | ✓/⚠ | biome / eslint / prettier / ruff |
| J. Effective tasks | ✓/⚠ | line count / Phase count |

### Suggestions
- Fix misplacement: sort interactively with `/ai-context sort`
- Tidy drafts: promote / delete with `/ai-context knowledge`
- Project-side gaps: generate with `harness-setup.sh --project`
- All clear: ✓ healthy
```

**Never writes anything.** If the user wants to fix things, route to `/ai-context sort` (misplacement) / `/ai-context knowledge` (drafts).
