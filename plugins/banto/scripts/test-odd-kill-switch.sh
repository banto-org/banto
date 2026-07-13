#!/bin/sh
# test-odd-kill-switch.sh — odd-kill-switch.sh の合成 payload テスト
# 対象: 4 ルール（main push / --no-verify / --force push / rm -rf root）の
#   block 正例・通過負例・escape ハッチ・store marker 例外・過去に実在した bypass 形
#   （複合コマンド + エスケープ引用符 / git -C / 引数中の push 文字列）。
# 経緯: 2026-06-12 監査 H-11（バイパス前科ありの安全コアがテスト 1 ケースのみだった）
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$DIR/../hooks/odd-kill-switch.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/odd-ks-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

run_hook() {  # $1=command → exit code
    printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
        "$(printf '%s' "$1" | jq -Rs .)" \
        | sh "$HOOK" >/dev/null 2>&1
}

STORE="$TMP/store"
mkdir -p "$STORE" && touch "$STORE/.ai-context-store"
NOSTORE="$TMP/plain"
mkdir -p "$NOSTORE"

# === ルール 1: main/master push ===
run_hook 'git push origin main'; [ $? -eq 2 ] \
    && ok "R1: push origin main blocked" || bad "R1: push origin main not blocked"
run_hook 'git push origin master'; [ $? -eq 2 ] \
    && ok "R1: push origin master blocked" || bad "R1: push origin master not blocked"
run_hook 'git push origin feature/x'; [ $? -eq 0 ] \
    && ok "R1: push feature branch passes" || bad "R1: feature push blocked"
# 過去の実 bypass 形: エスケープ引用符入り複合コマンド（grep fallback が途中切断していた）
run_hook 'git commit -m "fix: \"quoted\" msg" && git push origin main'; [ $? -eq 2 ] \
    && ok "R1: compound cmd with escaped quotes blocked (historic bypass)" || bad "R1: historic bypass form passes"
# git -C 形
run_hook "git -C $NOSTORE push origin main"; [ $? -eq 2 ] \
    && ok "R1: git -C <dir> push origin main blocked" || bad "R1: git -C form not blocked"
# 引数中の push 文字列での誤発火（負例）
run_hook 'git log --grep=push --force'; [ $? -eq 0 ] \
    && ok "R1: 'push' inside args does not false-positive" || bad "R1: false positive on args"
# store marker 例外
run_hook "git -C $STORE push origin main"; [ $? -eq 0 ] \
    && ok "R1: store (marker) main push passes" || bad "R1: store main push blocked"
# escape
ODD_ALLOW_MAIN_PUSH=1 sh -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push origin main\"}}' | sh '$HOOK' >/dev/null 2>&1"; [ $? -eq 0 ] \
    && ok "R1: ODD_ALLOW_MAIN_PUSH=1 escape works" || bad "R1: escape broken"

# === ルール 2: --no-verify ===
run_hook 'git commit --no-verify -m x'; [ $? -eq 2 ] \
    && ok "R2: --no-verify blocked" || bad "R2: --no-verify not blocked"
# 引数文字列に --no-verify が現れるケースはセグメント判定の既知の限界。
# 安全側（block / exit 2）に倒れるのが現仕様なので、それを実アサーションとして固定する。
run_hook 'git commit -m "use --no-verify never"'; [ $? -eq 2 ] \
    && ok "R2: --no-verify inside message blocks (safe-side, known segment limit)" || bad "R2: --no-verify inside message did not block (safe-side regression)"
ODD_ALLOW_NO_VERIFY=1 sh -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit --no-verify -m x\"}}' | sh '$HOOK' >/dev/null 2>&1"; [ $? -eq 0 ] \
    && ok "R2: ODD_ALLOW_NO_VERIFY=1 escape works" || bad "R2: escape broken"

# === ルール 2b: --force push ===
run_hook 'git push --force origin feature/x'; [ $? -eq 2 ] \
    && ok "R3: push --force blocked" || bad "R3: push --force not blocked"
run_hook 'git push --force-with-lease origin feature/x'; [ $? -eq 0 ] \
    && ok "R3: --force-with-lease passes (negative)" || bad "R3: --force-with-lease blocked"
run_hook 'git worktree remove --force wt'; [ $? -eq 0 ] \
    && ok "R3: non-push --force passes (worktree remove)" || bad "R3: worktree --force blocked"
run_hook 'docker build -f Dockerfile . && git push origin feature/x'; [ $? -eq 0 ] \
    && ok "R3: -f of another command not misread (historic FP)" || bad "R3: docker -f false positive"
ODD_ALLOW_FORCE_PUSH=1 sh -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push --force origin feature/x\"}}' | sh '$HOOK' >/dev/null 2>&1"; [ $? -eq 0 ] \
    && ok "R3: ODD_ALLOW_FORCE_PUSH=1 escape works" || bad "R3: escape broken"

# === ルール 4: rm -rf root/home ===
run_hook 'rm -rf /'; [ $? -eq 2 ] \
    && ok "R4: rm -rf / blocked" || bad "R4: rm -rf / not blocked"
run_hook 'rm -rf ./build'; [ $? -eq 0 ] \
    && ok "R4: rm -rf ./build passes" || bad "R4: relative rm blocked"
# 引用符・分割フラグの回避形（2026-07-02 監査で封鎖）
run_hook 'rm -rf "/"'; [ $? -eq 2 ] \
    && ok "R4: quoted root blocked (historic bypass)" || bad "R4: quoted root passes"
run_hook 'rm -r -f /'; [ $? -eq 2 ] \
    && ok "R4: split flags blocked (historic bypass)" || bad "R4: split flags pass"
run_hook 'rm -rf ~'; [ $? -eq 2 ] \
    && ok "R4: rm -rf ~ blocked" || bad "R4: rm -rf ~ not blocked"
run_hook 'rm -r -f ./build'; [ $? -eq 0 ] \
    && ok "R4: split flags on relative path pass (negative)" || bad "R4: relative split flags blocked"

# === ルール 5: rm が git 管理下ファイルを対象（warn only, no block） ===
run_hook_cwd() {  # $1=command $2=cwd → stdout=stderr, exit code は $? に残る
    printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":%s}' \
        "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" \
        | sh "$HOOK" 2>&1 >/dev/null
}
RM_REPO="$TMP/rm-repo"
git init -q -b main "$RM_REPO"
printf 'x' > "$RM_REPO/tracked.txt"
( cd "$RM_REPO" && git add tracked.txt && git -c user.email=t@t -c user.name=t commit -q -m init )

_rm_out=$(run_hook_cwd 'rm tracked.txt' "$RM_REPO"); _rm_rc=$?
[ "$_rm_rc" -eq 0 ] && printf '%s' "$_rm_out" | grep -q "git-tracked file" \
    && ok "R5: rm on tracked file warns (no block)" || bad "R5: rm on tracked file did not warn as expected (rc=$_rm_rc)"
_rm_out2=$(run_hook_cwd 'rm untracked.txt' "$RM_REPO"); _rm_rc2=$?
[ "$_rm_rc2" -eq 0 ] && ! printf '%s' "$_rm_out2" | grep -q "git-tracked file" \
    && ok "R5: rm on untracked file does not warn (negative)" || bad "R5: rm on untracked file falsely warned"
_rm_out3=$(run_hook_cwd 'rm *.txt' "$RM_REPO"); _rm_rc3=$?
[ "$_rm_rc3" -eq 0 ] && ! printf '%s' "$_rm_out3" | grep -q "git-tracked file" \
    && ok "R5: rm with glob is undeterminable, passes silently (negative)" || bad "R5: glob path falsely warned"

# === 早期 exit 撤去: プラグインルート解決が壊れても 4 ルールは生きる（2026-07-02 監査） ===
mkdir -p "$TMP/empty-root/hooks"
CLAUDE_PLUGIN_ROOT="$TMP/empty-root" sh -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push origin main\"}}' | sh '$HOOK' >/dev/null 2>&1"; [ $? -eq 2 ] \
    && ok "guard survives broken plugin-root (no odd.yaml)" || bad "guard silently disabled without odd.yaml"

# === jq 不在フォールバック（PATH から jq を消して単純 payload を通す） ===
NOJQ="$TMP/nojq-bin"
mkdir -p "$NOJQ"
for c in sh sed grep printf cat tr head dirname basename pwd; do
    p=$(command -v "$c" 2>/dev/null) && ln -s "$p" "$NOJQ/$c" 2>/dev/null
done
PATH="$NOJQ" sh -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push origin main\"}}' | sh '$HOOK' >/dev/null 2>&1"; [ $? -eq 2 ] \
    && ok "fallback: simple main push blocked without jq" || bad "fallback: no-jq simple form not blocked"

echo
[ "$fail" = "0" ] && { echo "ALL OK (test-odd-kill-switch)"; exit 0; } || { echo "FAILURES (test-odd-kill-switch)"; exit 1; }
