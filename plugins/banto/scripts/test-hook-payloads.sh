#!/bin/sh
# test-hook-payloads.sh — block 系 hook の合成 payload テスト（コンテナ不要・jq のみ依存）
# 対象:
#   - safety-guard.sh: .env 生読み / env dump / shell trace / git add・commit の secret-commit + escape + 負例
#   - lint-guard.sh:   lockfile / build 成果物 block + 通過負例
#   - agent-guard.sh:  短プロンプト block + 通過負例
#   - H-08 リグレッション: 複数行 content / バックスラッシュ入り command の payload が
#     dash 系 sh でも fail-open しない（printf '%s' 化の検証）
# ci.yml と clean-room-test.sh の双方から呼ばれる前提（2026-06-12 監査 H-13）。
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
HOOKS="$DIR/../hooks"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

bash_payload() { jq -c -n --arg c "$1" '{tool_name:"Bash", tool_input:{command:$c}}'; }
write_payload() { jq -c -n --arg fp "$1" --arg c "${2:-x}" '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}'; }

# === safety-guard.sh ===
SG="$HOOKS/safety-guard.sh"
bash_payload 'cat .env' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: cat .env blocked" || bad "safety: cat .env not blocked"
bash_payload 'head -5 ./config/.env.production' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: head .env.production blocked" || bad "safety: .env.* read not blocked"
bash_payload 'cat .env.example' | sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "safety: .env.example passes" || bad "safety: .env.example blocked"
bash_payload "sed 's/=.*/=***/' .env" | sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "safety: masked sed read passes (sanctioned)" || bad "safety: masked sed blocked"
bash_payload 'printenv' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: printenv blocked" || bad "safety: printenv not blocked"
bash_payload 'env' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: bare env blocked" || bad "safety: bare env not blocked"
bash_payload 'env FOO=1 ./run.sh' | sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "safety: env VAR=x cmd passes" || bad "safety: env prefix form blocked"
bash_payload 'declare -p' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: declare -p blocked" || bad "safety: declare -p not blocked"
bash_payload 'bash -x deploy.sh' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: bash -x blocked" || bad "safety: bash -x not blocked"
bash_payload 'set -x; ./run.sh' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: set -x blocked" || bad "safety: set -x not blocked"
bash_payload 'set -eu' | sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "safety: set -eu passes" || bad "safety: set -eu blocked"
bash_payload 'cat .env' | env BANTO_ALLOW_SECRET_READ=1 sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "safety: BANTO_ALLOW_SECRET_READ=1 escape works" || bad "safety: escape broken"
# H-08 リグレッション: バックスラッシュ + 改行入り command でも検出が機能する
bash_payload 'echo "step1\nstep2" > log.txt
cat .env' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: multiline+backslash payload still detected (H-08)" || bad "safety: H-08 regression (fail-open on multiline)"

# --- safety-guard.sh: secret-commit ガード（git add / git commit(-a) の .env 系 staged 検出) ---
bash_payload 'git add .env' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: git add .env blocked" || bad "safety: git add .env not blocked"
bash_payload 'git add .env.local' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "safety: git add .env.local blocked" || bad "safety: git add .env.local not blocked"
bash_payload 'git add .env.example' | sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "safety: git add .env.example passes" || bad "safety: git add .env.example blocked"
bash_payload 'git add src/app.js README.md' | sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "safety: git add normal files passes" || bad "safety: git add normal files blocked"
bash_payload 'git add .env' | env BANTO_ALLOW_SECRET_COMMIT=1 sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "safety: git add .env escape via BANTO_ALLOW_SECRET_COMMIT" || bad "safety: secret-commit escape broken"

if command -v git >/dev/null 2>&1; then
    SG_TMP=$(mktemp -d "${TMPDIR:-/tmp}/safety-guard-secret-test.XXXXXX")
    git init -q -b main "$SG_TMP"
    ( cd "$SG_TMP" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
    printf 'SECRET=x' > "$SG_TMP/.env"
    ( cd "$SG_TMP" && git add .env )
    jq -c -n --arg c "git commit -m x" --arg cwd "$SG_TMP" \
        '{tool_name:"Bash", tool_input:{command:$c}, cwd:$cwd}' | sh "$SG" >/dev/null 2>&1; [ $? -eq 2 ] \
        && ok "safety: git commit with staged .env blocked (via git diff --cached)" || bad "safety: staged .env commit not blocked"
    ( cd "$SG_TMP" && git restore --staged .env )
    jq -c -n --arg c "git commit -m x" --arg cwd "$SG_TMP" \
        '{tool_name:"Bash", tool_input:{command:$c}, cwd:$cwd}' | sh "$SG" >/dev/null 2>&1; [ $? -eq 0 ] \
        && ok "safety: git commit with unstaged .env passes (not staged)" || bad "safety: unstaged .env falsely blocked"
    rm -rf "$SG_TMP"
else
    echo "SKIP: git not found (secret-commit staged-diff cases)"
fi

# === lint-guard.sh ===
LG="$HOOKS/lint-guard.sh"
write_payload "/proj/package-lock.json" | sh "$LG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "lint: package-lock.json blocked" || bad "lint: package-lock.json not blocked"
write_payload "/proj/uv.lock" | sh "$LG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "lint: uv.lock blocked (H-20)" || bad "lint: uv.lock not blocked"
write_payload "/proj/composer.lock" | sh "$LG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "lint: composer.lock blocked (H-20)" || bad "lint: composer.lock not blocked"
write_payload "/proj/go.sum" | sh "$LG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "lint: go.sum blocked (H-20)" || bad "lint: go.sum not blocked"
write_payload "/proj/Pipfile.lock" | sh "$LG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "lint: Pipfile.lock blocked (H-20)" || bad "lint: Pipfile.lock not blocked"
write_payload "/proj/pubspec.lock" | sh "$LG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "lint: pubspec.lock blocked (H-20)" || bad "lint: pubspec.lock not blocked"
write_payload "/proj/src/main.ts" | sh "$LG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "lint: source file passes" || bad "lint: source file blocked"
write_payload "/proj/dist/bundle.js" | sh "$LG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "lint: dist/ output blocked" || bad "lint: dist/ not blocked"
# H-08 リグレッション: 複数行 content を持つ payload で file_path 抽出が壊れない
write_payload "/proj/yarn.lock" 'line1
line\nwith\tescapes
line3 $(echo x)' | sh "$LG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "lint: multiline content payload still blocks lockfile (H-08)" || bad "lint: H-08 regression (multiline fail-open)"

# === agent-guard.sh ===
AG="$HOOKS/agent-guard.sh"
jq -c -n '{tool_name:"Agent", tool_input:{prompt:"short"}}' | sh "$AG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "agent: short prompt blocked" || bad "agent: short prompt not blocked"
LONG=$(printf 'Investigate the auth module: goal, target files src/auth/*.ts, success criteria all tests green, follow repo conventions. %s' \
    "Include enough context because workers do not inherit the parent session context.")
jq -c -n --arg p "$LONG" '{tool_name:"Agent", tool_input:{prompt:$p}}' | sh "$AG" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "agent: sufficient prompt passes" || bad "agent: long prompt blocked"
# H-08 リグレッション: 複数行 prompt の payload で抽出が壊れて fail-open しない
jq -c -n '{tool_name:"Agent", tool_input:{prompt:"tiny\nprompt"}}' | sh "$AG" >/dev/null 2>&1; [ $? -eq 2 ] \
    && ok "agent: multiline short prompt still blocked (H-08)" || bad "agent: H-08 regression (multiline fail-open)"

# === SessionStart advisory hooks (knowledge-draft-review / ai-context-prune-auto) ===
# これらは SessionStart の advisory フック（提示/掃除のみ）。合成 SessionStart payload で
# 必ず exit 0（never block）であること、payload 不正でも fail-open することを確認する。
ss_payload() { jq -c -n --arg cwd "$1" --arg sid "${2:-ss-test}" '{cwd:$cwd, session_id:$sid, source:"startup"}'; }
for H in knowledge-draft-review.sh ai-context-prune-auto.sh; do
    HK="$HOOKS/$H"
    [ -f "$HK" ] || { bad "session-start: $H missing"; continue; }
    # 正常 payload（存在する CWD）→ exit 0
    ss_payload "$DIR/.." "ss-$H" | sh "$HK" >/dev/null 2>&1; [ $? -eq 0 ] \
        && ok "session-start: $H exits 0 on valid payload (never blocks)" \
        || bad "session-start: $H nonzero exit on valid payload"
    # 空 payload → fail-open exit 0
    printf '%s' '' | sh "$HK" >/dev/null 2>&1; [ $? -eq 0 ] \
        && ok "session-start: $H fail-open exit 0 on empty payload" \
        || bad "session-start: $H not fail-open on empty payload"
    # 不正 JSON → fail-open exit 0
    printf '%s' 'not json {{' | sh "$HK" >/dev/null 2>&1; [ $? -eq 0 ] \
        && ok "session-start: $H fail-open exit 0 on garbage payload" \
        || bad "session-start: $H not fail-open on garbage payload"
done

echo
[ "$fail" = "0" ] && { echo "ALL OK (test-hook-payloads)"; exit 0; } || { echo "FAILURES (test-hook-payloads)"; exit 1; }
