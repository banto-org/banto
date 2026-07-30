# Changelog

## 0.5.0

- **Always-on rules slimmed from 6 to 3 (10 → 7 rule files).** Following the direction of Claude Code's own system-prompt reduction (drop prohibition lists, delegate judgment to the model), the `testing` and `code-editing` rules were removed — the lockfile discipline moved into `dependencies` (still deterministically enforced by `lint-guard.sh`) — and `quality` / `evidence-first` were compressed. The contracts only prose can carry (`safety`, `pii-protection`, `spec-fidelity`) stay.
- **Model selection is now the main AI's judgment — no prescriptive roles.** The "implement = sonnet / audit = opus / mechanical = haiku" defaults and the `model-role-guard` warn hook are gone (49 registered hooks). Rules now prescribe only fan-out **granularity** (1 agent = 1 independent subtask: acceptance criterion stateable in one line, no sequential dependency, clear file boundary) and **parallelism** (about 5 agents per message as a guideline; declare scale and reason first when 8+). `model-policy.json` keeps only operational plumbing: `summarize` (the idle-checkpoint background fork) and `verify_external` (cross-check).
- **New skill: thinking-core — the former always-on work contract, now on demand.** The 7-section contract (acceptance criteria → evidence → minimal change → boundaries → verify → report → exceptions) loads only for sonnet / haiku fan-outs and older-generation models. It is strictly never loaded for 5-generation frontier models, where prescriptive procedure text constrains performance instead of helping. 21 public skills.
- **Prompts become tasks automatically.** A UserPromptSubmit router detects implementation/research asks and defer-markers in your messages and nudges them into the active workspace's `tasks.md` — capture-first, no modal interruptions.
- **Checkpoint delivery made deterministic.** The workspace marker on auto-saved checkpoints is now stamped by a deterministic hook instead of the model (the reader always matched exactly; now the writer does too), and checkpoints that cannot be delivered because no workspace is resolved surface a one-line recovery note at session start instead of silently piling up.
- **Fan-out hygiene: fold what you spawn.** Throwaway fan-out agents must not be given a `name` (named agents persist in the mailbox across session resumes); results are collected on completion and idle agents are stopped, not abandoned.
- **Store hygiene fixes.** Creation-index records why each store file was created; knowledge-store markers are recognized from subdirectories; docs/ naming is unified on a date-prefix canon with a hook check; `ws` degrades gracefully when git-town is not installed.
- **Docs: `/reload-plugins` is documented as sufficient to load a new skill / hook set.** A full restart is only needed when you want SessionStart hooks to re-run; the language switcher, kit catalog, and update instructions now say so.

## 0.4.0

- **New skill: docs — one skill for every document.** It replaces html-doc / ja-writing / b2b-docs (removed in this release): the best-fit format (HTML / xlsx / pptx / docx / tables) is chosen from the document's purpose, the writing follows a 25-rule three-layer canon (readability / persuasion / document-scene fit) shared across all formats, stiff phrasing is swept by a wording-swap canon plus bundled machine checks, and the default ivory-and-navy theme passes WCAG contrast checks.
- **diagram v2: a 14-pattern SVG diagram library.** Correspondence maps, ✗/✓ comparisons, flowcharts, logic trees, 2-axis matrices, Venn diagrams, Gantt charts, funnels, roadmaps, swimlanes and more — each with complete SVG code and built-in numeric constraints (element counts, label lengths, box widths) so layouts cannot structurally fall apart. Sequence diagrams still route to mermaid; AWS architecture diagrams to draw.io.
- **New skill: policy — a single-screen console for per-repo grants and protections.** It lists and edits standing grants (PR creation / feature push / production ops) and protections (no-edit / no-sync files) in one page; changes save automatically, take effect on the guard hooks immediately, and the server exits on Done / tab close / 15 idle minutes. `meta/policy.json` becomes the canon, with the older `grants.json` still honored as a fallback.
- **New skill: design-brief.** Converts a vague UI request ("make it look nice") into a 14-dimension design specification upstream of spec and implementation.
- **Task lists are per-workspace, and mirrored.** The persistent task-list id now derives from the active workspace (`<project>--<ws-slug>`), matching the store's per-workspace tasks.md. A [Task mirror] instruction injected at session start keeps the store ledger and the built-in task UI updated together — on start, on completion, and when new work arrives.
- **Store sync pulls every cycle.** Sync now runs commit → pull --rebase → push, so another machine's knowledge is pulled in on every cycle and a non-fast-forward can no longer strand local commits for days. Conflicts are never auto-resolved; they surface as checkpoints.
- **Freshness contract.** Newest-first search ordering, front-matter staleness warnings with status demotion, and workspace freshness notes — stale references get flagged instead of silently trusted.
- **Behavioral rules join the i18n line.** The behavioral rules (plus the workspace rule) are now bilingual like skills and agents — Japanese canonical, English generated, hash-verified. `/set-language` now switches the rules too.
- **New gate: full classification of shipped language files.** `i18n-coverage-check.sh` forces every language-bearing file under templates / skills / agents to be either i18n-managed or explicitly registered in an exemption registry. It runs on every push, every PR, and every export.
- **The Japanese writing-style rule is now opt-in (default off).** `set-language` owns the toggle (`/set-language writing-ja on|off`); the preference lives in user scope and survives plugin updates.
- **In-repo `.ai-context/` retired.** The knowledge base now lives only in the central store; an existing in-repo store migrates automatically at session start.
- **skill-audit: a 7-axis context-engineering audit for a single skill.** Complements plugin-audit (whole-plugin, 15 axes). Its scope now explicitly covers references/ and scripts/, and a description-measurement bug was fixed.
- **Self-heal that actually retries.** SessionStart applies the user-level harness setup automatically on first run and after upgrades — and a failed apply is no longer stamped as done: the marker is written only when setup succeeds and the deployed statusline byte-matches the shipped one, so a partial failure retries next session instead of freezing until the next version bump.
- **Guards tuned to opt-in.** odd-gate's consecutive-test-failure breaker is now opt-in (default off), and ODD audits are scoped to plugins that adopt ODD — fewer false blocks in mixed environments.
- **harness-drift-check: cross-skill reference false positive fixed.** Cross-skill `skills/<other>/references/...` pointers are now resolved from the skills root (and liveness-checked) instead of being misread as skill-local missing references.
- **Decision hygiene: no verbatim conversation quotes.** The decision-writing canon now requires rounding remarks to their substance; a lint warns when colloquial quotes land in decision files.
- **Statusline: checkpoint indicator.** The token-monitor statusline shows 💾 HH:MM once an automatic checkpoint has been saved, plus an open-task count and staged context-usage colors, with a 10-second refresh so unattended saves surface on their own.
- **Site: rewritten copy, a Flow page, and a click-to-modal toolset.** All pages were rewritten to the docs skill's writing canon (one idea per sentence, jargon defined on first use). The toolset's 26 cards open structured modals — lead line, an animated say-it → tool → result mini-flow, and bullet points. A new Flow page teaches the four always-on habits (💾 then /clear, /save-checkpoint at milestones, context colors, ws-driven workspaces) and the scenario flows for new development, AI features, and research. Mobile fixes: the header fits 375px, wide tables get scroll shadows plus a sticky first column, and wide SVGs scroll at a readable size. Tool counts match the shipped plugin (20 skills, 6 agents).
- **Hook fixes.** release-guard: prefix-assigned escape variables (`BANTO_ALLOW_...=1 git ...`) now actually reach the hook process, and detection moved to leading-token matching so quotes and heredoc bodies no longer false-positive. prod-guard fails open if its execute bit is missing.
## 0.3.1

- **Site: the Evidence page, rebuilt around one spine.** The measured report now leads with a single claim — same models, one has your project's memory — and three pillars (memory / boundary / cost), each backed by a numbered proof in importance order. Method and terms moved to a collapsible appendix, the honest null results were demoted to a "where the store does not change the outcome" aside, and only Banto-condition advantages are highlighted. No measured number changed.
- **Site: a "folding a session" section on the landing page.** The home page now covers `save-checkpoint` directly below the i18n flagship — how it writes a structured, resumable snapshot to the store and recommends exactly one of `compact` or `clear`, how that differs from a plain in-session `/compact`, and how the idle-checkpoint hook cuts one for you in the background when you step away.
- **idle-checkpoint's default model now resolves from the model-policy source of truth.** The background fork reads its model from `templates/model-policy.json` (`roles.summarize`, Sonnet) instead of a hardcoded literal, keeping the model tiers in one place. Behavior is unchanged; `BANTO_IDLE_CHECKPOINT_MODEL` still overrides per run.

## 0.3.0

- **New: idle-checkpoint — automatic session checkpoints when you step away.** After 5 minutes without API activity (matching the prompt cache's default 5-minute TTL, measured from the last API call), a Stop-armed watcher fires `/save-checkpoint` via a headless forked session, so returning to a cold-cache session costs a cheap `/clear` + checkpoint re-injection instead of a full cold re-read. The fork runs on a low-cost model by default (`BANTO_IDLE_CHECKPOINT_MODEL`), never touches the original transcript, skips small sessions (below 10% context usage or a 256KB transcript), accumulates only awake idle time so opening your laptop doesn't misfire, and runs with a read-only tool allowlist. Threshold tunable via `BANTO_IDLE_CHECKPOINT_MIN`; disable with `BANTO_IDLE_CHECKPOINT=0`.
- **Fixed: verify-claim-guard fired on already-resolved failures.** The completion-claim guard's error check now looks only at the *last* tool result — a failure immediately retried and resolved by a successful call no longer blocks a truthful completion report. Real failures remain covered by the verify-run RED/GREEN check.
- **Site.** Every skill and agent now has its own explainer page, reachable from a hover mega-menu in the header and from the toolset chips. New in-depth pages for the deterministic hook guard rails and for ODD (the per-skill autonomy declaration) — linked from the safety section.

## 0.2.2

- **Fixed: the qa-tester agent could not reach any browser via Claude in Chrome.** Its tool allowlist had the page-interaction tools (`navigate` / `read_page` / `form_input`) but not `tabs_context_mcp` — the tool that lists connected browsers and tabs — so the Claude in Chrome path was structurally unreachable. The agent now carries `tabs_context_mcp` / `tabs_create_mcp` / `computer` (click, type, screenshot), and its web-test procedure starts by getting the tab context and creating a fresh tab before navigating.

## 0.2.1

- **Stop-guard false positives fixed.** `verify-claim-guard` no longer trips on error-looking strings *inside* successful tool output (e.g. shell source code containing `fatal:`) — it now checks the actual `is_error` flag of the last 3 tool results structurally via jq, and treats an exploratory failure followed by successful calls as resolved. `model-claim-guard` no longer mistakes ordinary release/PR announcements for research-result claims: generic publish verbs now require a research noun (paper / eval / weights / arxiv / HF) in the same final message. Both guards ignore RED verify/eval state older than 4 hours, so leftovers from a previous work session can't block an unrelated one.
- **Migration guide: local store → central store.** The README now documents how to move a project's knowledge from the GitHub-less local store (`~/ai-context-local/<project>/`) into the central store once you adopt one — copy, register the central mapping, retire the local side, verify at session start.
- **Site.** The Store Search page now leads with what measurement showed to work — the cheapest model reaching the most expensive model's search accuracy at 1/10 the price — and links to the evidence report for the full data. Fixed a mobile horizontal-scroll bug on the landing page (a nowrap install command pushed the grid past 375px), a contradictory-looking hero stat layout, takeaway callouts rendering glued to their section headings on the evidence page, and several Japanese line-break and label polish items.

## 0.2.0

- **Store Search — a cross-store full-text section index.** Every markdown document across all of your project stores is indexed locally into SQLite FTS5 (trigram tokenizer — Japanese works out of the box) at section granularity with line ranges. The search skill queries it via `scripts/store-query.sh` (BM25-ranked top hits, `--all` for cross-store reach, automatic LIKE fallback for short terms) and falls back to the combined-text path when SQLite is absent. The index is a derived local artifact: rebuilt from scratch in seconds at session start, never committed — canonical data stays in git-managed markdown.
- **Location cards + a relation graph.** External documents (SharePoint, file servers, URLs, files outside the store) register as `docs/refs/[Ref] *.md` pointer cards (source / uri / fetched / related — no content mirroring). `related:` frontmatter is extracted deterministically into the ontology ledger's `references` relations and a queryable refs table; traverse both directions with `store-query.sh --related`. `scripts/ref_scan.py` bulk-inventories whole directories — for Excel workbooks it extracts sheet names, row counts, header text and cross-sheet formula references using the standard library only (a synthetic 100-sheet workbook inventories in 0.05s), and rejects DTD/entity-bearing OOXML from untrusted sources.
- **Japanese output style, applied automatically.** A compact style block (`templates/ja-style-core.md`), distilled for models weaker at Japanese, ships embedded in all 6 bundled agents and is referenced by the fan-out guidance in the quality rule.
- **Hook hardening (full 46-hook audit).** Fixed a class of "silent disablement" bugs: a date-glob drift causing false "unsaved decision" warnings, a freshness check watching a file that never updates, a permanently-dead workspace nudge, typecheck silently disabled on stock macOS, quoted-path bypasses of the secrets guard and the `rm -rf` kill switch, and a session-key mismatch that kept the test-failure circuit breaker from accumulating. The universal safety rules no longer depend on plugin-root resolution succeeding, and a dead PreToolUse branch was removed.
- **Skill/doc consistency.** ws / dev-loop / model-lab declarations now match their implementations — the `/ws new` workspace rule now ships as a real template (`templates/workspace-rule.md`), gate descriptions no longer over-claim, and stale guidance (task-worktree `claude -w` usage, hook "force-update" wording) is corrected.
- **Site.** New Store Search page (`docs/store-search.html`) with measured numbers — including the honest negative result (no token savings at current scale; the wins are cross-store reach, scale headroom and fewer search steps).

## 0.1.9

- **macOS / POSIX robustness.** Fixed a `harness-setup.sh` crash on macOS under `set -u`, and audited & fixed dash/GNU portability across the hook and script set so the harness runs cleanly on both macOS and Linux CI.
- **plugin-audit is a 15-axis quality audit.** Axis 15 (cross-skill reference consistency) is now reflected consistently across the skill copy and the project site.

## 0.1.8

- **Fixed: the context-limit checkpoint reminder misfiring after a compact.** The "context is near the limit — save a checkpoint" reminder no longer re-fires right after a `/compact` or `/clear`. The warning state now re-arms when the context usage drops, instead of only tracking the highest threshold ever reached, and the compact/clear boundary resets the per-session baseline (and prunes stale temp state). The same fix also restores the reminder when the context legitimately fills up again later in the session — previously it could go permanently silent after the first warning.

## 0.1.7

- **Site: deeper Plugin-tools page.** Each of the 14 audit axes now shows what it concretely checks (with a static / fresh-agent badge), a "why the score is trustworthy" section (fresh-agent review · deterministic static axes · measured routing precision · model-tier sweep · boundary-case weighting), a **HeavySkill** explainer (the 4 required components; based on [arXiv 2605.02396](https://arxiv.org/abs/2605.02396)), and a sources list. Tagline reworded to "audit them rigorously". Fixed a CSS class collision that hid the `plugin-dev` flow nodes in a normal browser.

## 0.1.6

- **Site: explainer pages** added under `docs/`. A deep-dive on the **AI-Context-Store** (what lives in the store, what the plugin does with it, and how it wires into Claude Code's hook lifecycle — with an animated diagram and a familiar folder tree), and a **Plugin tools** page covering `plugin-audit` (14-axis quality audit; static axes vs. a fresh-agent judgment pass) and `plugin-dev` (scaffold &amp; refactor). Reachable from the landing page's flagship and toolset sections.

## 0.1.5

- **New skill `model-lab`**: a model-building research workflow (the research-layer sibling of `dev-loop` / `ai-build`) — pretraining, full fine-tune, PEFT/LoRA, distillation, pruning, and architecture search, driven verification-first through to publishing a paper (arXiv/LaTeX) + Hugging Face + GitHub. Nine stages (frame → survey → design → implement → run → verify → analyze → paper → iterate); `autonomy_level: L3` with hard human gates on paid compute, publishing, and method/architecture goal forks.
- **Verification spine (deterministic hooks)**: `repro-gate` flags missing seed / determinism / std-CI in training scripts and result docs; `model-claim-guard` blocks a "paper/result done" claim that lacks a backing experiment (the research analog of `verify-claim-guard`); `compute-cost-gate` gates paid cloud / cluster compute behind owner confirmation (`BANTO_PAID_LAUNCH_RE` extends it per project). Helper scripts: `repro-check`, `eval-stats` (multi-seed BCa bootstrap 95% CI + permutation test), `claim-link` (claim ↔ verified-ledger check).

## 0.1.4

- **ai-context store bootstrap (non-blocking)**: an unregistered project now lands immediately in a temporary local store (`~/ai-context-local/<project>/`, same layout) instead of waiting on a prompt — work is never blocked. `/ai-context bootstrap` later backs it with a GitHub store (register existing or create private in a chosen, remembered org) and migrates the local store in (additive, never overwrites). `/ai-context local` pins a project local-only.
- **memo & knowledge folded into `ai-context`**: the standalone `memo` and `knowledge` skills are gone — use `/ai-context memo` and `/ai-context knowledge` (old `/memo` `/knowledge` keep working for one release). Subcommands consolidated (`init`→`bootstrap`, `status`+`doctor`→`doctor`, `prune` is now an automatic hook).
- **Knowledge draft review**: a SessionStart hook prompts to promote-or-delete once drafts reach a threshold (`BANTO_DRAFT_REVIEW_MIN`, default 10).
- **Store health lint**: `ai-context doctor` reports broken links / orphans / likely duplicates / stale decisions (detection only — never auto-fixes).
- **search → research as a work default**: the evidence-first order (local `search` first, then `research` for freshness-critical topics) now applies mid-task, not just to explicit questions. Search adds a 3-layer retrieval view (index → timeline → full) for token control.
- **New skill `ai-build`**: an AI-feature workflow (frame → search → research → design → implement → eval → iterate) with an LLM-as-judge eval step. The store gains `learnings/` and `meta/` scopes, and `directory-structure.md` is now the canonical folder↔skill mapping.

## 0.1.3

- **Website**: added the Banto project site under `docs/` (self-contained static page — bilingual JA/EN toggle, scroll-driven SVG animations), served via GitHub Pages (`main` / `/docs`). Tagline metaphor reworded from "runs the shop" to "runs the development" (the Edo-merchant-house etymology keeps "shop").
- **ai-context store bootstrap**: a project's first session no longer silently creates a local store — it asks once whether to register an existing GitHub `ai-context-store`, create one (and in which org, remembered for later projects, private), or stay local-only. The legacy in-repo `.ai-context/` is no longer a silent fallback; it prompts migration (read-compatible during the move).
- **search → research ordering**: "find/investigate" now runs the local `search` skill first and only escalates to the web when there's no confident hit; a soft `WebSearch` reminder nudges this (silence with `BANTO_ALLOW_WEBSEARCH=1`). Research output records source URLs with a `/webread <url>` re-verification affordance.
- **search coverage**: the ranker now includes `extra_docs_dirs` on the fast path (was only `decisions/` + `docs/`).
- **Persistent task list**: a SessionStart hook auto-sets `CLAUDE_CODE_TASK_LIST_ID` per project in the personal (gitignored) `.claude/settings.local.json`, so the task list survives resume / clear / restart. No setup required.
- **Catalog**: the `kit` overview now lists `ws` and `set-language` and the full rule set; dropped the maintainer-only `banto-port`.

## 0.1.2

- Leaner skill descriptions: removed non-routing detail (dependency lines, internal mechanics, duplicate triggers); triggers and "do not use when" guidance kept intact.
- `ws`: surfaced the `list` subcommand in the argument hint.
- Docs: README links now resolve to the correct-language targets.
- CI: added a markdown link-integrity gate (`check-md-links.sh`); fixed an i18n-sync manifest drift that could fail CI on the published tree.

## 0.1.1

- Removed the maintainer-only `banto-port` skill from the public scope (it ports Banto's own dev tree to public — not a user feature; same dev-only category as `harness-audit`).

## 0.1.0

Initial public release.
