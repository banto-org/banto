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
PLUGIN_EXCLUDE="skills/status skills/harness-audit skills/banto-port scripts/migrate-store-layout.sh scripts/migrate-store-v2.sh scripts/migrate-to-store.sh"

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
PUB_VERSION="0.1.2"
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
