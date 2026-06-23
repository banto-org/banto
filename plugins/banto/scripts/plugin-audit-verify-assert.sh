#!/bin/sh
# plugin-audit-verify-assert.sh
# Deterministic assertion checker for `plugin-audit verify` (functional verification).
#
# Given a produced base directory (the artifacts a skill generated for a verify-case),
# run deterministic assertions on the output. This is the deterministic layer; the
# judgmental layer (does the content actually satisfy the claim) is a separate agent pass.
#
# Assertions are passed as explicit flags (not parsed from YAML here) so this stays a
# dependency-free, unit-testable POSIX script. The `plugin-audit verify` procedure reads
# verify-cases.yaml and translates each case into one invocation of this checker.
#
# Glob/heading/forbidden matches are LITERAL substrings (grep -F), so filenames containing
# glob metacharacters — notably the `[Memo]` / `[Audit]` prefixes — match safely.
#
# Usage:
#   plugin-audit-verify-assert.sh --dir <produced-base> [checks...]
# Checks (any subset):
#   --glob "<substr>"               ≥1 file whose relative path contains <substr>
#   --headings "A|B|C"              every matched file contains each (literal) heading
#   --forbidden "x|y"               no matched file contains any of these (literal) strings
#   --no-template-vars "<substr>"   <substr> (e.g. "{{" ) must not appear in matched files
#   --writes-only-under "<prefix>"  every file under <dir> has a relative path starting with <prefix>
# Exit: 0 if all checks pass, 1 if any fail. One PASS/FAIL line per check.

set -u
DIR=""
GLOB=""; HEADINGS=""; FORBIDDEN=""; NOTPL=""; WUNDER=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DIR=$2; shift 2 ;;
        --glob) GLOB=$2; shift 2 ;;
        --headings) HEADINGS=$2; shift 2 ;;
        --forbidden) FORBIDDEN=$2; shift 2 ;;
        --no-template-vars) NOTPL=$2; shift 2 ;;
        --writes-only-under) WUNDER=$2; shift 2 ;;
        *) printf 'unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done
[ -n "$DIR" ] || { printf 'error: --dir required\n' >&2; exit 2; }
[ -d "$DIR" ] || { printf 'error: --dir not a directory: %s\n' "$DIR" >&2; exit 2; }

FAIL=0
DIRN="${DIR%/}"

# relative paths of all files under DIR (one per line)
ALL_REL=$(find "$DIRN" -type f 2>/dev/null | sed "s#^$DIRN/##")

# --- glob: ≥1 file path contains GLOB (literal) ---
MATCHED=""
if [ -n "$GLOB" ]; then
    MATCHED=$(printf '%s\n' "$ALL_REL" | grep -F "$GLOB" 2>/dev/null)
    if [ -n "$MATCHED" ]; then
        printf 'PASS glob: %d file(s) match "%s"\n' "$(printf '%s\n' "$MATCHED" | grep -c .)" "$GLOB"
    else
        printf 'FAIL glob: no file matches "%s"\n' "$GLOB"; FAIL=1
    fi
fi

# content checks apply to MATCHED files (or, if no glob given, all files)
TARGETS="$MATCHED"
[ -z "$GLOB" ] && TARGETS="$ALL_REL"

# read matched files' content once
content_of() {
    printf '%s\n' "$1" | while IFS= read -r rel; do
        [ -n "$rel" ] && cat "$DIRN/$rel" 2>/dev/null
    done
}

# --- headings: every listed heading present across matched files ---
if [ -n "$HEADINGS" ]; then
    BODY=$(content_of "$TARGETS")
    miss=""
    OLDIFS=$IFS; IFS='|'
    for h in $HEADINGS; do
        [ -z "$h" ] && continue
        printf '%s' "$BODY" | grep -Fq "$h" || miss="$miss $h"
    done
    IFS=$OLDIFS
    if [ -z "$miss" ]; then printf 'PASS headings: all present\n'
    else printf 'FAIL headings: missing ->%s\n' "$miss"; FAIL=1; fi
fi

# --- forbidden: none present ---
if [ -n "$FORBIDDEN" ]; then
    BODY=$(content_of "$TARGETS")
    hit=""
    OLDIFS=$IFS; IFS='|'
    for s in $FORBIDDEN; do
        [ -z "$s" ] && continue
        printf '%s' "$BODY" | grep -Fq "$s" && hit="$hit $s"
    done
    IFS=$OLDIFS
    if [ -z "$hit" ]; then printf 'PASS forbidden: none present\n'
    else printf 'FAIL forbidden: present ->%s\n' "$hit"; FAIL=1; fi
fi

# --- no-template-vars: substr absent ---
if [ -n "$NOTPL" ]; then
    BODY=$(content_of "$TARGETS")
    if printf '%s' "$BODY" | grep -Fq "$NOTPL"; then
        printf 'FAIL no-template-vars: "%s" still present (unfilled)\n' "$NOTPL"; FAIL=1
    else
        printf 'PASS no-template-vars: "%s" absent\n' "$NOTPL"
    fi
fi

# --- writes-only-under: every file under the allowed prefix ---
if [ -n "$WUNDER" ]; then
    stray=$(printf '%s\n' "$ALL_REL" | while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        # print rel only if it does NOT start with the allowed prefix (prefix-strip leaves it unchanged)
        if [ "${rel#"$WUNDER"}" = "$rel" ]; then
            printf '%s\n' "$rel"
        fi
    done)
    if [ -z "$stray" ]; then printf 'PASS writes-only-under: all files under "%s"\n' "$WUNDER"
    else printf 'FAIL writes-only-under: stray ->\n%s\n' "$stray"; FAIL=1; fi
fi

exit $FAIL
