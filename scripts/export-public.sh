#!/bin/sh
# export-public.sh — build the public Banto tree from the explicit ALLOWLIST below.
#
# Allowlist semantics (NDA-safe default): anything NOT listed is NOT exported.
# New files are private until someone consciously adds them here.
#
# Usage:
#   scripts/export-public.sh <target-dir>     # target must not exist
#
# The script copies the allowlist, applies plugin-level exclusions, generates a
# fresh CHANGELOG stub, initializes a git repo (no commit), and runs the brand
# gate inside the export. Committing/pushing/publishing stays a human decision.
set -eu

TARGET=${1:?usage: export-public.sh <target-dir>}
SRC=$(cd "$(dirname "$0")/.." && pwd)
if [ -e "$TARGET" ]; then
    printf 'Error: target already exists: %s\n' "$TARGET"
    exit 1
fi

# --- ALLOWLIST (explicit, default-deny) -------------------------------------
# Deliberately absent (kept private): catalog.tsv /
# skills/ (root standalone skills) / CHANGELOG.md (internal history) / .serena /
# .claude (project-local rules) / audit & store artifacts (live outside the repo)
ALLOW="
README.md
README.ja.md
LICENSE
CONTRIBUTING.md
SECURITY.md
.gitattributes
CONCEPT.md
CLAUDE.md
docs
.claude-plugin
.github
scripts/check-legacy-names.sh
scripts/check-md-links.sh
scripts/export-public.sh
scripts/clean-room-test.sh
scripts/pre-push-check.sh
plugins/banto
"

# Plugin-level exclusions:
#   skills/status                  — pending the telemetry-based keep/fold decision
#   scripts/migrate-store-layout.sh / migrate-store-v2.sh / migrate-to-store.sh — all three store
#                                     migrations are dev-only: a fresh public install has nothing to
#                                     migrate. Kept in the repo for existing-user / local upgrades,
#                                     held back from the public export (owner decision 2026-06-22).
#   skills/harness-audit — dev-only meta tool: it audits banto's OWN harness (drift / dead-skill /
#                          ideology), which an end-user driving their project never needs. The
#                          deterministic watchdog (harness-drift-check.sh + dead-skill-report.sh,
#                          run at SessionStart / nightly) stays; only the manual model-judged skill
#                          is held back from the public surface.
PLUGIN_EXCLUDE="skills/status skills/harness-audit skills/banto-port workflows/harness-audit.workflow.js scripts/migrate-store-layout.sh scripts/migrate-store-v2.sh scripts/migrate-to-store.sh"

mkdir -p "$TARGET"
for p in $ALLOW; do
    if [ ! -e "$SRC/$p" ]; then
        printf '  skip (absent): %s\n' "$p"
        continue
    fi
    dir=$(dirname "$p")
    mkdir -p "$TARGET/$dir"
    cp -R "$SRC/$p" "$TARGET/$dir/"
    printf '  + %s\n' "$p"
done

PUB_MANIFEST="$TARGET/plugins/banto/i18n/.sync-manifest.json"
for p in $PLUGIN_EXCLUDE; do
    rm -rf "$TARGET/plugins/banto/$p"
    # also drop the i18n source copies AND the manifest entries. Dropping only the files
    # leaves the manifest referencing a now-absent ja source, which i18n-sync-check reports
    # as ORPHAN — the public CI failure this prune exists to prevent.
    case "$p" in
      skills/*)
        rm -rf "$TARGET/plugins/banto/i18n/ja/$p" "$TARGET/plugins/banto/i18n/en/$p"
        if [ -f "$PUB_MANIFEST" ]; then
            jq --arg pre "$p/" '.files |= with_entries(select((.key | startswith($pre)) | not))' \
                "$PUB_MANIFEST" > "$PUB_MANIFEST.tmp" && mv "$PUB_MANIFEST.tmp" "$PUB_MANIFEST"
        fi
        ;;
    esac
    printf '  - plugins/banto/%s (excluded, incl i18n + manifest)\n' "$p"
done

# Fresh public changelog (internal history is not carried over)
cat > "$TARGET/CHANGELOG.md" <<'MD'
# Changelog

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
MD

# Public versions start fresh and must match the CHANGELOG stub above
# (the internal 5.x line is private history and is not carried over)
PUB_VERSION="0.1.5"
for j in "plugins/banto/.claude-plugin/plugin.json:.version = \$v" \
         ".claude-plugin/marketplace.json:.metadata.version = \$v | .plugins[0].version = \$v"; do
    f="$TARGET/${j%%:*}"
    jq --arg v "$PUB_VERSION" "${j#*:}" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
printf '  ~ export versions set to %s (fresh public line)\n' "$PUB_VERSION"

# Public default = English, regardless of the dev's local language choice.
# /set-language materializes the chosen language into the loaded plugin's skills/, so a
# developer running banto from this source repo may have flipped skills/ to JA. The export
# must ship EN, so we re-materialize EN into the export copy (never touches the source tree).
if [ -d "$TARGET/plugins/banto/i18n/en" ]; then
    BANTO_PLUGIN_ROOT="$TARGET/plugins/banto" sh "$TARGET/plugins/banto/scripts/i18n-materialize.sh" en >/dev/null
    printf '  ~ materialized active skill/agent set to EN (public default)\n'
fi

# Init repo (no commit — publishing is a human gate) and run gates inside
cd "$TARGET"
git init -q
git add -A
printf '\n--- gates inside the export ---\n'
sh scripts/check-legacy-names.sh --code
sh scripts/check-legacy-names.sh
printf '\n--- syntax inside the export ---\n'
fail=0
for f in $(git ls-files '*.sh'); do sh -n "$f" || { printf 'SH FAIL: %s\n' "$f"; fail=1; }; done
for f in $(git ls-files '*.json'); do jq empty "$f" 2>/dev/null || { printf 'JSON FAIL: %s\n' "$f"; fail=1; }; done
[ "$fail" -eq 0 ] && printf 'syntax: all OK\n'

printf '\n--- i18n sync inside the export ---\n'
# Catches a stale manifest after PLUGIN_EXCLUDE (the ORPHAN class) before it reaches public CI.
BANTO_PLUGIN_ROOT="$TARGET/plugins/banto" sh "$TARGET/plugins/banto/scripts/i18n-sync-check.sh" || fail=1

printf '\n--- markdown links inside the export ---\n'
# Catches links that break only in the public tree (PLUGIN_EXCLUDE'd targets, language flips).
sh scripts/check-md-links.sh || fail=1

printf '\nExport ready: %s (%s files staged, NOT committed)\n' "$TARGET" "$(git ls-files | wc -l | tr -d ' ')"
printf 'Next (human gate): review, then commit and create the public repo.\n'
exit "$fail"
