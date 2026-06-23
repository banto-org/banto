#!/bin/sh
# webread.sh — fetches a URL's body as clean full-text Markdown "without any LLM summarization".
#
# Difference from WebFetch (built into Claude Code):
#   WebFetch returns the fetched page *summarized by a small model*, so the main model never
#   reads the raw body (omissions and distortions occur; cause of the incident where Webwright
#   was mistaken for having no MCP). webread extracts the full body with trafilatura (pure local,
#   no LLM, body-extraction benchmark F1=0.909), and the caller (the main model) reads that full
#   text directly. When a summary is needed, the main model reads first and then summarizes.
#
# Usage:
#   sh webread.sh <url>                 # output the full body as Markdown on stdout
#   sh webread.sh --html <file.html>    # extract from local HTML (e.g. an SPA rendered via Playwright)
#
# SPA / JS-rendered sites:
#   trafilatura fetches static HTML, so SPAs rendered by JS may yield no body.
#   In that case, save the rendered HTML via Claude in Chrome / Playwright MCP and pass it with
#   --html (two-stage flow). webread itself never renders (keeps it pure local with minimal deps).
#
# Dependencies: python3 + trafilatura (pip install --user trafilatura). curl is the fallback.
# POSIX compatible: macOS / Linux / WSL
set -u

# Locate the trafilatura CLI (PATH / pip --user default bin / python -m)
find_traf() {
    if command -v trafilatura >/dev/null 2>&1; then echo "trafilatura"; return 0; fi
    for b in "$HOME/Library/Python/"*/bin/trafilatura "$HOME/.local/bin/trafilatura"; do
        [ -x "$b" ] && { echo "$b"; return 0; }
    done
    return 1
}

MODE=url
SRC=""
case "${1:-}" in
    --html) MODE=html; SRC="${2:-}" ;;
    "" )    echo "usage: webread.sh <url> | webread.sh --html <file.html>" >&2; exit 2 ;;
    --* )   echo "webread: unknown option: $1" >&2; exit 2 ;;
    * )     SRC="$1" ;;
esac
[ -n "$SRC" ] || { echo "webread: no input given" >&2; exit 2; }

TRAF=$(find_traf || true)

if [ -z "$TRAF" ]; then
    echo "[webread] trafilatura is not installed. Install: pip install --user trafilatura" >&2
    if [ "$MODE" = "url" ]; then
        echo "[webread] fallback: fetching raw HTML via curl (no body extraction, tags included). The main model is expected to read it." >&2
        curl -fsSL --max-time 30 -A "Mozilla/5.0 (webread)" "$SRC" 2>/dev/null || {
            echo "[webread] curl also failed. Check the URL and network: $SRC" >&2; exit 1; }
    else
        cat "$SRC" 2>/dev/null || { echo "[webread] cannot read file: $SRC" >&2; exit 1; }
    fi
    exit 0
fi

# trafilatura proper (pure local, no LLM). Full text as markdown with metadata.
if [ "$MODE" = "url" ]; then
    OUT=$("$TRAF" --markdown --with-metadata -u "$SRC" 2>/dev/null)
else
    OUT=$("$TRAF" --markdown --with-metadata < "$SRC" 2>/dev/null)
fi

if [ -z "$OUT" ]; then
    echo "[webread] could not extract a body (possibly an SPA / dynamic site)." >&2
    echo "[webread] Fix: save the rendered HTML via Claude in Chrome / Playwright MCP and rerun with webread.sh --html <file>." >&2
    if [ "$MODE" = "url" ]; then
        echo "[webread] FYI: emitting raw HTML via curl (tags included; the main model is expected to read it)." >&2
        curl -fsSL --max-time 30 -A "Mozilla/5.0 (webread)" "$SRC" 2>/dev/null || true
    fi
    exit 1
fi

printf '%s\n' "$OUT"
