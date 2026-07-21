#!/bin/sh
# banto-setup-bootstrap.sh — SessionStart hook. First-run / post-upgrade self-heal.
#
# Removes the manual "run scripts/harness-setup.sh" onboarding step: on the first session on a
# machine (and after each plugin version bump), this idempotently applies the user-level harness
# setup — behavioral rules, settings.json (statusLine / permissions / sandbox / autoUpdate), and
# the central store — then prints a loud summary and a restart reminder (settings + statusLine
# are read at startup, so the current session shows them only after a restart).
#
# Gated by a version-stamped marker (~/.claude/.banto-setup-done, content = plugin version):
# runs only when the marker is absent or its version != the installed plugin version. Fail-open —
# every error is swallowed so a broken setup can never block a session (same philosophy as the
# egress guard / i18n-reconcile).
#
# harness-setup is itself idempotent (custom rules / statusLine / settings are preserved, the
# banto-owned statusLine is repaired to the canonical absolute path), so re-running is safe.
# When jq is missing the settings merge is skipped (harness-setup warns) and the marker is NOT
# stamped, so the full setup completes automatically once jq is installed.
#
# Overridable for tests: BANTO_PLUGIN_ROOT, BANTO_SETUP_MARKER, BANTO_SKIP_BOOTSTRAP.
set -eu

# Explicit opt-out (e.g. users who manage their own dotfiles and never want auto-mutation).
[ -n "${BANTO_SKIP_BOOTSTRAP:-}" ] && exit 0

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)        # real hooks/ dir (from $0)
REAL_PLUGIN=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)           # real plugin root (has scripts/)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$REAL_PLUGIN}
SETUP="$PLUGIN_ROOT/scripts/harness-setup.sh"
MARKER=${BANTO_SETUP_MARKER:-$HOME/.claude/.banto-setup-done}

[ -f "$SETUP" ] || exit 0

VER=$(jq -r '.version // "?"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")
PREV=$(cat "$MARKER" 2>/dev/null || echo "")
[ "$PREV" = "$VER" ] && exit 0    # already set up for this version → fast no-op

# Apply the user-level setup (idempotent). Output stays swallowed — a failure must never block
# a session — but a failure must NOT be stamped as done either (issue #109: the masked failure
# froze self-heal until the next version bump).
SETUP_OK=0
sh "$SETUP" >/dev/null 2>&1 && SETUP_OK=1

# Key-artifact verification: the deployed statusline must byte-match the shipped one (the
# regression class of #109 — exit 0 with a stale deployment). harness-setup copies the file
# unconditionally, so a mismatch here means the apply did not actually land.
if [ "$SETUP_OK" = 1 ] && [ -f "$PLUGIN_ROOT/statuslines/token-monitor.sh" ]; then
    cmp -s "$PLUGIN_ROOT/statuslines/token-monitor.sh" "$HOME/.claude/statuslines/token-monitor.sh" 2>/dev/null || SETUP_OK=0
fi

if ! command -v jq >/dev/null 2>&1; then
    # No jq → settings/statusLine could not be wired. Do NOT stamp; retry next session once jq exists.
    echo "[Banto setup] ⚠ jq が無いため設定の自動配線を保留しました。jq を入れて再起動すると自動で完了します（rules と store は配置済み）。"
elif [ "$SETUP_OK" = 1 ]; then
    # Full apply verified (setup exited 0 + key artifact matches). Stamp so we don't re-run every session.
    mkdir -p "$(dirname "$MARKER")" 2>/dev/null || true
    printf '%s' "$VER" > "$MARKER" 2>/dev/null || true
    echo "[Banto setup] 初回/更新セットアップを自動適用しました（v${VER}）:"
    echo "  • 行動ルール → ~/.claude/rules/（既存カスタムは保持）"
    echo "  • settings.json: statusLine（絶対パス・自己修復）/ permissions / sandbox（既定 off）/ AskUserQuestion deny / autoUpdate"
    echo "  • 中央ストア → ~/ai-context-store/ を初期化"
    echo "  ⟳ statusLine と settings の反映には Claude Code の再起動が必要です。"
    echo "  （適用内容は ~/.claude/settings.json で確認・変更できます）"
else
    # Setup failed or the key artifact does not match. Do NOT stamp — retry on the next session.
    echo "[Banto setup] ⚠ harness-setup が完走しなかったため、完了マーカーを記録していません。次のセッション開始時に自動で再試行します（手動実行: sh \"$SETUP\"）。"
fi

exit 0
