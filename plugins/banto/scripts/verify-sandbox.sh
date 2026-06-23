#!/bin/sh
# verify-sandbox.sh — set up / tear down the `plugin-audit verify` sandbox.
#
# The fixture base (a throwaway ai-context base under TMPDIR) + the verify-write-guard
# (PreToolUse) together guarantee a verified skill writes only to disposable space — the
# real store and repo stay untouched. The verify procedure (plugin-audit SKILL.md) injects
# the printed base path as the skill's ai-context base for the run.
#
# Note: this isolates *Write/Edit*. For skills that mutate the repo via Bash git commands,
# layer a `git worktree` on top (run the verify subagent with cwd in a throwaway worktree).
# Tier A skills (memo/spec → docs/ output) need only the fixture base + guard.
#
# Usage:
#   base=$(verify-sandbox.sh start)      # creates fixture base + activates the guard; prints base
#   verify-sandbox.sh stop ["$base"]     # deactivates the guard; removes the fixture base if given
set -u

# macOS の TMPDIR は末尾 '/' 付き（/var/folders/.../T/）。そのまま mktemp テンプレに使うと
# base に '//' が混入し、verify-write-guard の literal 比較が canonicalized な Write target と
# 食い違って全 Write が誤ブロックされる。末尾スラッシュを畳んでから使う。
TMP="${TMPDIR:-/tmp}"; TMP="${TMP%/}"
MARKER="$TMP/banto-verify-active"

case "${1:-}" in
    start)
        BASE=$(mktemp -d "$TMP/banto-verify-XXXXXX") || exit 1
        mkdir -p "$BASE/docs" "$BASE/decisions"
        printf '%s\n%s\n' "$BASE" "$(date +%s)" > "$MARKER"
        printf '%s\n' "$BASE"
        ;;
    stop)
        rm -f "$MARKER"
        if [ -n "${2:-}" ]; then
            # only remove paths we created (TMPDIR/banto-verify-*) — never an arbitrary dir
            case "$2" in
                "$TMP"/banto-verify-*) rm -rf "$2" ;;
            esac
        fi
        ;;
    *)
        printf 'usage: verify-sandbox.sh start | stop [fixture-base]\n' >&2
        exit 2
        ;;
esac
