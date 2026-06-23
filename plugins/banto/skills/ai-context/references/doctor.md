# /ai-context doctor — diagnostic details

## Purpose
Only detect and report structural anomalies in `.ai-context/` **plus the whole project's health**. Performs no fixes (routes to sort or guidance).

> store-first: resolve BASE as described at the top of SKILL.md. Read the diagnosed `.ai-context/` as the resolved `$BASE/`.

## Diagnostic items (`.ai-context/` scope)

**A. Missing directories**
List the expected paths that do not exist:
`decisions/`, `docs/research/`, `docs/knowledges/drafts/`, `sessions/`, `tasks/old/`, `workspaces/`

**B. Suspected misplacement**

1. Unexpected directories directly under `.ai-context/`
2. Directly under `docs/`, a directory other than `research/` / `knowledges/` with no `[Prefix]`-prefixed file / prefix violations
3. Files in `decisions/` whose name does not match the `YYYY-MM-DD*.md` pattern (both timestamp / old-NNN forms)
4. Old (30+ days) checkpoints inside `sessions/`
5. Files directly under `docs/` that lack one of these prefixes (README.md is an exception):
   `[Review]` `[QA]` `[Audit]` `[Status]` `[Design]` `[Guide]` `[Memo]` `[Index]`
6. Empty files (<100 bytes) in `decisions/`

**C. .gitignore inconsistency**
`.ai-context/sessions/`, `.ai-context/project-index/`, etc. are unregistered

**D. hooks registration**
If ai-context-family hooks are not registered in `.claude/settings.json` (at the project level), surface it as information.

## Diagnostic items (whole project)

**E. Git state**
```bash
git status --porcelain 2>/dev/null | wc -l
git branch --show-current 2>/dev/null
```
- 20 or more uncommitted changes → warning
- Working directly on the main/master branch → warning

**F. CLAUDE.md**
- Whether there is a `CLAUDE.md` or `.claude/CLAUDE.md` at the project root
- If absent → guide "you can generate it with native `/init`"

**G. .claude/rules/**
- Confirm the directory and the md files inside exist
- If absent → guide "you can generate rules with `harness-setup.sh --project`"

**H. Test configuration**
- Confirm a `test` script in `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` exists
- If absent → warning

**I. Linter/formatter**
- Confirm `biome.json` / `.eslintrc*` / `.prettierrc*` / `ruff.toml` exists
- If absent → recommendation guidance

**J. Health of tasks/active.md**
- Line count > 200 → "splitting recommended"
- `## Phase:` header count ≥ 4 → "multiple Phases mixed, organizing recommended"

## Output format

```
## Diagnostic results

### .ai-context/ scope
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

### Whole project
| Item | State | Details |
|------|------|------|
| E. Git | ✓/⚠ | branch name, uncommitted count |
| F. CLAUDE.md | ✓/⚠ | path or missing |
| G. .claude/rules/ | ✓/⚠ | md file count |
| H. Test config | ✓/⚠ | package.json / pyproject / Cargo, etc. |
| I. Linter | ✓/⚠ | biome / eslint / prettier / ruff |
| J. active.md | ✓/⚠ | line count / Phase count |

### Proposals
- needs fixing: triage interactively with `/ai-context sort`
- project-side gaps: generate with `harness-setup.sh --project`
- no problems: ✓ healthy
```

**Never write anything**. If the user wants to fix, route them to `/ai-context sort`.
