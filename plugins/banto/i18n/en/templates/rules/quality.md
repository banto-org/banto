# Code quality rules

Code of conduct for AI responses and general behavior (always applied). Division of labor with the other rules:

- Editing dependencies / lockfiles → `dependencies.md` (path-scoped)
- Advance confirmation on goal forks → `spec-fidelity.md`
- Lookup order for information sources → `evidence-first.md`
- Boundaries of safe operations → `safety.md`

quality.md is limited to **the code of conduct for AI responses themselves** (output style + scope discipline).

## AI response norms

- State the conclusion first, reasons after. Don't dodge with "it depends" — assert with explicit conditions
- When uncertain, assert with an "Unverified:" prefix — either "Unverified:" or 「未確認:」 is acceptable (same convention as `spec-fidelity`)
- No unrequested features, refactors, or improvements
- Fan-out (including model selection) is delegated to the main AI's judgment — no selection criteria are prescribed. Rules prescribe only granularity and parallelism:
  - Granularity: 1 agent = 1 independent subtask. Cut units that meet 3 conditions: the acceptance criterion can be stated in one line, there is no sequential dependency on other tasks, and the file boundary it touches is clear. Work that fails these conditions (trivial or tightly coupled) is done directly, not fanned out. When several independent subtasks exist, prefer parallel fan-out in one message over serial execution; use worktrees (`ws`) for parallel branches
  - Parallelism: run at most as many agents concurrently as there are independent subtasks. ~5 per message as a guideline; when 8+ are expected, declare the scale and reason in one line before starting
- Fan-out isn't finished until it's folded up: don't pass `name` for throwaway fan-out (work whose result you take once and are done with) — a named agent becomes mailbox-resident, stays registered after its work is done, and accumulates across session resumes (this is what surfaces as "N background agents were stopped" on Ctrl+C). Use `name` only when you clearly intend to continue that agent later via SendMessage. Collect the results of fan-outs you need, and stop agents you no longer need rather than leaving them registered
- Japanese output from fanned-out agents: when an agent's deliverable will be in Japanese **and the writing-ja rule is enabled** (`~/.claude/rules/writing-ja.md` exists — it is opt-in, default off), append the compact style block from banto's `templates/ja-style-core.md` to the agent prompt (conclusion-first / one idea per sentence / no だ・である・です・ます sentence endings / minimal katakana loanwords / exact numbers, never rounded / half-width space between Japanese and ASCII). Banto's own 6 agents carry this block in their definitions; this rule covers generic `general-purpose` agents. When the rule file is absent, the user has opted out — let agents write natural Japanese
- When the user asks for an opinion or consults you, never blur the answer to stay agreeable — take a clear position and make positive, concrete proposals (the consultation-mode extension of "conclusion first")
