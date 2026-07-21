#!/bin/sh
# test-setup-bootstrap.sh — unit test for hooks/banto-setup-bootstrap.sh (SessionStart self-heal).
#
# Hermetic: runs the hook against a throwaway HOME and the real plugin tree (BANTO_PLUGIN_ROOT),
# asserting the version-gated apply / no-op / re-apply / opt-out behavior. No network, no writes
# outside the temp HOME.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
HOOK="$PLUGIN_ROOT/hooks/banto-setup-bootstrap.sh"
VER=$(jq -r '.version // "?"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")

fails=0
ok()   { echo "  ok   $1"; }
bad()  { echo "  FAIL $1"; fails=$((fails+1)); }

command -v jq >/dev/null 2>&1 || { echo "test-setup-bootstrap: jq required — skip"; exit 0; }

TDIR=$(mktemp -d)
trap 'rm -rf "$TDIR"' EXIT
export BANTO_PLUGIN_ROOT="$PLUGIN_ROOT"

echo "== banto-setup-bootstrap =="

# [1] fresh machine (no marker) → applies + stamps marker == version
OUT=$(HOME="$TDIR" sh "$HOOK" 2>&1)
[ "$(cat "$TDIR/.claude/.banto-setup-done" 2>/dev/null)" = "$VER" ] && ok "fresh: marker stamped to version" || bad "fresh: marker not stamped ($VER)"
echo "$OUT" | grep -q "自動適用" && ok "fresh: prints loud summary" || bad "fresh: no summary printed"
SLCMD=$(jq -r '.statusLine.command // ""' "$TDIR/.claude/settings.json" 2>/dev/null)
case "$SLCMD" in
    /*token-monitor.sh) ok "fresh: statusLine command is an absolute path" ;;
    "~"*)               bad "fresh: statusLine command still uses tilde ($SLCMD)" ;;
    *)                  bad "fresh: statusLine command unexpected ($SLCMD)" ;;
esac
[ -f "$TDIR/ai-context-store/.ai-context-store" ] && ok "fresh: central store initialized" || bad "fresh: store marker missing"
[ -d "$TDIR/.claude/rules" ] && [ -n "$(ls "$TDIR/.claude/rules" 2>/dev/null)" ] && ok "fresh: rules deployed" || bad "fresh: rules not deployed"

# [2] second run with marker == version → fast no-op (no output, no re-apply)
OUT2=$(HOME="$TDIR" sh "$HOOK" 2>&1)
[ -z "$OUT2" ] && ok "repeat: no-op when marker matches version" || bad "repeat: re-applied (output: $OUT2)"

# [3] stale marker (version bump) → re-applies and updates marker
echo "0.0.0-old" > "$TDIR/.claude/.banto-setup-done"
HOME="$TDIR" sh "$HOOK" >/dev/null 2>&1
[ "$(cat "$TDIR/.claude/.banto-setup-done" 2>/dev/null)" = "$VER" ] && ok "stale: re-applied and bumped marker" || bad "stale: marker not updated"

# [4] BANTO_SKIP_BOOTSTRAP opt-out → no-op even on a fresh HOME
TDIR2=$(mktemp -d)
OUT4=$(HOME="$TDIR2" BANTO_SKIP_BOOTSTRAP=1 sh "$HOOK" 2>&1)
[ -z "$OUT4" ] && [ ! -e "$TDIR2/.claude/.banto-setup-done" ] && ok "opt-out: BANTO_SKIP_BOOTSTRAP skips entirely" || bad "opt-out: did not skip"
rm -rf "$TDIR2"

# ---- issue #109: a failed / partial apply must NOT be stamped (self-heal keeps retrying) ----
# Fake plugin root: plugin.json + statuslines/ + a swappable harness-setup.sh.
FAKE=$(mktemp -d)
mkdir -p "$FAKE/scripts" "$FAKE/statuslines" "$FAKE/.claude-plugin"
printf '{"name":"banto","version":"9.9.9"}\n' > "$FAKE/.claude-plugin/plugin.json"
printf '#!/bin/sh\necho "shipped statusline v9.9.9"\n' > "$FAKE/statuslines/token-monitor.sh"

# [5] harness-setup exits non-zero → no stamp + retry warning
printf '#!/bin/sh\nexit 1\n' > "$FAKE/scripts/harness-setup.sh"
TDIR5=$(mktemp -d)
OUT5=$(HOME="$TDIR5" BANTO_PLUGIN_ROOT="$FAKE" sh "$HOOK" 2>&1)
[ ! -e "$TDIR5/.claude/.banto-setup-done" ] && ok "fail: non-zero setup is not stamped" || bad "fail: failure was stamped as done"
echo "$OUT5" | grep -q "完走しなかった" && ok "fail: prints retry warning" || bad "fail: no retry warning ($OUT5)"

# [6] setup exits 0 but the key artifact was not deployed → no stamp (stale-deployment class)
printf '#!/bin/sh\nexit 0\n' > "$FAKE/scripts/harness-setup.sh"
OUT6=$(HOME="$TDIR5" BANTO_PLUGIN_ROOT="$FAKE" sh "$HOOK" 2>&1)
[ ! -e "$TDIR5/.claude/.banto-setup-done" ] && ok "mismatch: exit-0 without artifact is not stamped" || bad "mismatch: stale deployment was stamped"

# [7] next session with a healthy setup → stamps (the retry promise)
printf '#!/bin/sh\nmkdir -p "$HOME/.claude/statuslines"\ncp "%s/statuslines/token-monitor.sh" "$HOME/.claude/statuslines/"\nexit 0\n' "$FAKE" > "$FAKE/scripts/harness-setup.sh"
OUT7=$(HOME="$TDIR5" BANTO_PLUGIN_ROOT="$FAKE" sh "$HOOK" 2>&1)
[ "$(cat "$TDIR5/.claude/.banto-setup-done" 2>/dev/null)" = "9.9.9" ] && ok "retry: healthy re-run stamps the marker" || bad "retry: marker still absent after healthy run"
rm -rf "$TDIR5" "$FAKE"

if [ "$fails" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "FAILED ($fails)"; exit 1; fi
