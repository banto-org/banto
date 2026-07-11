#!/bin/sh
# test-harness-drift-autoupdate.sh — harness-drift-check.sh の live 反映半自動化（S4）検証
#
# 検証:
#   1. version 差分検知 + claude CLI 成功 → marketplace update / plugin update を実行し
#      「auto-applied」を報告する
#   2. 1 日 1 回のスロットル: 同日 2 回目は claude を再実行しない（呼び出し回数が増えない）
#   3. claude CLI が失敗 → 従来どおりの手動指示メッセージへフォールバック、以降も再試行しない
#   4. claude CLI が PATH に無い環境 → 従来どおりの手動指示メッセージへ fail-open
#
# 隔離: 合成の editing repo / live plugin.json + fake claude 実行ファイル + 合成 TMPDIR
#   （スロットル marker が実 TMPDIR を汚さないようにする）。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$DIR/scripts/harness-drift-check.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/drift-autoupdate.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

EDIT_DIR="$TMP/editrepo"
mkdir -p "$EDIT_DIR/plugins/banto/.claude-plugin"
printf '{"name":"banto","version":"9.9.9"}\n' > "$EDIT_DIR/plugins/banto/.claude-plugin/plugin.json"

RUN_DIR="$TMP/live"
mkdir -p "$RUN_DIR/.claude-plugin"
printf '{"name":"banto","version":"9.9.8"}\n' > "$RUN_DIR/.claude-plugin/plugin.json"

FAKEBIN="$TMP/bin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/claude" <<'FAKECLAUDE'
#!/bin/sh
echo "$@" >> "$CLAUDE_CALL_LOG"
exit "${FAKE_CLAUDE_RC:-0}"
FAKECLAUDE
chmod +x "$FAKEBIN/claude"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

call_count() { # log
    [ -f "$1" ] && grep -c . "$1" || echo 0
}

# === 1 & 2: 成功 + スロットル ===
T1="$TMP/tmp1"; mkdir -p "$T1"
LOG1="$T1/claude-calls.log"
OUT1=$(PATH="$FAKEBIN:$PATH" TMPDIR="$T1" CLAUDE_PLUGIN_ROOT="$RUN_DIR" \
    CLAUDE_CALL_LOG="$LOG1" FAKE_CLAUDE_RC=0 sh "$HOOK" "$EDIT_DIR" 2>/dev/null)
case "$OUT1" in
    *"auto-applied"*) ok "1: success path reports auto-applied" ;;
    *) bad "1: success path did not report auto-applied ($OUT1)" ;;
esac
N1=$(call_count "$LOG1")
[ "$N1" -eq 2 ] && ok "1: claude invoked twice (marketplace update + plugin update)" \
    || bad "1: expected 2 claude invocations, got $N1"

OUT1B=$(PATH="$FAKEBIN:$PATH" TMPDIR="$T1" CLAUDE_PLUGIN_ROOT="$RUN_DIR" \
    CLAUDE_CALL_LOG="$LOG1" FAKE_CLAUDE_RC=0 sh "$HOOK" "$EDIT_DIR" 2>/dev/null)
N1B=$(call_count "$LOG1")
[ "$N1B" -eq 2 ] && ok "2: same-day second run does not re-invoke claude (throttled)" \
    || bad "2: throttle failed, invocation count grew to $N1B"
case "$OUT1B" in
    *"auto-applied"*) ok "2: throttled run still reports the earlier applied state" ;;
    *) bad "2: throttled run lost the applied notice ($OUT1B)" ;;
esac

# === 3: claude 失敗 → フォールバック + 再試行しない ===
T2="$TMP/tmp2"; mkdir -p "$T2"
LOG2="$T2/claude-calls.log"
OUT2=$(PATH="$FAKEBIN:$PATH" TMPDIR="$T2" CLAUDE_PLUGIN_ROOT="$RUN_DIR" \
    CLAUDE_CALL_LOG="$LOG2" FAKE_CLAUDE_RC=1 sh "$HOOK" "$EDIT_DIR" 2>/dev/null)
case "$OUT2" in
    *"harness drift"*"version mismatch"*) ok "3: claude failure falls back to manual instructions" ;;
    *) bad "3: failure path did not fall back correctly ($OUT2)" ;;
esac
case "$OUT2" in *"auto-applied"*) bad "3: failure path wrongly claimed auto-applied" ;; *) ok "3: failure path does not claim success" ;; esac
N2=$(call_count "$LOG2")

OUT2B=$(PATH="$FAKEBIN:$PATH" TMPDIR="$T2" CLAUDE_PLUGIN_ROOT="$RUN_DIR" \
    CLAUDE_CALL_LOG="$LOG2" FAKE_CLAUDE_RC=1 sh "$HOOK" "$EDIT_DIR" 2>/dev/null)
N2B=$(call_count "$LOG2")
[ "$N2B" -eq "$N2" ] && ok "3: same-day retry after failure does not re-invoke claude" \
    || bad "3: failure throttle did not hold ($N2 -> $N2B)"

# === 4: claude が PATH に無い → 従来どおりの手動指示へ fail-open ===
T3="$TMP/tmp3"; mkdir -p "$T3"
NOCLAUDE_BIN="$TMP/nocloudbin"
mkdir -p "$NOCLAUDE_BIN"
for c in sh jq git find cksum sort awk grep sed cat cd basename dirname date; do
    p=$(command -v "$c" 2>/dev/null) && ln -sf "$p" "$NOCLAUDE_BIN/$c" 2>/dev/null
done
OUT3=$(PATH="$NOCLAUDE_BIN" TMPDIR="$T3" CLAUDE_PLUGIN_ROOT="$RUN_DIR" \
    sh "$HOOK" "$EDIT_DIR" 2>/dev/null)
case "$OUT3" in
    *"harness drift"*"version mismatch"*) ok "4: no-claude-on-PATH falls back to manual instructions" ;;
    *) bad "4: no-claude-on-PATH did not fail open correctly ($OUT3)" ;;
esac

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
