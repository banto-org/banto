#!/bin/sh
# test-prod-guard.sh — prod-guard.sh の合成 payload テスト
# 対象: 検出 5 パターン + 非該当の素通り + escape（env / 前置代入） + grants 3 状態 + fail-open
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
HOOK="$DIR/../hooks/prod-guard.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/prod-guard-test.XXXXXX")
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
run_hook_stderr() {  # $1=command $2=cwd  → stderr のみ
    printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":%s}' \
        "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" \
        | sh "$HOOK" 2>&1 >/dev/null
}

REPO="$TMP/repo"
mkdir -p "$REPO"

# === 検出 5 パターン（block 正例） ===
run_hook 'kubectl -n prod-ns get pods' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 1: kubectl -n prod-ns blocked" || bad "detect 1: kubectl -n prod-ns not blocked"
run_hook 'kubectl --context prod-cluster apply -f x.yaml' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 1b: kubectl --context prod-cluster blocked" || bad "detect 1b: kubectl --context prod-cluster not blocked"
run_hook 'terraform apply -auto-approve' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 2: terraform apply -auto-approve blocked" || bad "detect 2: terraform apply not blocked"
run_hook 'terraform destroy' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 2b: terraform destroy blocked" || bad "detect 2b: terraform destroy not blocked"
run_hook 'vercel deploy --prod' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 3: vercel deploy --prod blocked" || bad "detect 3: vercel --prod not blocked"
run_hook 'flyctl deploy' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 3b: flyctl deploy blocked" || bad "detect 3b: flyctl deploy not blocked"
run_hook 'gcloud app deploy' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 3c: gcloud app deploy blocked" || bad "detect 3c: gcloud app deploy not blocked"
run_hook 'aws s3 ls --profile my-prod-account' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 3d: aws --profile *prod* blocked" || bad "detect 3d: aws --profile prod not blocked"
run_hook 'npm run deploy:prod' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 4: npm run deploy:prod blocked" || bad "detect 4: npm run deploy:prod not blocked"
run_hook 'pnpm run prod:deploy' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 4b: pnpm run prod:deploy blocked" || bad "detect 4b: pnpm run prod:deploy not blocked"
run_hook 'ssh user@prod-web-01' "$REPO"; [ $? -eq 2 ] \
    && ok "detect 5: ssh to prod host blocked" || bad "detect 5: ssh to prod host not blocked"

# === 非該当（素通り・負例） ===
run_hook 'kubectl -n staging get pods' "$REPO"; [ $? -eq 0 ] \
    && ok "non-hit: kubectl -n staging passes" || bad "non-hit: kubectl -n staging blocked"
run_hook 'terraform plan' "$REPO"; [ $? -eq 0 ] \
    && ok "non-hit: terraform plan passes" || bad "non-hit: terraform plan blocked"
run_hook 'vercel dev' "$REPO"; [ $? -eq 0 ] \
    && ok "non-hit: vercel dev passes" || bad "non-hit: vercel dev blocked"
run_hook 'npm run test' "$REPO"; [ $? -eq 0 ] \
    && ok "non-hit: npm run test passes" || bad "non-hit: npm run test blocked"
run_hook 'ssh user@staging-web-01' "$REPO"; [ $? -eq 0 ] \
    && ok "non-hit: ssh to staging host passes" || bad "non-hit: ssh to staging host blocked"
run_hook 'echo "deploy to prod later"' "$REPO"; [ $? -eq 0 ] \
    && ok "non-hit: mention inside unrelated command passes" || bad "non-hit: false positive on unrelated mention"
run_hook 'git status' "$REPO"; [ $? -eq 0 ] \
    && ok "non-hit: unrelated git command passes" || bad "non-hit: unrelated git command blocked"

# === escape ===
BANTO_ALLOW_PROD=1 run_hook 'vercel --prod' "$REPO"; [ $? -eq 0 ] \
    && ok "escape: env BANTO_ALLOW_PROD=1 passes" || bad "escape: env BANTO_ALLOW_PROD=1 blocked"
unset BANTO_ALLOW_PROD
run_hook 'BANTO_ALLOW_PROD=1 vercel --prod' "$REPO"; [ $? -eq 0 ] \
    && ok "escape: in-command prefix escape passes" || bad "escape: in-command prefix escape ineffective"
run_hook 'BANTO_ALLOW_PROD=0 vercel --prod' "$REPO"; [ $? -eq 2 ] \
    && ok "escape: prefix =0 does not escape" || bad "escape: prefix =0 falsely escapes"
run_hook 'cd /tmp && vercel --prod' "$REPO"; [ $? -eq 2 ] \
    && ok "escape: segment after && still blocked without escape" || bad "escape: segment after && not blocked"

# === BANTO_PROD_PATTERNS 拡張 ===
# 注: `VAR=1 関数` の一時代入は POSIX では関数呼び出し後も残留しうるため（release-guard と同じ落とし穴）、
# このグループの末尾で直後に unset する
BANTO_PROD_PATTERNS='my-custom-deploy-tool' run_hook 'my-custom-deploy-tool run' "$REPO"; [ $? -eq 2 ] \
    && ok "custom pattern: BANTO_PROD_PATTERNS blocks matching command" || bad "custom pattern: BANTO_PROD_PATTERNS not applied"
unset BANTO_PROD_PATTERNS
run_hook 'my-custom-deploy-tool run' "$REPO"; [ $? -eq 0 ] \
    && ok "custom pattern: without env var, unrelated command passes" || bad "custom pattern: false positive without env var"

# === grants（{base}/meta/grants.json 3 状態） ===
mkdir -p "$TMP/store/prodproj/meta"
GRANT_MAP="$TMP/.mapping.json"
cat > "$GRANT_MAP" <<JSON
{"version":2,"store_root":"$TMP/store","projects":{"$REPO":{"project":"prodproj"}}}
JSON
GRANTS_FILE="$TMP/store/prodproj/meta/grants.json"

printf '{"grants":{"prod_ops":"allow"}}' > "$GRANTS_FILE"
AI_CONTEXT_MAPPING="$GRANT_MAP" run_hook 'vercel --prod' "$REPO"; [ $? -eq 0 ] \
    && ok "grants: prod_ops=allow passes without escape" || bad "grants: prod_ops=allow blocked"

printf '{"grants":{"prod_ops":"deny"}}' > "$GRANTS_FILE"
AI_CONTEXT_MAPPING="$GRANT_MAP" run_hook 'vercel --prod' "$REPO"; [ $? -eq 2 ] \
    && ok "grants: prod_ops=deny blocked" || bad "grants: prod_ops=deny not blocked"
_deny_msg=$(AI_CONTEXT_MAPPING="$GRANT_MAP" run_hook_stderr 'vercel --prod' "$REPO")
printf '%s' "$_deny_msg" | grep -q "BANTO_ALLOW_PROD" && bad "grants: deny message unexpectedly shows escape guidance" \
    || ok "grants: deny message has no escape guidance"

printf '{"grants":{"prod_ops":"confirm"}}' > "$GRANTS_FILE"
AI_CONTEXT_MAPPING="$GRANT_MAP" run_hook 'vercel --prod' "$REPO"; [ $? -eq 2 ] \
    && ok "grants: prod_ops=confirm behaves like default (blocked)" || bad "grants: confirm state not blocked"
AI_CONTEXT_MAPPING="$GRANT_MAP" BANTO_ALLOW_PROD=1 run_hook 'vercel --prod' "$REPO"; [ $? -eq 0 ] \
    && ok "grants: confirm state still honors env escape" || bad "grants: confirm state escape ineffective"
unset BANTO_ALLOW_PROD

rm -f "$GRANTS_FILE"
AI_CONTEXT_MAPPING="$GRANT_MAP" run_hook 'vercel --prod' "$REPO"; [ $? -eq 2 ] \
    && ok "grants: no grants.json falls back to confirm (blocked)" || bad "grants: missing grants.json not fail-open to confirm"

# === fail-open ===
printf 'not-json' | sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "fail-open: garbage payload exits 0" || bad "fail-open: garbage payload non-zero"
printf '{"tool_name":"Write","tool_input":{"file_path":"x"}}' | sh "$HOOK" >/dev/null 2>&1; [ $? -eq 0 ] \
    && ok "fail-open: non-Bash tool exits 0" || bad "fail-open: non-Bash tool non-zero"

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; else echo "FAILURES PRESENT"; exit 1; fi
