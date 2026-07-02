#!/bin/sh
# i18n-en-sanity.sh — detect CORRUPTED i18n/en files: ones that are a leaked agent / Stop-hook
# note (or a collapsed stub) instead of a faithful translation of their i18n/ja source.
#
# Why hashes are not enough: i18n-gen's translator (an LLM) can fail by emitting a conversational
# message ("I've rebuilt the file…") instead of the translated content. If that output gets
# recorded into .sync-manifest.json, i18n-sync-check.sh (hash-only) treats it as "in sync" and the
# garbage ships. This gate checks CONTENT sanity — structural parity with the JA source + leak
# markers — which a hash comparison cannot see.
#
# Flags an EN file (vs its JA source) when ANY of:
#   - size collapse      : en line count < ja_lines / 3 (a faithful translation is comparable)
#   - structure lost     : ja has >= 3 markdown headings but en has 0
#   - frontmatter broken : ja starts with '---' on line 1 but en does not
#   - leak markers       : agent / Stop-hook chatter in the en body
#
# Usage:  i18n-en-sanity.sh [<plugin_dir|repo_dir>] [--strict]
# exit 1 on any flagged file when --strict. Read-only. POSIX sh.
set -u

DIR="."
STRICT=0
for a in "$@"; do
    case "$a" in --strict) STRICT=1 ;; *) DIR="$a" ;; esac
done

# Accept either a repo root (…/plugins/banto/i18n) or a plugin root (…/i18n).
if   [ -d "$DIR/plugins/banto/i18n/ja" ]; then EN="$DIR/plugins/banto/i18n/en"; JA="$DIR/plugins/banto/i18n/ja"
elif [ -d "$DIR/i18n/ja" ];               then EN="$DIR/i18n/en";               JA="$DIR/i18n/ja"
else echo "i18n-en-sanity: no i18n/ja under '$DIR' — skip"; exit 0; fi

# High-confidence leak markers: unambiguous agent / decision-note chatter. Deliberately NARROW —
# pattern-name tokens that skills legitimately DOCUMENT (subagent_tokens / duration_ms / "Stop hook")
# are excluded to avoid flagging scoring.md / directory-structure.md. The structural checks above are
# the reliable backbone; these only corroborate.
LEAK_PAT='No design decision was made|[Tt]ranslated file is ready|I won.{0,2}t fabricate|If you.{0,3}d like, I can apply|I have (rebuilt|regenerated|re-?translated)|Here is the (translated|updated) (file|version)|承知しました|この(会話|ターン)で(は)?(設計)?判断'

count() { grep -cE "$1" "$2" 2>/dev/null || true; }

FLAG=0
echo "## i18n EN sanity (corruption detector)"
echo ""
echo "| EN file | reason |"
echo "|---------|--------|"
for ef in $(find "$EN" -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null | sort); do
    rel=${ef#"$EN"/}
    jf="$JA/$rel"
    [ -e "$jf" ] || continue
    reasons=""
    el=$(wc -l < "$ef" | tr -d ' '); jl=$(wc -l < "$jf" | tr -d ' ')
    if [ "$jl" -ge 9 ] && [ "$el" -lt $((jl / 3)) ]; then reasons="$reasons size-collapse(en=$el/ja=$jl)"; fi
    jh=$(count '^#' "$jf"); eh=$(count '^#' "$ef")
    if [ "$jh" -ge 3 ] && [ "$eh" -eq 0 ]; then reasons="$reasons structure-lost(ja_headings=$jh)"; fi
    if head -1 "$jf" | grep -q '^---' && ! head -1 "$ef" | grep -q '^---'; then reasons="$reasons frontmatter-broken"; fi
    if grep -qE "$LEAK_PAT" "$ef" 2>/dev/null; then reasons="$reasons leak-markers"; fi
    if [ -n "$reasons" ]; then echo "| $rel |$reasons |"; FLAG=$((FLAG + 1)); fi
done
echo ""
echo "Flagged: $FLAG"
echo ""
echo "_Companion to i18n-sync-check (ja<->en hash) and i18n-materialize-check (canonical<->active): this checks EN CONTENT validity that hashes miss._"

if [ "$STRICT" -eq 1 ] && [ "$FLAG" -gt 0 ]; then exit 1; fi
exit 0
