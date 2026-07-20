#!/bin/sh
# test-checkpoint-autofire.sh — コンテキスト 90% 到達時の自動 /save-checkpoint 発火と
# 二重発火防止（idle-checkpoint 経路との排他 + 同一セッション内の再発火抑制）を検証する（S4）。
#
# 検証:
#   1. TIER=90 へ新規到達 → AUTO-FIRING メッセージを出し、実際に checkpoint-autofire.sh
#      経由で（detach fork の先で）claude が呼ばれる
#   2. 同一セッション・同ティアの再送信は既存の WARNED_FILE 機構でそもそも再通知されない
#   3. idle-checkpoint-watch 側からの直接呼び出しは、同一セッションの排他ロックにより
#      実行されない（claude が再度呼ばれない = 二重発火防止）
#   4. 別セッションは独立にロックされ、正常に自動発火する
#   5. fail-open: claude CLI が PATH に無い → 従来どおりの手動 URGENT メッセージ
#
# 隔離: 合成 HOME + 合成 TMPDIR（token-pct / warned / autofire ロックの marker を隔離）+
#   fake claude 実行ファイル。実 claude は一切起動しない。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
RECOMMEND="$DIR/hooks/checkpoint-recommend.sh"
AUTOFIRE="$DIR/hooks/checkpoint-autofire.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

unset CLAUDE_PLUGIN_ROOT 2>/dev/null || true

TMP=$(mktemp -d "${TMPDIR:-/tmp}/checkpoint-autofire.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
FAKE_TMP="$TMP/tmp"
mkdir -p "$FAKE_HOME/.claude" "$FAKE_TMP"

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

count_lines() { # file
    [ -f "$1" ] && wc -l < "$1" 2>/dev/null | tr -d ' ' || echo 0
}

wait_for_log_lines() { # logfile min_lines timeout_tenths
    _n=0
    while [ "$(count_lines "$1")" -lt "$2" ] && [ "$_n" -lt "$3" ]; do
        sleep 0.1; _n=$((_n + 1))
    done
}

CWD="$TMP/repo"
mkdir -p "$CWD"
TRANSCRIPT="$TMP/transcript.jsonl"
printf '{}\n' > "$TRANSCRIPT"

run_recommend() { # session_id pct claude_call_log
    _sid="$1"; _pct="$2"; _log="$3"
    printf '%s' "$_pct" > "$FAKE_TMP/banto-token-pct-${_sid}"
    printf '%s' "{\"session_id\":\"$_sid\",\"transcript_path\":\"$TRANSCRIPT\",\"cwd\":\"$CWD\"}" \
        | env HOME="$FAKE_HOME" TMPDIR="$FAKE_TMP" PATH="$FAKEBIN:$PATH" \
              CLAUDE_CALL_LOG="$_log" FAKE_CLAUDE_RC=0 sh "$RECOMMEND" 2>/dev/null
}

# === 1. TIER=90 到達 → AUTO-FIRING + 実際に claude が呼ばれる ===
SID1="s-autofire-1"
LOG1="$TMP/claude-calls-1.log"
: > "$LOG1"
OUT1=$(run_recommend "$SID1" 95 "$LOG1")
case "$OUT1" in *"AUTO-FIRING"*) ok "1: tier-90 crossing reports AUTO-FIRING" ;; *) bad "1: missing AUTO-FIRING notice ($OUT1)" ;; esac
wait_for_log_lines "$LOG1" 1 30
N1=$(count_lines "$LOG1")
[ "$N1" -ge 1 ] && ok "1: background fork invoked claude via checkpoint-autofire.sh" || bad "1: claude was never invoked (N=$N1)"

# === 2. 同一セッション・同ティアの再送信は既存の WARNED_FILE により再通知されない ===
OUT1B=$(run_recommend "$SID1" 95 "$LOG1")
[ -z "$OUT1B" ] && ok "2: same-tier re-submit is silent (WARNED_FILE suppression)" || bad "2: unexpected repeat notice ($OUT1B)"

# === 3. idle-checkpoint-watch 側からの直接呼び出しは排他ロックで弾かれる（二重発火防止） ===
N_BEFORE=$(count_lines "$LOG1")
env HOME="$FAKE_HOME" TMPDIR="$FAKE_TMP" CLAUDE_CALL_LOG="$LOG1" FAKE_CLAUDE_RC=0 \
    sh "$AUTOFIRE" "$SID1" "$TRANSCRIPT" "$CWD" "$FAKEBIN/claude" idle >/dev/null 2>&1
N_AFTER=$(count_lines "$LOG1")
[ "$N_AFTER" -eq "$N_BEFORE" ] && ok "3: idle-path re-entry is locked out (no extra claude invocation)" \
    || bad "3: idle-path re-entry re-invoked claude ($N_BEFORE -> $N_AFTER)"

# === 4. 別セッションは独立にロックされ、正常に自動発火する ===
SID2="s-autofire-2"
LOG2="$TMP/claude-calls-2.log"
: > "$LOG2"
OUT2=$(run_recommend "$SID2" 95 "$LOG2")
case "$OUT2" in *"AUTO-FIRING"*) ok "4: a different session also crosses tier-90 and fires" ;; *) bad "4: different session did not auto-fire ($OUT2)" ;; esac
wait_for_log_lines "$LOG2" 1 30
N2=$(count_lines "$LOG2")
[ "$N2" -ge 1 ] && ok "4: different session's fork also invoked claude" || bad "4: different session's claude was never invoked"

# === 5. fail-open: claude CLI が PATH に無い → 従来どおりの手動 URGENT メッセージ ===
NOCLAUDE_BIN="$TMP/nocloudbin"
mkdir -p "$NOCLAUDE_BIN"
for c in sh jq cat; do
    p=$(command -v "$c" 2>/dev/null) && ln -sf "$p" "$NOCLAUDE_BIN/$c" 2>/dev/null
done
SID3="s-autofire-3"
printf '%s' "95" > "$FAKE_TMP/banto-token-pct-${SID3}"
OUT3=$(printf '%s' "{\"session_id\":\"$SID3\",\"transcript_path\":\"$TRANSCRIPT\",\"cwd\":\"$CWD\"}" \
    | env HOME="$FAKE_HOME" TMPDIR="$FAKE_TMP" PATH="$NOCLAUDE_BIN" sh "$RECOMMEND" 2>/dev/null)
case "$OUT3" in
    *"URGENT"*) ok "5: no-claude-on-PATH falls back to the manual URGENT message" ;;
    *) bad "5: no-claude-on-PATH did not fail open ($OUT3)" ;;
esac
case "$OUT3" in *"AUTO-FIRING"*) bad "5: no-claude-on-PATH wrongly claimed AUTO-FIRING" ;; *) ok "5: no-claude-on-PATH does not claim auto-fire" ;; esac

# === 6. クールダウン経過後は同一セッションでも再発火する（永続ロックではない） ===
# 3 で SID1 のロックは残っている。COOLDOWN=0 で即 stale 化 → idle 経路の再入が再び claude を呼ぶ。
N_BEFORE6=$(count_lines "$LOG1")
env HOME="$FAKE_HOME" TMPDIR="$FAKE_TMP" CLAUDE_CALL_LOG="$LOG1" FAKE_CLAUDE_RC=0 \
    BANTO_CHECKPOINT_COOLDOWN_SEC=0 \
    sh "$AUTOFIRE" "$SID1" "$TRANSCRIPT" "$CWD" "$FAKEBIN/claude" idle >/dev/null 2>&1
N_AFTER6=$(count_lines "$LOG1")
[ "$N_AFTER6" -gt "$N_BEFORE6" ] && ok "6: cooldown expiry allows re-fire in same session" \
    || bad "6: re-fire did not happen after cooldown ($N_BEFORE6 -> $N_AFTER6)"

# === 7. 上書き: 同一セッションの前回 auto-checkpoint を削除して貯めない ===
# 実 store をモック（AI_CONTEXT_STORE_ROOT）し、fake claude が checkpoint を書く。
STORE7="$TMP/store7"; mkdir -p "$STORE7"
PH="$DIR/scripts/_ai-context-paths.sh"
SID7="s-autofire-7"
CWD7="$TMP/repo7"; mkdir -p "$CWD7"
WS_BASE7=$(env HOME="$FAKE_HOME" AI_CONTEXT_STORE_ROOT="$STORE7" sh "$PH" --resolve "$CWD7" 2>/dev/null)
if [ -n "$WS_BASE7" ]; then
    mkdir -p "$WS_BASE7/sessions"
    cat > "$FAKEBIN/claude-ck" <<'FAKECK'
#!/bin/sh
echo "$@" >> "$CLAUDE_CALL_LOG"
[ -n "$CHECKPOINT_TARGET" ] && printf '# Checkpoint\n' > "$CHECKPOINT_TARGET"
exit 0
FAKECK
    chmod +x "$FAKEBIN/claude-ck"
    LOG7="$TMP/claude-calls-7.log"; : > "$LOG7"
    CK_A="$WS_BASE7/sessions/checkpoint-2026-07-13-1200.md"
    CK_B="$WS_BASE7/sessions/checkpoint-2026-07-13-1210.md"
    env HOME="$FAKE_HOME" TMPDIR="$FAKE_TMP" AI_CONTEXT_STORE_ROOT="$STORE7" \
        CLAUDE_CALL_LOG="$LOG7" CHECKPOINT_TARGET="$CK_A" BANTO_CHECKPOINT_COOLDOWN_SEC=0 \
        sh "$AUTOFIRE" "$SID7" "$TRANSCRIPT" "$CWD7" "$FAKEBIN/claude-ck" idle >/dev/null 2>&1
    [ -f "$CK_A" ] && ok "7: fire-1 created checkpoint A" || bad "7: fire-1 did not create A"
    sleep 1  # CK_B の mtime を確実に CK_A より新しくして ls -t 順を確定させる
    env HOME="$FAKE_HOME" TMPDIR="$FAKE_TMP" AI_CONTEXT_STORE_ROOT="$STORE7" \
        CLAUDE_CALL_LOG="$LOG7" CHECKPOINT_TARGET="$CK_B" BANTO_CHECKPOINT_COOLDOWN_SEC=0 \
        sh "$AUTOFIRE" "$SID7" "$TRANSCRIPT" "$CWD7" "$FAKEBIN/claude-ck" idle >/dev/null 2>&1
    [ -f "$CK_B" ] && ok "7: fire-2 created checkpoint B" || bad "7: fire-2 did not create B"
    [ ! -f "$CK_A" ] && ok "7: fire-2 overwrote (deleted) prior auto-checkpoint A" || bad "7: prior auto-checkpoint A was not deleted"
else
    ok "7: SKIP (store base did not resolve in test env)"
fi

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
