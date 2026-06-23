#!/bin/sh
# check-md-links.sh — deterministic markdown link gate for the banto repo.
#
# Rule 1 (FAIL): every relative, path-like link target in a tracked *.md resolves to an
#   existing path. Skipped: http(s)/mailto, pure #anchors, fenced/inline code (example
#   syntax), and non-path-like barewords (template placeholders like URL / url1).
# Rule 2 (WARN): a root language README (README.md / README.<lang>.md) must not link
#   into the active, language-flipping plugins/banto/skills/ tree — link the stable
#   i18n/<lang>/ canonical instead (the active path's language flips on materialize).
#
# Same three-layer placement as i18n-sync-check.sh: scripts/pre-push-check.sh,
# .github/workflows/ci.yml, and the export-public.sh internal gates. Uses git
# (rev-parse + ls-files), so it also runs inside the export's freshly-init'd tree.
# Findings go to a temp file (not $(...)) so case-in-loop stays parseable on macOS bash 3.2.
# Note: relies on word-splitting over git ls-files; tracked paths have no spaces.
set -eu

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "check-md-links: not a git repo — skip"; exit 0; }
cd "$ROOT"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

for f in $(git ls-files '*.md'); do
    dir=$(dirname "$f")
    # blank fenced code ranges (keep line count for grep -n), strip inline-code spans,
    # then list each ](target) with its original line number.
    sed -e '/^[[:space:]]*```/,/^[[:space:]]*```/ s/.*//' -e 's/`[^`]*`//g' "$f" 2>/dev/null \
      | grep -noE '\]\([^)]+\)' \
      | sed -E 's/^([0-9]+):\]\((.*)\)$/\1 \2/' \
      | while read -r ln t; do
        t=${t%% *}                                       # drop optional "title"
        case $t in http://*|https://*|mailto:*|'#'*|'') continue ;; esac
        path=${t%%#*}                                    # strip trailing #anchor
        [ -z "$path" ] && continue
        case $path in *[/.]*) ;; *) continue ;; esac     # skip non-path-like barewords (placeholders)
        case $f in README.md|README.*.md) case $path in
            plugins/banto/skills/*)
                printf 'WARN %s:%s active-path link (flips on materialize) — use i18n/<lang>/: %s\n' "$f" "$ln" "$path" >> "$tmp" ;;
        esac ;; esac
        case $path in /*) r=".$path" ;; *) r="$dir/$path" ;; esac
        [ -e "$r" ] || printf 'FAIL %s:%s broken link: %s\n' "$f" "$ln" "$t" >> "$tmp"
    done
done

fails=$(grep -c '^FAIL' "$tmp" 2>/dev/null || true)
warns=$(grep -c '^WARN' "$tmp" 2>/dev/null || true)
[ -s "$tmp" ] && cat "$tmp"
if [ "${fails:-0}" -ne 0 ]; then
    printf 'check-md-links FAIL: %s broken link(s) (%s warning(s))\n' "$fails" "$warns"
    exit 1
fi
printf 'check-md-links OK: 0 broken links (%s warning(s)) across %s md files\n' "${warns:-0}" "$(git ls-files '*.md' | wc -l | tr -d ' ')"
