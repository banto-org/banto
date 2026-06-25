# Changelog

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
