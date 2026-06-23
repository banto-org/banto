#!/bin/sh
# test-release-guard.sh — release-guard.sh の合成 payload テスト
# 対象: R1 main-commit / R2 pr-merge / R3 publish / R4 push 検査（block 正例・通過負例・escape・store 例外）
# spec: docs/specs/2026-06-12_release-guard-hooks_spec.md（store 側）
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$DIR/../hooks/release-guard.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/release-guard-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# payload を組んで hook を実行し exit code を返す
run_hook() {  # $1=command $2=cwd
    printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":%s}' \
        "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" \
        | sh "$HOOK" 2>/dev/null
}

# --- フィクスチャ: main にいる git repo / feature branch の repo / store repo ---
mk_repo() {  # $1=path $2=branch
    git init -q -b "$2" "$1"
    ( cd "$1" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
}
REPO_MAIN="$TMP/on-main";    mk_repo "$REPO_MAIN" main
REPO_FEAT="$TMP/on-feature"; mk_repo "$REPO_FEAT" feature/x
REPO_STORE="$TMP/store";     mk_repo "$REPO_STORE" main; touch "$REPO_STORE/.ai-context-store"

# === R1: main 上の git commit ===
run_hook 'git commit -m "x"' "$REPO_MAIN"; [ $? -eq 2 ] \
    && ok "R1: commit on main blocked" || bad "R1: commit on main not blocked"
run_hook 'git commit -m "x"' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R1: commit on feature branch passes" || bad "R1: feature branch commit blocked"
run_hook 'git commit -m "x"' "$REPO_STORE"; [ $? -eq 0 ] \
    && ok "R1: commit on store main passes (marker)" || bad "R1: store main commit blocked"
run_hook "git -C $REPO_MAIN commit -m x" "$REPO_FEAT"; [ $? -eq 2 ] \
    && ok "R1: git -C <main-repo> detected from another cwd" || bad "R1: git -C not detected"
run_hook 'git log --grep=commit' "$REPO_MAIN"; [ $? -eq 0 ] \
    && ok "R1: 'commit' as argument does not misfire" || bad "R1: misfire on argument"
# 注: `VAR=1 関数` の一時代入は POSIX では関数呼び出し後も残留しうるため、escape テストは
# 各グループ末尾に置き、直後に unset する
BANTO_ALLOW_MAIN_COMMIT=1 run_hook 'git commit -m "x"' "$REPO_MAIN"; [ $? -eq 0 ] \
    && ok "R1: escape via BANTO_ALLOW_MAIN_COMMIT" || bad "R1: escape ineffective"
unset BANTO_ALLOW_MAIN_COMMIT

# === R2: gh pr merge ===
run_hook 'gh pr merge 12 --squash' "$REPO_FEAT"; [ $? -eq 2 ] \
    && ok "R2: gh pr merge blocked" || bad "R2: gh pr merge not blocked"
run_hook 'gh pr view 12' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R2: gh pr view passes" || bad "R2: gh pr view blocked"
BANTO_ALLOW_PR_MERGE=1 run_hook 'gh pr merge 12 --squash' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R2: escape via BANTO_ALLOW_PR_MERGE" || bad "R2: escape ineffective"
unset BANTO_ALLOW_PR_MERGE

# === R3: 公開系コマンド ===
run_hook 'gh repo create me/x --public' "$REPO_FEAT"; [ $? -eq 2 ] \
    && ok "R3: gh repo create --public blocked" || bad "R3: repo create --public not blocked"
run_hook 'gh repo create me/x --private' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R3: gh repo create --private passes" || bad "R3: private create blocked"
run_hook 'gh repo edit me/x --visibility public' "$REPO_FEAT"; [ $? -eq 2 ] \
    && ok "R3: visibility public blocked" || bad "R3: visibility public not blocked"
run_hook 'npm publish' "$REPO_FEAT"; [ $? -eq 2 ] \
    && ok "R3: npm publish blocked" || bad "R3: npm publish not blocked"
run_hook 'npm publish --dry-run' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R3: npm publish --dry-run passes" || bad "R3: dry-run blocked"
run_hook 'cargo publish' "$REPO_FEAT"; [ $? -eq 2 ] \
    && ok "R3: cargo publish blocked" || bad "R3: cargo publish not blocked"
BANTO_ALLOW_PUBLISH=1 run_hook 'npm publish' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R3: escape via BANTO_ALLOW_PUBLISH" || bad "R3: escape ineffective"
unset BANTO_ALLOW_PUBLISH

# === R4: push 時の pre-push-check ===
mkdir -p "$REPO_FEAT/scripts"
printf '#!/bin/sh\nexit 0\n' > "$REPO_FEAT/scripts/pre-push-check.sh"
run_hook 'git push origin feature/x' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R4: push passes when check succeeds" || bad "R4: passing check blocked push"
printf '#!/bin/sh\necho boom\nexit 1\n' > "$REPO_FEAT/scripts/pre-push-check.sh"
run_hook 'git push origin feature/x' "$REPO_FEAT"; [ $? -eq 2 ] \
    && ok "R4: push blocked when check fails" || bad "R4: failing check not blocking"
run_hook 'git push origin feature/x' "$REPO_MAIN"; [ $? -eq 0 ] \
    && ok "R4: push passes when no check script exists" || bad "R4: blocked without check script"
run_hook 'git status' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R4: non-push git command ignores check" || bad "R4: non-push ran check"
BANTO_SKIP_PUSH_CHECK=1 run_hook 'git push origin feature/x' "$REPO_FEAT"; [ $? -eq 0 ] \
    && ok "R4: escape via BANTO_SKIP_PUSH_CHECK" || bad "R4: escape ineffective"
unset BANTO_SKIP_PUSH_CHECK

# === fail-open ===
printf 'not-json' | sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "fail-open: garbage payload exits 0" || bad "fail-open: garbage payload non-zero"
printf '{"tool_name":"Write","tool_input":{"file_path":"x"}}' | sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "fail-open: non-Bash tool exits 0" || bad "fail-open: non-Bash tool non-zero"

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; else echo "FAILURES PRESENT"; exit 1; fi
