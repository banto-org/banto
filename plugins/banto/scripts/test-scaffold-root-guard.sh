#!/bin/sh
# test-scaffold-root-guard.sh — store ブートストラップの検証
# spec 2026-06-24 ai-context-subsystem-redesign: 未登録 repo では **ブロックせず** 仮ローカル store
# (~/ai-context-local/<project>/) を作成・登録(local:false)して 1 行通知する（A1 の prompt-only を上書き）。
# 登録済み(central / local-store)は skeleton を冪等確保。repo 側には一切書かない。grandfather 維持。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
# 実 plugin cache / 実 store に触れない（テスト決定論）
unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_STORE_ROOT AI_CONTEXT_LOCAL_ROOT AI_CONTEXT_LOCAL_MAPPING
. "$DIR/hooks/_ai-context-scaffold.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/scaffold-guard-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# 実環境を汚さないよう隔離: HOME（notice marker = ~/.claude/banto-bootstrap-asked）/ central store root /
# local store root / denylist をすべて TMP 配下へ。
HOME="$TMP/home"; mkdir -p "$HOME/.claude"
BANTO_IGNORE_FILE="$TMP/empty-ignore"; touch "$BANTO_IGNORE_FILE"
AI_CONTEXT_STORE_ROOT="$TMP/store"
AI_CONTEXT_LOCAL_ROOT="$TMP/local"
export HOME BANTO_IGNORE_FILE AI_CONTEXT_STORE_ROOT AI_CONTEXT_LOCAL_ROOT
CMAP="$TMP/store/.mapping.json"     # central mapping (should stay empty for unregistered repos)
LMAP="$TMP/local/.mapping.json"     # local store mapping (where unregistered repos land)

# === case 1: 未登録 git repo → 非ブロッキングで ai-context-local に作成・登録 + repo はクリーン ===
R="$TMP/repo"
mkdir -p "$R"; git -C "$R" init -q
OUT1=$(_ai_context_scaffold "$R")
[ ! -e "$R/.ai-context" ]  && ok "unregistered: no local .ai-context in repo"  || bad "unregistered: local .ai-context created"
[ ! -e "$R/.gitignore" ]   && ok "unregistered: no local .gitignore in repo"   || bad "unregistered: local .gitignore created"
[ -d "$TMP/local/repo/decisions" ] && ok "unregistered: ai-context-local skeleton created" || bad "unregistered: ai-context-local skeleton missing"
[ -f "$TMP/local/.ai-context-local" ] && ok "unregistered: ai-context-local marker created" || bad "unregistered: ai-context-local marker missing"
[ ! -d "$TMP/store/repo" ] && ok "unregistered: no central store dir (defers to bootstrap)" || bad "unregistered: central store dir created"
[ ! -f "$CMAP" ]           && ok "unregistered: no central mapping registration"  || bad "unregistered: central mapping created"
[ "$(jq '.projects | length' "$LMAP" 2>/dev/null)" = "1" ] && ok "unregistered: registered in local mapping" || bad "unregistered: local mapping not registered"
[ "$(jq -r '.projects[].local' "$LMAP" 2>/dev/null)" = "false" ] && ok "unregistered: local:false (pending bootstrap)" || bad "unregistered: local flag not false"
printf '%s' "$OUT1" | grep -q 'temporary local store' && ok "unregistered: one-line notice emitted" || bad "unregistered: notice missing"
printf '%s' "$OUT1" | grep -q '/ai-context bootstrap' && ok "unregistered: notice points at bootstrap" || bad "unregistered: bootstrap hint missing"

# === case 1b: learnings/ と meta/ が skeleton に含まれる（spec の新 scope） ===
[ -d "$TMP/local/repo/learnings" ] && ok "skeleton: learnings/ created" || bad "skeleton: learnings/ missing"
[ -d "$TMP/local/repo/meta" ]      && ok "skeleton: meta/ created"      || bad "skeleton: meta/ missing"

# === case 2: repo のサブディレクトリ → toplevel でないので何もしない ===
S="$R/sub/dir"; mkdir -p "$S"
BEFORE=$(jq '.projects | length' "$LMAP")
_ai_context_scaffold "$S" >/dev/null
[ ! -e "$S/.ai-context" ] && ok "subdir: no local .ai-context" || bad "subdir: .ai-context created"
[ "$(jq '.projects | length' "$LMAP")" = "$BEFORE" ] && ok "subdir: no new registration" || bad "subdir: registration leaked"

# === case 3: 非 git dir → skip（どちら側にも生成されない） ===
N="$TMP/plain"; mkdir -p "$N"
_ai_context_scaffold "$N" >/dev/null
[ ! -e "$N/.ai-context" ]   && ok "non-git: no local .ai-context" || bad "non-git: .ai-context created"
[ ! -e "$TMP/local/plain" ] && ok "non-git: no local store dir"   || bad "non-git: local store dir created"

# === case 4: should_skip はサブディレクトリを素通り（hook 注入系は止めない＝責務分離） ===
if _ai_context_should_skip "$S"; then
    bad "should_skip: subdir unexpectedly skipped (workspace injection would die)"
else
    ok "should_skip: subdir still passes (hook keeps running, only scaffold is gated)"
fi

# === case 5: notice は 1 回だけ — 2 回目は marker が立っており無言（仮ローカルは冪等確保） ===
OUT5=$(_ai_context_scaffold "$R")
[ -z "$OUT5" ] && ok "once-only: second run silent (asked-marker gates the notice)" || bad "once-only: second run re-emitted"
[ "$(jq '.projects | length' "$LMAP")" = "1" ] && ok "once-only: still single registration (idempotent)" || bad "once-only: duplicate registration"

# === case 6: 登録済み(local-store) → resolver/local-lookup hit で skeleton を冪等確保（無言） ===
OUT6=$(_ai_context_scaffold "$R")
[ -z "$OUT6" ] && ok "registered(local): idempotent, silent" || bad "registered(local): emitted output"

# === case 7: dirname 衝突（別パスの同名 repo）→ 決定論 suffix で別 project dir ===
R2="$TMP/other/repo"; mkdir -p "$R2"; git -C "$R2" init -q
( _ai_context_scaffold "$R2" ) >/dev/null
[ -d "$TMP/local/repo-2/decisions" ] && ok "collision: second 'repo' derives repo-2 locally" || bad "collision: suffix not applied"
B1=$(sh "$DIR/scripts/_ai-context-paths.sh" --resolve "$R")
B2=$(sh "$DIR/scripts/_ai-context-paths.sh" --resolve "$R2")
[ "$B1" != "$B2" ] && ok "collision: two repos resolve to distinct dirs" || bad "collision: same dir ($B1)"
case "$B1" in "$TMP/local/"*) ok "collision: first repo resolves into the local store" ;; *) bad "collision: first repo not local ($B1)" ;; esac

# === case 8: grandfather — 既存の repo 内 .ai-context は触らず local/central 登録もしない ===
G="$TMP/leg"; mkdir -p "$G/.ai-context/decisions"; git -C "$G" init -q
BEFORE=$(jq '.projects | length' "$LMAP")
_ai_context_scaffold "$G" >/dev/null
[ "$(jq '.projects | length' "$LMAP")" = "$BEFORE" ] && ok "grandfather: no local registration" || bad "grandfather: registered locally"
[ ! -e "$TMP/local/leg" ] && ok "grandfather: no local store dir" || bad "grandfather: local store dir created"
[ ! -e "$TMP/store/leg" ] && ok "grandfather: no central store dir" || bad "grandfather: central store dir created"

# === case 9: local 固定（/ai-context local 相当）→ mapping local:true・bootstrap でスキップ ===
RL="$TMP/pinned/repo"; mkdir -p "$RL"; git -C "$RL" init -q
PIN_OUT=$(sh "$DIR/scripts/ai-context-store-init.sh" local --cwd "$RL" 2>&1)
PIN_TOP=$(git -C "$RL" rev-parse --show-toplevel)
[ "$(jq -r --arg t "$PIN_TOP" '.projects[$t].local' "$LMAP" 2>/dev/null)" = "true" ] \
    && ok "local-pin: mapping local:true set" || bad "local-pin: local:true not set (out: $PIN_OUT)"
( . "$DIR/scripts/_ai-context-paths.sh"; _ai_context_is_local_pinned "$PIN_TOP" ) \
    && ok "local-pin: is_local_pinned predicate true" || bad "local-pin: predicate false"

# === case 10: bootstrap 移行 ai-context-local → central store（additive・上書きしない） ===
# 隔離 central store を gh 無しで使うため、既存 local clone（commit 済 + ローカル bare origin）を用意。
if command -v gh >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    BREPO="$TMP/bootstrap/myproj"; mkdir -p "$BREPO"; git -C "$BREPO" init -q
    BTOP=$(git -C "$BREPO" rev-parse --show-toplevel)
    # 1) 仮ローカル store にコンテンツを置く（未登録 → scaffold で local 登録）
    _ai_context_scaffold "$BREPO" >/dev/null
    BPROJ=$(jq -r --arg t "$BTOP" '.projects[$t].project' "$LMAP")
    printf 'local decision\n' > "$TMP/local/$BPROJ/decisions/d1.md"
    printf 'shared note\n'    > "$TMP/local/$BPROJ/docs/note.md"
    # 2) 隔離 central store（既に local clone 済み・ローカル bare origin で push がネットに出ない）
    CLOCAL="$TMP/central-clone"
    BARE="$TMP/central-bare.git"; git init -q --bare "$BARE"
    git clone -q "$BARE" "$CLOCAL" 2>/dev/null
    ( cd "$CLOCAL"
      git config user.email t@e; git config user.name t
      touch .ai-context-store; printf '# store\n' > README.md
      # 衝突ファイル: central 側に既存の d1.md（上書きしてはいけない）
      mkdir -p "$BPROJ/decisions"; printf 'CENTRAL ORIGINAL — must NOT be overwritten\n' > "$BPROJ/decisions/d1.md"
      git add -A; git commit -q -m init; git branch -M main 2>/dev/null; git push -q -u origin main 2>/dev/null )
    # org は user-scope conf 経由で渡す（env override は設計上クロバーされる）。
    printf 'AI_CONTEXT_STORE_ORG="dummy-org"\n' > "$HOME/.claude/banto-store-target.conf"
    # 3) bootstrap 実行（AI_CONTEXT_STORE_LOCAL=隔離 clone, central mapping は clone 配下）
    BOUT=$(HOME="$HOME" \
        AI_CONTEXT_STORE_LOCAL="$CLOCAL" \
        AI_CONTEXT_MAPPING="$CLOCAL/.mapping.json" \
        AI_CONTEXT_LOCAL_ROOT="$TMP/local" AI_CONTEXT_LOCAL_MAPPING="$LMAP" \
        BANTO_STORES_LIST="$TMP/stores-list" \
        sh "$DIR/scripts/ai-context-store-init.sh" bootstrap --cwd "$BREPO" 2>&1)
    # 衝突しない note.md は central に移行される
    [ -f "$CLOCAL/$BPROJ/docs/note.md" ] && ok "bootstrap: non-conflicting file migrated to central" || bad "bootstrap: note.md not migrated (out: $BOUT)"
    # 衝突する d1.md は central 原本のまま（上書きされない）
    grep -q 'CENTRAL ORIGINAL' "$CLOCAL/$BPROJ/decisions/d1.md" 2>/dev/null \
        && ok "bootstrap: conflicting file NOT overwritten (central original kept)" || bad "bootstrap: central file was overwritten"
    # 衝突は両方に残る（local 原本は消されない）
    grep -q 'local decision' "$TMP/local/$BPROJ/decisions/d1.md" 2>/dev/null \
        && ok "bootstrap: conflicting source left in BOTH (local kept)" || bad "bootstrap: local source removed on conflict"
    printf '%s' "$BOUT" | grep -qi 'conflict' && ok "bootstrap: conflict reported to user" || bad "bootstrap: conflict not reported"
    # central mapping に登録され、local mapping から外れる
    [ "$(jq -r --arg t "$BTOP" '.projects[$t].project // empty' "$CLOCAL/.mapping.json" 2>/dev/null)" = "$BPROJ" ] \
        && ok "bootstrap: registered in central mapping" || bad "bootstrap: central mapping not updated"
    [ -z "$(jq -r --arg t "$BTOP" '.projects[$t] // empty' "$LMAP" 2>/dev/null)" ] \
        && ok "bootstrap: local mapping entry removed" || bad "bootstrap: local mapping entry not removed"
else
    ok "bootstrap: SKIP (gh/git not available) — migration case skipped"
fi

# === case 11: BANTO_AI_CONTEXT_CENTRAL_ONLY は no-op（読み捨て）— 未登録なら従来どおり仮ローカル ===
R3="$TMP/co/repo3"; mkdir -p "$R3"; git -C "$R3" init -q
BANTO_AI_CONTEXT_CENTRAL_ONLY=1 _ai_context_scaffold "$R3" >/dev/null
[ ! -e "$TMP/store/repo3" ] && ok "CENTRAL_ONLY: no-op (no central dir for unregistered)" || bad "CENTRAL_ONLY: created central dir"
[ -d "$TMP/local/repo3" ] && ok "CENTRAL_ONLY: unregistered still lands in local store" || bad "CENTRAL_ONLY: local store dir missing"

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
