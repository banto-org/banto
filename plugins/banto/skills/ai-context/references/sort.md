# /ai-context sort — triage details (internal + whole project, merged the former doc-sort)

Switch 2 modes by argument:

| Invocation | Mode | Target |
|---|---|---|
| `/ai-context sort` | **Internal mode** (default) | Triage of misplaced files inside `.ai-context/` |
| `/ai-context sort project` | **Whole-project mode** (former doc-sort) | Organize scattered documents at the root / `docs/`, etc. |

ai-context also fires on natural language like "organize the docs", "it's a mess", "move the docs", etc., and judges the mode from context (project mode if it seems whole-project-ish).

---

## Internal mode (default)

### Purpose
**Interactively triage** misplacements inside `.ai-context/` (those detected by doctor). Do not move without user approval.

### Execution procedure

1. Internally re-run the doctor diagnosis (no writes)
2. Classify and present the move candidates:

```
## .ai-context/ triage candidates

### [Prefix violation] directly under docs/
| # | File | Recommended action | Reason |
|---|---------|--------------|------|
| 1 | docs/meeting-notes.md | rename to `[Memo] meeting-notes.md` | meeting notes |
| 2 | docs/api-review.md | rename to `[Review] api-review.md` | review |

### [Missing date] decisions/
| # | File | Recommended action |
|---|---------|--------------|
| 4 | decisions/old-decision.md | rename to YYYY-MM-DD_old-decision_<user>.md |

### [Stale session] sessions/
| # | File | Updated | Recommended action |
|---|---------|--------|--------------|
| 5 | checkpoint-2026-03-01-1430.md | 46 days ago | delete |
```

3. Ask the user to choose:

```
Specify by number:
- run all → "all"
- confirm each → "each"
- pick numbers → "1,3,4"
- abort → "skip"
```

4. When executing, **prefer `git mv` if available**, otherwise `mv`. Confirm before `rm` for deletion.

5. After completion, the search `combined.txt` is auto-regenerated on save by the hook (`ai-context-combined-rebuild.sh`), so no manual operation is needed.

6. Completion report:

```
## Triage complete

- Renamed: N
- Moved: N
- Deleted: N
- Skipped: N

Recommended: check the final state with `/ai-context status`
```

## Safety rules (internal mode)

- **Don't touch dated files in `decisions/` as a rule** (already canonical)
- Don't touch files in `docs/research/` (research-agent output is free-form OK)
- Don't move conventional files like `README.md` / `LICENSE`
- Warn if under `git` management and there are staged changes in `git status`

---

## Whole-project mode (`/ai-context sort project`, former doc-sort)

Interactively organize documents scattered inside the project. The target is outside `.ai-context/` (placed at the root / `docs/`, etc.).

### Target file types
```
.md, .txt, .rst, .docx, .doc, .pptx, .xlsx, .xls, .csv, .tsv, .pdf
```
Additionally scan `.json .yaml .yml .toml`, but **skip config files (package.json / tsconfig.json / pyproject.toml etc.)** and target documents (openapi.yaml / api-spec.json etc.).

### Excluded directories
```
node_modules, .git, dist, build, .next, .nuxt, __pycache__,
.ai-context/sessions,
vendor, target, .venv, venv
```

### Execution procedure

**Step 1: Scan**
- Small scale (~50 files or fewer): run `Glob` for each extension in the main session
- Medium-to-large scale (over 50 / monorepo): delegate to an `Explore` subagent (to prevent a large flood of paths into the parent context). When in doubt, lean toward Explore.

**Step 2: Classify** — present to the user in 3 categories:
- `[Move recommended]` placed at the root → recommend moving to `docs/` (# / file / size / recommended destination / action)
- `[Reference only]` immovable (README / LICENSE / CHANGELOG / CONTRIBUTING / CODE_OF_CONDUCT / under `.github/` / sub-package README)
- `[Confirm]` judgment needed (move to docs/ / delete / leave as-is)

**Step 3: Dialogue** — ask for a choice with `1,2` / `all` / `each` / `skip`.

**Step 4: Execute** — prefer `git mv` (otherwise `mv`). Create `docs/` if absent.

**Step 5: Propose registering search targets** — if `docs/` etc. is unregistered in `config.json`'s `extra_docs_dirs`, propose registration → on yes, add to `extra_docs_dirs` (reflected into `combined.txt` at the next hook regeneration. No manual rebuild needed).

**Step 6: Generate a reference index** — save an index of all documents to `<base>/docs/[Index] project-documents.md` (3 tables: docs/ / root (immovable) / sub-packages).

**Step 7: Completion report** — a summary of moved / skipped / deleted / search-target registration (`extra_docs_dirs` additions).
