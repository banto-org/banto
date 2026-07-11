#!/bin/sh
# test-idle-checkpoint-delivery.sh — idle-checkpoint の配送マトリクス（案 A′ + 有界化 + workspace 宛先）
# decision 2026-07-08 idle-checkpoint-delivery を合成 payload で検証する。
#   受け取り（消費）は source=clear のときだけ / resume/startup/compact は消費せずヒントのみ /
#   宛先は workspace キー（別 ws 宛ては配送しない） / 24h 超はヒント抑止 / 3 日超は GC で consumed/ へ。
# 実 hook（ai-context-session-start.sh）を合成 HOME + 合成 store root で通す。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
SS="$DIR/hooks/ai-context-session-start.sh"
PH="$DIR/scripts/_ai-context-paths.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }
[ -f "$SS" ] || { echo "SKIP: session-start hook not found"; exit 0; }

unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_LOCAL_ROOT AI_CONTEXT_LOCAL_MAPPING BANTO_IGNORE_FILE
TMP=$(mktemp -d "${TMPDIR:-/tmp}/idle-ck-delivery.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"; mkdir -p "$FAKE_HOME/.claude" "$TMP/tmp"
STORE="$TMP/store"
# author を "tester" に固定（gh api のネットワーク呼び出しを回避）
printf 'tester\n' > "$TMP/tmp/banto-ai-context-author-$(id -u 2>/dev/null || echo u)"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# 実 hook を合成環境で起動（stdout を echo）
run_ss() { # cwd source
    printf '%s' "{\"cwd\":\"$1\",\"source\":\"$2\",\"session_id\":\"t-$2\"}" \
        | HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" AI_CONTEXT_STORE_ROOT="$STORE" sh "$SS" 2>/dev/null
}
paths() { HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" AI_CONTEXT_STORE_ROOT="$STORE" sh "$PH" "$@" 2>/dev/null; }

# mtime を N 日前に設定（BSD/GNU 両対応）
set_days_ago() { # file days
    _ts=$(date -v-"$2"d +%Y%m%d%H%M 2>/dev/null || date -d "$2 days ago" +%Y%m%d%H%M 2>/dev/null)
    [ -n "$_ts" ] && touch -t "$_ts" "$1" 2>/dev/null
}

# --- リポジトリ用意 + 初回 hook で store 登録 ---
R="$TMP/myrepo"; mkdir -p "$R"
( cd "$R" && git init -q && git config user.name tester && git config user.email tester@example.com \
    && git commit -q --allow-empty -m init ) 2>/dev/null
run_ss "$R" startup >/dev/null 2>&1   # scaffold: base 解決を確定させる
BASE=$(paths --resolve "$R")
[ -n "$BASE" ] && [ -d "$BASE" ] || { echo "SKIP: base did not resolve ($BASE)"; exit 0; }
SESS="$BASE/sessions"; mkdir -p "$SESS"
# workspace pointer（git-dir に無いので $BASE/WORKSPACE.md にフォールバックする）
printf '# Workspace: [test] alpha\n' > "$BASE/WORKSPACE.md"
[ "$(paths --ws-key "$R")" = "[test] alpha" ] \
    && ok "ws-key resolves to the pointer topic" \
    || bad "ws-key mismatch (got '$(paths --ws-key "$R")')"

reset_ck() { rm -f "$SESS"/checkpoint-*.md; rm -rf "$SESS/consumed"; }
# 「N 日前」の checkpoint を実運用と同形式（checkpoint-<YYYY-MM-DD-HHMM>-<seq>.md）で作り、パスを echo。
# ファイル名の日付は date で動的生成し、set_days_ago が設定する実 mtime と常に一致させる（ハードコード
# 日付を排除。reader はファイル名の日付を parse せず glob + mtime だけを見るため、名前は age のラベル）。
# days=0 で fresh（mtime=現在）。seq 連番で同一分内の衝突を防ぐ。
_ck_seq=0
mk_ck() { # days  [marker-line]  → echoes the created path
    _ck_seq=$((_ck_seq + 1))
    _d=${1:-0}
    _stamp=$(date -v-"$_d"d +%Y-%m-%d-%H%M 2>/dev/null || date -d "$_d days ago" +%Y-%m-%d-%H%M 2>/dev/null)
    [ -z "$_stamp" ] && _stamp="1970-01-01-0000"
    _f="$SESS/checkpoint-$_stamp-$_ck_seq.md"
    { [ -n "${2:-}" ] && printf '%s\n' "$2"; printf '# Checkpoint - test\n\ncontent\n'; } > "$_f"
    [ "$_d" != "0" ] && set_days_ago "$_f" "$_d"
    printf '%s\n' "$_f"
}
consumed_path() { echo "$SESS/consumed/tester/$(basename "$1")"; }

# === A: startup + fresh + 未マーカー → 消費しない・ヒント出る ===
reset_ck; F=$(mk_ck 0)
OUT=$(run_ss "$R" startup)
case "$OUT" in *"=== Checkpoint (user-confirmed) ==="*) bad "A: startup injected full checkpoint (should not)";; *) ok "A: startup does not inject full checkpoint";; esac
case "$OUT" in *"idle-checkpoint あり"*) ok "A: startup shows the /clear hint";; *) bad "A: startup missing hint";; esac
[ -f "$F" ] && ok "A: startup preserves the checkpoint (not consumed)" || bad "A: startup consumed the checkpoint"

# === B: clear + fresh + 未マーカー → 全文注入・consumed へ退避 ===
reset_ck; F=$(mk_ck 0)
OUT=$(run_ss "$R" clear)
case "$OUT" in *"=== Checkpoint (user-confirmed) ==="*) ok "B: clear injects the checkpoint";; *) bad "B: clear did not inject";; esac
[ ! -f "$F" ] && ok "B: clear removed it from the mailbox" || bad "B: clear left it in the mailbox"
[ -f "$(consumed_path "$F")" ] && ok "B: clear moved it to consumed/<author>" || bad "B: clear did not archive to consumed"

# === C: clear + 別 ws 宛て → 配送しない・消費しない ===
reset_ck; F=$(mk_ck 0 "<!-- banto-ws: [test] beta -->")
OUT=$(run_ss "$R" clear)
case "$OUT" in *"=== Checkpoint (user-confirmed) ==="*) bad "C: clear injected a foreign-ws checkpoint";; *) ok "C: clear does not inject a foreign-ws checkpoint";; esac
[ -f "$F" ] && ok "C: foreign-ws checkpoint preserved (not consumed)" || bad "C: foreign-ws checkpoint was consumed"

# === C2: clear + 自 ws 宛てマーカー → 配送する ===
reset_ck; F=$(mk_ck 0 "<!-- banto-ws: [test] alpha -->")
OUT=$(run_ss "$R" clear)
case "$OUT" in *"=== Checkpoint (user-confirmed) ==="*) ok "C2: clear injects an own-ws marked checkpoint";; *) bad "C2: clear did not inject own-ws checkpoint";; esac
[ ! -f "$F" ] && ok "C2: own-ws checkpoint consumed" || bad "C2: own-ws checkpoint not consumed"

# === D: startup + 2 日前（>24h, < 保持窓）→ ヒント抑止・保存は維持 ===
reset_ck; F=$(mk_ck 2)
OUT=$(run_ss "$R" startup)
case "$OUT" in *"idle-checkpoint あり"*) bad "D: stale (2d) checkpoint still shows hint";; *) ok "D: stale (2d) checkpoint suppresses the hint (>24h)";; esac
[ -f "$F" ] && ok "D: 2d checkpoint preserved (< retain window)" || bad "D: 2d checkpoint wrongly GC'd"

# === D2: startup + 6 日前（旧 3 日窓なら消えていた・新 10 日窓では維持）→ 保存維持 ===
reset_ck; F=$(mk_ck 6)
run_ss "$R" startup >/dev/null 2>&1
[ -f "$F" ] && ok "D2: 6d checkpoint preserved (retain window is 10d, not 3d)" || bad "D2: 6d checkpoint GC'd too early"

# === D3: 保持日数を env で 3 日に縮めると 6 日前は GC される（調整可の実証） ===
reset_ck; F=$(mk_ck 6)
printf '%s' "{\"cwd\":\"$R\",\"source\":\"startup\",\"session_id\":\"t-env\"}" \
    | HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" AI_CONTEXT_STORE_ROOT="$STORE" BANTO_IDLE_CHECKPOINT_RETAIN_DAYS=3 sh "$SS" >/dev/null 2>&1
[ ! -f "$F" ] && ok "D3: RETAIN_DAYS=3 GC's the 6d checkpoint (env-tunable)" || bad "D3: RETAIN_DAYS env not honored"

# === E: startup + 12 日前（> 保持窓）→ GC で consumed/ へ退避 ===
reset_ck; F=$(mk_ck 12)
OUT=$(run_ss "$R" startup)
[ ! -f "$F" ] && ok "E: >10d checkpoint GC'd out of the mailbox" || bad "E: >10d checkpoint not GC'd"
[ -f "$(consumed_path "$F")" ] && ok "E: >10d checkpoint archived to consumed/" || bad "E: >10d checkpoint not archived"

echo
[ "$fail" = "0" ] && { echo "ALL OK (test-idle-checkpoint-delivery)"; exit 0; } || { echo "FAILURES (test-idle-checkpoint-delivery)"; exit 1; }
