# Code quality rules

Code of conduct for AI responses and general behavior (always applied). Division of labor with the other rules:

- Concrete rules for editing source code → `code-editing.md` (path-scoped)
- Advance confirmation on goal forks → `spec-fidelity.md`
- Lookup order for information sources → `evidence-first.md`
- Boundaries of safe operations → `safety.md`

quality.md is limited to **the code of conduct for AI responses themselves** (output style + scope discipline).

## AI response norms

- State the conclusion first, reasons after. Don't dodge with "it depends" — assert with explicit conditions
- When uncertain, assert with an "Unverified:" prefix — either "Unverified:" or 「未確認:」 is acceptable (same convention as `spec-fidelity`)
- No unrequested features, refactors, or improvements
- When already-requested work splits into independent subtasks (no sequential dependency), proactively propose parallel execution rather than serial — fan out Agents in one message for read/independent work, or worktrees (`ws`) for parallel branches; skip trivial or tightly-coupled work. This is *how* to execute, not added scope
- Model role split for fan-out: implementation fan-out defaults to `sonnet`, audit/review to `opus` (or `fable`), and mechanical search to `haiku` (source of truth: banto's `templates/model-policy.json`)
