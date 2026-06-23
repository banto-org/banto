#!/bin/sh
# plugin-cache-gc.sh — garbage-collects old versions from the plugin cache
#
# Background: `claude plugin update` does not delete old version dirs, so
# ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/ keeps accumulating
# (measured: 16 banto versions × 44M ≈ 700MB; the cache GC item of decisions/2026-05-29_005).
#
# Deterministic rule (safe side):
#   Keep = versions referenced by installPath in installed_plugins.json (all scopes)
#        + each plugin's most recent KEEP versions (mtime descending, default 2; may overlap referenced ones)
#   Delete the rest. No-op when installed_plugins.json is unreadable (fail-safe).
#
# Usage:
#   plugin-cache-gc.sh            # dry-run (shows deletion targets)
#   plugin-cache-gc.sh --apply    # execute
#   --keep N                      # number of recent versions to keep (default 2)
#   env: BANTO_PLUGIN_CACHE_ROOT / BANTO_INSTALLED_PLUGINS_JSON (overrides for tests)
#
# Auto-run asynchronously with a daily throttle from the SessionStart hook (self-driving harness principle).
# POSIX compatible: macOS / Linux / WSL

set -u

APPLY=0
KEEP=2
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1; shift ;;
        --keep)  KEEP="${2:?--keep requires N}"; shift 2 ;;
        *) echo "usage: plugin-cache-gc.sh [--apply] [--keep N]" >&2; exit 2 ;;
    esac
done

command -v jq >/dev/null 2>&1 || exit 0
CACHE="${BANTO_PLUGIN_CACHE_ROOT:-$HOME/.claude/plugins/cache}"
MANIFEST="${BANTO_INSTALLED_PLUGINS_JSON:-$HOME/.claude/plugins/installed_plugins.json}"
[ -d "$CACHE" ] || exit 0
[ -f "$MANIFEST" ] || exit 0

# List of referenced installPaths (fail-safe no-op when unreadable)
REFS=$(jq -r '.plugins // {} | to_entries[] | .value[]? | .installPath // empty' "$MANIFEST" 2>/dev/null)
jq -e '.plugins' "$MANIFEST" >/dev/null 2>&1 || exit 0

for mp in "$CACHE"/*/; do
    [ -d "$mp" ] || continue
    for pl in "$mp"*/; do
        [ -d "$pl" ] || continue
        # List version dirs in mtime-descending order
        _i=0
        ls -td "$pl"*/ 2>/dev/null | while IFS= read -r v; do
            v="${v%/}"
            [ -d "$v" ] || continue
            _i=$((_i + 1))
            # Keep the most recent KEEP versions
            [ "$_i" -le "$KEEP" ] && continue
            # Keep referenced versions (exact line match; substring matching would wrongly keep 5.21.2 ⊂ 5.21.24)
            printf '%s\n' "$REFS" | grep -qxF "$v" && continue
            sz=$(du -sh "$v" 2>/dev/null | cut -f1)
            if [ "$APPLY" -eq 1 ]; then
                rm -rf "$v"
                echo "gc: removed ${v#"$CACHE"/} ($sz)"
            else
                echo "gc: would-remove ${v#"$CACHE"/} ($sz)"
            fi
        done
    done
done

[ "$APPLY" -eq 1 ] || echo "(dry-run; execute with --apply)"
exit 0
