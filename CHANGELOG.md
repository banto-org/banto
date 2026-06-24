# Changelog

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
