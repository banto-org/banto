#!/bin/sh
# test-store-first-session.sh — 合成 HOME での session 一連テスト（store-first 受け入れ基準）
# 実 hook（session-start → auto(prompt) → stop）を合成 payload で通し、
#   基準 1: 未登録 repo（subdir 含む）で一連を実行しても repo 内に .ai-context/ が生成されない
#   基準 2: 未登録 repo は **ブロックせず** ~/ai-context-local/<project>/ を作成・登録(local:false)し、
#           1 行通知する（marker で 2 回目は静か）。central store には一切登録・生成しない。
#           （spec 2026-06-24 ai-context-subsystem-redesign が旧 A1「prompt-only」を上書き。）
#   基準 3: 既存 legacy repo は読み取り互換のまま + 移行提案（/ai-context migrate）1 行
#   基準 4: dirname 衝突する 2 repo も決定論 suffix で別々の local store dir（衝突しない）
#   基準 5: denylist / HOME / 非 git / subdir では central にも local にも登録・生成されない
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
SS="$DIR/hooks/ai-context-session-start.sh"
AUTO="$DIR/hooks/ai-context-auto.sh"
STOP="$DIR/hooks/ai-context-stop.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

# 隔離: 合成 HOME（denylist / store root / gh config）+ 合成 TMPDIR（author cache）+ 合成 local store root
unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_STORE_ROOT BANTO_IGNORE_FILE \
      AI_CONTEXT_LOCAL_ROOT AI_CONTEXT_LOCAL_MAPPING
TMP=$(mktemp -d "${TMPDIR:-/tmp}/store-first-session.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude" "$TMP/tmp"
STORE="$FAKE_HOME/ai-context-store"        # central store (must stay empty for unregistered repos)
LOCAL_STORE="$FAKE_HOME/ai-context-local"  # non-blocking temp store (unregistered repos land here)
CMAP="$STORE/.mapping.json"
LMAP="$LOCAL_STORE/.mapping.json"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# 実 hook を合成 HOME で起動する（stdout を echo する）。local store root も合成側に向ける。
run_hook() { # hookpath payload
    printf '%s' "$2" | HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" \
        AI_CONTEXT_LOCAL_ROOT="$LOCAL_STORE" sh "$1" 2>/dev/null
}

# 合成 transcript（stop hook 用・決定キーワードなし）
TRANSCRIPT="$TMP/transcript.jsonl"
printf '{"type":"user","message":{"content":"hi"}}\n' > "$TRANSCRIPT"

repo_clean() { # repodir label
    if [ ! -e "$1/.ai-context" ] && [ ! -e "$1/.gitignore" ]; then ok "$2"; else bad "$2"; fi
}

# === 基準 1+2: 未登録 repo toplevel で session 一連（ブロックせず仮ローカルを作成・通知） ===
R="$TMP/proj/myrepo"
mkdir -p "$R"
git -C "$R" init -q
OUT=$(run_hook "$SS" "{\"cwd\":\"$R\",\"source\":\"startup\"}")
case "$OUT" in
    *"ai-context ベース: $LOCAL_STORE/myrepo"*) ok "session-start: base resolves into the local store after scaffold" ;;
    *) bad "session-start: local-store base injection missing" ;;
esac
case "$OUT" in
    *"temporary local store"*) ok "criterion 2: one-line local-store notice emitted (non-blocking)" ;;
    *) bad "criterion 2: local-store notice missing" ;;
esac
[ -d "$LOCAL_STORE/myrepo/decisions" ] && ok "criterion 2: local store skeleton created" || bad "criterion 2: local store skeleton missing"
[ -d "$LOCAL_STORE/myrepo/learnings" ] && [ -d "$LOCAL_STORE/myrepo/meta" ] && ok "criterion 2: learnings/ + meta/ scope present" || bad "criterion 2: learnings/meta scope missing"
[ "$(jq -r '.projects[].local' "$LMAP" 2>/dev/null)" = "false" ] && ok "criterion 2: registered local:false (pending bootstrap)" || bad "criterion 2: local mapping not local:false"
[ ! -e "$STORE/myrepo" ] && ok "criterion 2: central store dir NOT created (defers to bootstrap)" || bad "criterion 2: central store dir silently created"
[ ! -f "$CMAP" ] && ok "criterion 2: central mapping NOT created" || bad "criterion 2: central mapping silently created"
run_hook "$AUTO" "{\"cwd\":\"$R\",\"prompt\":\"design talk\",\"session_id\":\"s1\"}" >/dev/null
run_hook "$STOP" "{\"cwd\":\"$R\",\"transcript_path\":\"$TRANSCRIPT\"}" >/dev/null
repo_clean "$R" "criterion 1: repo stays clean after start->prompt->stop"
# marker gate: 2 回目は通知を出さない（毎回 nag しない）
OUT2=$(run_hook "$SS" "{\"cwd\":\"$R\",\"source\":\"startup\"}")
case "$OUT2" in
    *"temporary local store"*) bad "criterion 2: notice re-emitted (marker did not gate)" ;;
    *) ok "criterion 2: second session does not re-notice (marker gates)" ;;
esac
# marker は hook が解決する git toplevel（macOS では /private 実体パス）を slug 化する
R_TOP=$(git -C "$R" rev-parse --show-toplevel 2>/dev/null)
R_SLUG=$(printf '%s' "$R_TOP" | sed 's#[^A-Za-z0-9._-]#_#g')
[ -f "$FAKE_HOME/.claude/banto-bootstrap-asked/$R_SLUG" ] \
    && ok "criterion 2: bootstrap-asked marker written (user scope)" \
    || bad "criterion 2: bootstrap-asked marker missing"

# === 基準 1+5: 未登録 repo の subdir → toplevel でないので何も作らない（注入は続く） ===
R2="$TMP/proj2/subrepo"
mkdir -p "$R2/deep/inside"
git -C "$R2" init -q
OUT=$(run_hook "$SS" "{\"cwd\":\"$R2/deep/inside\",\"source\":\"startup\"}")
case "$OUT" in
    *"ai-context ベース: $STORE/subrepo"*) ok "subdir: derive base still injected (toplevel not scaffolded from subdir)" ;;
    *) bad "subdir: derive base not injected" ;;
esac
run_hook "$AUTO" "{\"cwd\":\"$R2/deep/inside\",\"prompt\":\"hello\",\"session_id\":\"s2\"}" >/dev/null
run_hook "$STOP" "{\"cwd\":\"$R2/deep/inside\",\"transcript_path\":\"$TRANSCRIPT\"}" >/dev/null
repo_clean "$R2" "criterion 1: subdir session leaves repo clean"
repo_clean "$R2/deep/inside" "criterion 1: subdir itself stays clean"
[ ! -e "$STORE/subrepo" ] && [ ! -e "$LOCAL_STORE/subrepo" ] && ok "criterion 5: subdir does not register/create either store" || bad "criterion 5: subdir created a store dir"

# === 基準 3: in-repo .ai-context は廃止（2026-07-08）→ その場読みをやめ store へ自動移行（非破壊）+ 登録 ===
G="$TMP/leg"
mkdir -p "$G/.ai-context/decisions"
printf '# legacy\n' > "$G/.ai-context/decisions/legacy-note.md"
git -C "$G" init -q
OUT=$(run_hook "$SS" "{\"cwd\":\"$G\",\"source\":\"startup\"}")
case "$OUT" in
    *"Migrated in-repo .ai-context"*) ok "criterion 3: legacy .ai-context auto-migrated (notice injected)" ;;
    *) bad "criterion 3: migration notice missing" ;;
esac
GTOP=$(git -C "$G" rev-parse --show-toplevel)
GPROJ=$(jq -r --arg t "$GTOP" '.projects[$t].project // empty' "$LMAP" 2>/dev/null)
{ [ -n "$GPROJ" ] && [ -f "$LOCAL_STORE/$GPROJ/decisions/legacy-note.md" ]; } && ok "criterion 3: in-repo decision migrated into the local store" || bad "criterion 3: content not migrated (proj=$GPROJ)"
[ -d "$G/.ai-context" ] && ok "criterion 3: in-repo .ai-context kept intact (non-destructive)" || bad "criterion 3: in-repo .ai-context removed"

# === 基準 4: dirname 衝突する 2 repo → 決定論 suffix で別々の local store dir ===
C1="$TMP/a/dup"; C2="$TMP/b/dup"
mkdir -p "$C1" "$C2"
git -C "$C1" init -q; git -C "$C2" init -q
run_hook "$SS" "{\"cwd\":\"$C1\",\"source\":\"startup\"}" >/dev/null
run_hook "$SS" "{\"cwd\":\"$C2\",\"source\":\"startup\"}" >/dev/null
[ -d "$LOCAL_STORE/dup" ] && [ -d "$LOCAL_STORE/dup-2" ] \
    && ok "criterion 4: colliding repos derive dup and dup-2 in the local store" \
    || bad "criterion 4: collision suffix not applied in the local store"
[ ! -e "$STORE/dup" ] && [ ! -e "$STORE/dup-2" ] && ok "criterion 4: no central store dirs for colliding repos" || bad "criterion 4: central store dirs created"
repo_clean "$C1" "criterion 4: first colliding repo stays clean"
repo_clean "$C2" "criterion 4: second colliding repo stays clean"

# === 基準 5: denylist / HOME / 非 git ===
D="$TMP/denied"
mkdir -p "$D"
git -C "$D" init -q
printf '%s\n' "$D" > "$FAKE_HOME/.claude/banto-ignore"
OUT=$(run_hook "$SS" "{\"cwd\":\"$D\",\"source\":\"startup\"}")
[ -z "$OUT" ] && [ ! -e "$STORE/denied" ] && [ ! -e "$LOCAL_STORE/denied" ] && ok "criterion 5: denylist repo fully silent, no store side" || bad "criterion 5: denylist leaked"
OUT=$(run_hook "$SS" "{\"cwd\":\"$FAKE_HOME\",\"source\":\"startup\"}")
[ ! -e "$STORE/home" ] && [ ! -e "$LOCAL_STORE/home" ] && [ ! -e "$FAKE_HOME/.ai-context" ] && ok "criterion 5: HOME cwd creates nothing" || bad "criterion 5: HOME cwd leaked"
P="$TMP/plaindir"
mkdir -p "$P"
run_hook "$SS" "{\"cwd\":\"$P\",\"source\":\"startup\"}" >/dev/null
[ ! -e "$P/.ai-context" ] && [ ! -e "$STORE/plaindir" ] && [ ! -e "$LOCAL_STORE/plaindir" ] && ok "criterion 5: non-git dir creates nothing" || bad "criterion 5: non-git leaked"

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
