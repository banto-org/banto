#!/bin/sh
# test-store-first-session.sh — 合成 HOME での session 一連テスト（store-first 受け入れ基準）
# 実 hook（session-start → auto(prompt) → stop）を合成 payload で通し、
#   基準 1: 未登録 repo（subdir 含む）で一連を実行しても repo 内に .ai-context/ が生成されない
#   基準 2: 未登録 repo は黙って作らず、対話ブートストラップを 1 回だけ促す（marker で 2 回目は静か）。
#           store 側にも一切登録・生成しない（A1）。
#   基準 3: 既存 legacy repo は読み取り互換のまま + 移行提案（/ai-context migrate）1 行（A2）
#   基準 4: dirname 衝突する 2 repo もどちらも黙って作らずクリーンのまま（A1）
#   基準 5: denylist / HOME / 非 git / subdir では store 側にも登録・生成されない
# を検証する。spec: 2026-06-24 store-bootstrap-search-routing-catalog-locked-spec（A1–A4）
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
SS="$DIR/hooks/ai-context-session-start.sh"
AUTO="$DIR/hooks/ai-context-auto.sh"
STOP="$DIR/hooks/ai-context-stop.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

# 隔離: 合成 HOME（denylist / store root / gh config が全て合成側に向く）+ 合成 TMPDIR（author cache）
unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_STORE_ROOT BANTO_IGNORE_FILE
TMP=$(mktemp -d "${TMPDIR:-/tmp}/store-first-session.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude" "$TMP/tmp"
STORE="$FAKE_HOME/ai-context-store"
MAP="$STORE/.mapping.json"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# 実 hook を合成 HOME で起動する（stdout を echo する）
run_hook() { # hookpath payload
    printf '%s' "$2" | HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" sh "$1" 2>/dev/null
}

# 合成 transcript（stop hook 用・決定キーワードなし）
TRANSCRIPT="$TMP/transcript.jsonl"
printf '{"type":"user","message":{"content":"hi"}}\n' > "$TRANSCRIPT"

repo_clean() { # repodir label
    if [ ! -e "$1/.ai-context" ] && [ ! -e "$1/.gitignore" ]; then ok "$2"; else bad "$2"; fi
}

# === 基準 1+2: 未登録 repo toplevel で session 一連（黙って作らず対話を促す） ===
R="$TMP/proj/myrepo"
mkdir -p "$R"
git -C "$R" init -q
OUT=$(run_hook "$SS" "{\"cwd\":\"$R\",\"source\":\"startup\"}")
case "$OUT" in
    *"ai-context ベース: $STORE/myrepo"*) ok "session-start: derive base injected (read path resolves into the store)" ;;
    *) bad "session-start: base injection missing" ;;
esac
case "$OUT" in
    *"store 未セットアップ"*) ok "criterion 2: bootstrap prompt emitted (not silent auto-create)" ;;
    *) bad "criterion 2: bootstrap prompt missing" ;;
esac
case "$OUT" in
    *"Registered this repo"*) bad "criterion 2: repo was silently auto-registered (should not be)" ;;
    *) ok "criterion 2: no silent registration notice" ;;
esac
[ ! -e "$STORE/myrepo" ] && ok "criterion 2: store dir NOT created for unregistered repo" || bad "criterion 2: store dir silently created"
[ ! -f "$MAP" ] && ok "criterion 2: mapping NOT created (no silent registration)" || bad "criterion 2: mapping silently created"
run_hook "$AUTO" "{\"cwd\":\"$R\",\"prompt\":\"design talk\",\"session_id\":\"s1\"}" >/dev/null
run_hook "$STOP" "{\"cwd\":\"$R\",\"transcript_path\":\"$TRANSCRIPT\"}" >/dev/null
repo_clean "$R" "criterion 1: repo stays clean after start->prompt->stop"
# marker gate: 2 回目はブートストラップ案内を出さない（毎回 nag しない）
OUT2=$(run_hook "$SS" "{\"cwd\":\"$R\",\"source\":\"startup\"}")
case "$OUT2" in
    *"store 未セットアップ"*) bad "criterion 2: bootstrap prompt re-emitted (marker did not gate)" ;;
    *) ok "criterion 2: second session does not re-prompt (marker gates)" ;;
esac
# marker は hook が解決する git toplevel（macOS では /private 実体パス）を slug 化する
R_TOP=$(git -C "$R" rev-parse --show-toplevel 2>/dev/null)
R_SLUG=$(printf '%s' "$R_TOP" | sed 's#[^A-Za-z0-9._-]#_#g')
[ -f "$FAKE_HOME/.claude/banto-bootstrap-asked/$R_SLUG" ] \
    && ok "criterion 2: bootstrap-asked marker written (user scope)" \
    || bad "criterion 2: bootstrap-asked marker missing"

# === 基準 1+5: 未登録 repo の subdir ===
R2="$TMP/proj2/subrepo"
mkdir -p "$R2/deep/inside"
git -C "$R2" init -q
OUT=$(run_hook "$SS" "{\"cwd\":\"$R2/deep/inside\",\"source\":\"startup\"}")
case "$OUT" in
    *"ai-context ベース: $STORE/subrepo"*) ok "subdir: derive base still injected (writes aim at the store)" ;;
    *) bad "subdir: derive base not injected" ;;
esac
run_hook "$AUTO" "{\"cwd\":\"$R2/deep/inside\",\"prompt\":\"hello\",\"session_id\":\"s2\"}" >/dev/null
run_hook "$STOP" "{\"cwd\":\"$R2/deep/inside\",\"transcript_path\":\"$TRANSCRIPT\"}" >/dev/null
repo_clean "$R2" "criterion 1: subdir session leaves repo clean"
repo_clean "$R2/deep/inside" "criterion 1: subdir itself stays clean"
[ ! -e "$STORE/subrepo" ] && ok "criterion 5: subdir does not register/create store side" || bad "criterion 5: subdir created store dir"

# === 基準 3: 既存 legacy repo は grandfather + 移行提案 1 行 ===
G="$TMP/leg"
mkdir -p "$G/.ai-context/decisions"
git -C "$G" init -q
OUT=$(run_hook "$SS" "{\"cwd\":\"$G\",\"source\":\"startup\"}")
case "$OUT" in
    *"/ai-context migrate"*) ok "criterion 3: migration proposal injected" ;;
    *) bad "criterion 3: migration proposal missing" ;;
esac
case "$OUT" in
    *"中央 store 運用"*) bad "criterion 3: legacy repo wrongly labeled central" ;;
    *) ok "criterion 3: no central wording for legacy repo" ;;
esac
[ ! -e "$STORE/leg" ] && ok "criterion 3: legacy repo not registered to store" || bad "criterion 3: legacy repo registered"

# === 基準 4: dirname 衝突する 2 repo もどちらも黙って作らずクリーンのまま（A1） ===
C1="$TMP/a/dup"; C2="$TMP/b/dup"
mkdir -p "$C1" "$C2"
git -C "$C1" init -q; git -C "$C2" init -q
OUTC1=$(run_hook "$SS" "{\"cwd\":\"$C1\",\"source\":\"startup\"}")
OUTC2=$(run_hook "$SS" "{\"cwd\":\"$C2\",\"source\":\"startup\"}")
case "$OUTC1$OUTC2" in
    *"store 未セットアップ"*) ok "criterion 4: colliding repos each get a bootstrap prompt" ;;
    *) bad "criterion 4: bootstrap prompt missing for colliding repos" ;;
esac
[ ! -e "$STORE/dup" ] && [ ! -e "$STORE/dup-2" ] \
    && ok "criterion 4: no store dirs auto-created for colliding repos" \
    || bad "criterion 4: store dirs silently created on collision"
repo_clean "$C1" "criterion 4: first colliding repo stays clean"
repo_clean "$C2" "criterion 4: second colliding repo stays clean"

# === 基準 5: denylist / HOME / 非 git ===
D="$TMP/denied"
mkdir -p "$D"
git -C "$D" init -q
printf '%s\n' "$D" > "$FAKE_HOME/.claude/banto-ignore"
OUT=$(run_hook "$SS" "{\"cwd\":\"$D\",\"source\":\"startup\"}")
[ -z "$OUT" ] && [ ! -e "$STORE/denied" ] && ok "criterion 5: denylist repo fully silent, no store side" || bad "criterion 5: denylist leaked"
OUT=$(run_hook "$SS" "{\"cwd\":\"$FAKE_HOME\",\"source\":\"startup\"}")
[ ! -e "$STORE/home" ] && [ ! -e "$FAKE_HOME/.ai-context" ] && ok "criterion 5: HOME cwd creates nothing" || bad "criterion 5: HOME cwd leaked"
P="$TMP/plaindir"
mkdir -p "$P"
run_hook "$SS" "{\"cwd\":\"$P\",\"source\":\"startup\"}" >/dev/null
[ ! -e "$P/.ai-context" ] && [ ! -e "$STORE/plaindir" ] && ok "criterion 5: non-git dir creates nothing" || bad "criterion 5: non-git leaked"

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
