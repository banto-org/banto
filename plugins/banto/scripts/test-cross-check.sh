#!/bin/sh
# test-cross-check.sh — tests for cross-check.sh (S5 多モデル相互検証、サブスク CLI 優先版)。
# codex / gemini / claude / curl はすべて実際には呼ばず、フェイクバイナリ（PATH 先頭に配置）で
# リクエストを記録・応答を差し替える。auto 判定に影響するテストは、ホスト実機にインストール
# 済みの本物の codex / claude 等を拾わないよう、隔離した最小 PATH（fakebin + /usr/bin + /bin）で実行する。
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CC="$SCRIPT_DIR/cross-check.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

command -v jq >/dev/null 2>&1 || { echo "jq required for this test"; exit 0; }

FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/fakebin"

# 隔離 PATH: ホストに本物の codex / gemini / claude が入っていても拾わない
SAFE_PATH="$FIX/fakebin:/usr/bin:/bin"

# ---- フェイク curl（PATH 先頭）: request body を FAKE_CURL_CAPTURE に記録し、
#      FAKE_CURL_RESPONSE の内容を -o 先へコピーして応答とする ----
cat > "$FIX/fakebin/curl" <<'EOF'
#!/bin/sh
OUT=""
DATA_SRC=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUT="$2"; shift 2 ;;
        --data) DATA_SRC="$2"; shift 2 ;;
        -w) shift 2 ;;
        -X) shift 2 ;;
        -H) shift 2 ;;
        --max-time) shift 2 ;;
        -sS|-s|-S) shift ;;
        *) shift ;;
    esac
done
case "$DATA_SRC" in
    @*) SRC_FILE="${DATA_SRC#@}"; [ -n "${FAKE_CURL_CAPTURE:-}" ] && cat "$SRC_FILE" > "$FAKE_CURL_CAPTURE" ;;
    *) [ -n "${FAKE_CURL_CAPTURE:-}" ] && printf '%s' "$DATA_SRC" > "$FAKE_CURL_CAPTURE" ;;
esac
if [ -n "$OUT" ]; then
    if [ -n "${FAKE_CURL_RESPONSE:-}" ] && [ -f "$FAKE_CURL_RESPONSE" ]; then
        cat "$FAKE_CURL_RESPONSE" > "$OUT"
    else
        printf '{}' > "$OUT"
    fi
fi
printf '%s' "${FAKE_CURL_HTTP_CODE:-200}"
exit "${FAKE_CURL_EXIT:-0}"
EOF
chmod +x "$FIX/fakebin/curl"

# ---- フェイク codex（PATH 先頭）: `codex exec --json --skip-git-repo-check [-m MODEL] -`
#      stdin 全体を FAKE_CODEX_CAPTURE に記録し、-m の値を FAKE_CODEX_MODEL_CAPTURE に記録、
#      FAKE_CODEX_RESPONSE（JSONL）を stdout へ出す ----
cat > "$FIX/fakebin/codex" <<'EOF'
#!/bin/sh
MODEL=""
while [ $# -gt 0 ]; do
    case "$1" in
        -m) MODEL="$2"; shift 2 ;;
        *) shift ;;
    esac
done
[ -n "${FAKE_CODEX_MODEL_CAPTURE:-}" ] && printf '%s' "$MODEL" > "$FAKE_CODEX_MODEL_CAPTURE"
IN=$(cat)
[ -n "${FAKE_CODEX_CAPTURE:-}" ] && printf '%s' "$IN" > "$FAKE_CODEX_CAPTURE"
if [ -n "${FAKE_CODEX_RESPONSE:-}" ] && [ -f "$FAKE_CODEX_RESPONSE" ]; then
    cat "$FAKE_CODEX_RESPONSE"
fi
exit "${FAKE_CODEX_EXIT:-0}"
EOF
chmod +x "$FIX/fakebin/codex"

# ---- フェイク gemini（PATH 先頭）: `gemini --output-format json [-m MODEL]`、stdin がプロンプト全体 ----
cat > "$FIX/fakebin/gemini" <<'EOF'
#!/bin/sh
MODEL=""
while [ $# -gt 0 ]; do
    case "$1" in
        -m) MODEL="$2"; shift 2 ;;
        *) shift ;;
    esac
done
[ -n "${FAKE_GEMINI_MODEL_CAPTURE:-}" ] && printf '%s' "$MODEL" > "$FAKE_GEMINI_MODEL_CAPTURE"
IN=$(cat)
[ -n "${FAKE_GEMINI_CAPTURE:-}" ] && printf '%s' "$IN" > "$FAKE_GEMINI_CAPTURE"
if [ -n "${FAKE_GEMINI_RESPONSE:-}" ] && [ -f "$FAKE_GEMINI_RESPONSE" ]; then
    cat "$FAKE_GEMINI_RESPONSE"
fi
exit "${FAKE_GEMINI_EXIT:-0}"
EOF
chmod +x "$FIX/fakebin/gemini"

# ---- フェイク claude（PATH 先頭）: `claude -p "<instruction>" [--model M] --output-format json --bare`、
#      stdin がレビュー対象本文 ----
cat > "$FIX/fakebin/claude" <<'EOF'
#!/bin/sh
MODEL=""
while [ $# -gt 0 ]; do
    case "$1" in
        --model) MODEL="$2"; shift 2 ;;
        -p) shift 2 ;;
        *) shift ;;
    esac
done
[ -n "${FAKE_CLAUDE_MODEL_CAPTURE:-}" ] && printf '%s' "$MODEL" > "$FAKE_CLAUDE_MODEL_CAPTURE"
IN=$(cat)
[ -n "${FAKE_CLAUDE_CAPTURE:-}" ] && printf '%s' "$IN" > "$FAKE_CLAUDE_CAPTURE"
if [ -n "${FAKE_CLAUDE_RESPONSE:-}" ] && [ -f "$FAKE_CLAUDE_RESPONSE" ]; then
    cat "$FAKE_CLAUDE_RESPONSE"
fi
exit "${FAKE_CLAUDE_EXIT:-0}"
EOF
chmod +x "$FIX/fakebin/claude"

jq -n '{choices:[{message:{content:"looks fine\n{\"verdict\":\"sound\",\"issues\":[]}"}}]}' > "$FIX/resp_sound.json"
jq -n '{choices:[{message:{content:"bad\n{\"verdict\":\"flawed\",\"issues\":[\"issue1\",\"issue2\"]}"}}]}' > "$FIX/resp_flawed.json"
jq -n '{choices:[{message:{content:"unsure\n{\"verdict\":\"uncertain\",\"issues\":[]}"}}]}' > "$FIX/resp_uncertain.json"
jq -n '{choices:[{message:{content:"no verdict json here"}}]}' > "$FIX/resp_unparsable.json"

jq -nc '{type:"thread.started",thread_id:"t1"}' > "$FIX/resp_codex_sound.jsonl"
jq -nc '{type:"item.completed",item:{id:"item_1",type:"agent_message",text:"looks fine\n{\"verdict\":\"sound\",\"issues\":[]}"}}' >> "$FIX/resp_codex_sound.jsonl"
jq -nc '{type:"turn.completed",usage:{}}' >> "$FIX/resp_codex_sound.jsonl"

jq -n '{response:"looks fine\n{\"verdict\":\"sound\",\"issues\":[]}"}' > "$FIX/resp_gemini_sound.json"
jq -n '{result:"looks fine\n{\"verdict\":\"sound\",\"issues\":[]}"}' > "$FIX/resp_claude_sound.json"

# ---- (a) auto 検出の優先順（codex → gemini → openrouter） ----
mkdir -p "$FIX/only_codex" "$FIX/only_gemini"
cp "$FIX/fakebin/codex" "$FIX/only_codex/"
cp "$FIX/fakebin/gemini" "$FIX/only_gemini/"

out=$(printf 'x' | env -u OPENROUTER_API_KEY PATH="$FIX/only_codex:/usr/bin:/bin" \
    FAKE_CODEX_RESPONSE="$FIX/resp_codex_sound.jsonl" \
    sh "$CC" --mode diff 2>&1); rc=$?
{ [ "$rc" = "0" ] && echo "$out" | grep -q "backend=codex"; } \
    && ok "auto: codex があれば codex を選ぶ" || no "auto は codex を優先するはず（rc=$rc: $out）"

out=$(printf 'x' | env -u OPENROUTER_API_KEY PATH="$FIX/only_gemini:/usr/bin:/bin" \
    FAKE_GEMINI_RESPONSE="$FIX/resp_gemini_sound.json" \
    sh "$CC" --mode diff 2>&1); rc=$?
{ [ "$rc" = "0" ] && echo "$out" | grep -q "backend=gemini"; } \
    && ok "auto: codex が無く gemini があれば gemini を選ぶ" || no "auto は gemini にフォールバックするはず（rc=$rc: $out）"

out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$FIX/fakebin:/usr/bin:/bin" \
    FAKE_CURL_RESPONSE="$FIX/resp_sound.json" \
    sh "$CC" --mode diff 2>&1); rc=$?
# fakebin には codex/gemini/claude も置いてあるので、両方無い状況を作るため空ディレクトリ経由にする
mkdir -p "$FIX/only_curl_target"
cp "$FIX/fakebin/curl" "$FIX/only_curl_target/"
out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$FIX/only_curl_target:/usr/bin:/bin" \
    FAKE_CURL_RESPONSE="$FIX/resp_sound.json" \
    sh "$CC" --mode diff 2>&1); rc=$?
{ [ "$rc" = "0" ] && echo "$out" | grep -q "backend=openrouter"; } \
    && ok "auto: codex/gemini が無く OPENROUTER_API_KEY があれば openrouter を選ぶ" \
    || no "auto は最後に openrouter を選ぶはず（rc=$rc: $out）"

# ---- (e) 経路ゼロ時の exit 3 案内 ----
mkdir -p "$FIX/empty_target"
out=$(printf 'x' | env -u OPENROUTER_API_KEY PATH="$FIX/empty_target:/usr/bin:/bin" sh "$CC" --mode diff 2>&1); rc=$?
{ [ "$rc" = "3" ] && echo "$out" | grep -q "利用可能な判定経路が無い"; } \
    && ok "経路ゼロ -> exit 3（案内メッセージ付き）" || no "経路ゼロは exit 3 + 案内のはず（rc=$rc: $out）"

# ---- (b) codex バックエンドへのプロンプト受け渡しと verdict パース ----
out=$(printf 'target text' | env PATH="$SAFE_PATH" \
    FAKE_CODEX_RESPONSE="$FIX/resp_codex_sound.jsonl" FAKE_CODEX_CAPTURE="$FIX/cap_codex.txt" \
    sh "$CC" --backend codex --mode claim 2>&1); rc=$?
{ [ "$rc" = "0" ] && echo "$out" | grep -q "verdict: sound"; } \
    && ok "codex backend: verdict sound -> exit 0" || no "codex backend の verdict 解析に失敗（rc=$rc: $out）"
grep -q "target text" "$FIX/cap_codex.txt" && ok "codex backend: stdin にレビュー対象本文が渡る" \
    || no "codex への stdin にレビュー対象が含まれていない"
grep -q "mode=claim" "$FIX/cap_codex.txt" && ok "codex backend: プロンプトに mode が埋め込まれる" \
    || no "codex へのプロンプトに mode=claim が無い"

out=$(printf 'x' | env PATH="$SAFE_PATH" \
    FAKE_CODEX_RESPONSE="$FIX/resp_codex_sound.jsonl" FAKE_CODEX_MODEL_CAPTURE="$FIX/cap_codex_model.txt" \
    sh "$CC" --backend codex --model gpt-5.6 2>&1); rc=$?
model=$(cat "$FIX/cap_codex_model.txt" 2>/dev/null)
[ "$model" = "gpt-5.6" ] && ok "codex backend: --model が -m として渡る" \
    || no "codex への --model 上書きが渡っていない（got: $model）"

# ---- gemini backend も同様に verdict パース ----
out=$(printf 'gemini target' | env PATH="$SAFE_PATH" \
    FAKE_GEMINI_RESPONSE="$FIX/resp_gemini_sound.json" FAKE_GEMINI_CAPTURE="$FIX/cap_gemini.txt" \
    sh "$CC" --backend gemini --mode design 2>&1); rc=$?
{ [ "$rc" = "0" ] && echo "$out" | grep -q "verdict: sound"; } \
    && ok "gemini backend: verdict sound -> exit 0" || no "gemini backend の verdict 解析に失敗（rc=$rc: $out）"
grep -q "gemini target" "$FIX/cap_gemini.txt" && ok "gemini backend: stdin にレビュー対象本文が渡る" \
    || no "gemini への stdin にレビュー対象が含まれていない"

# ---- (c) claude backend は既定で拒否、--allow-same-vendor で通る ----
out=$(printf 'x' | env PATH="$SAFE_PATH" sh "$CC" --backend claude 2>&1); rc=$?
{ [ "$rc" = "3" ] && echo "$out" | grep -q "allow-same-vendor"; } \
    && ok "claude backend は既定で拒否される" || no "claude backend は既定拒否のはず（rc=$rc: $out）"

out=$(printf 'claude target' | env PATH="$SAFE_PATH" \
    FAKE_CLAUDE_RESPONSE="$FIX/resp_claude_sound.json" FAKE_CLAUDE_CAPTURE="$FIX/cap_claude.txt" \
    sh "$CC" --backend claude --allow-same-vendor 2>&1); rc=$?
{ [ "$rc" = "0" ] && echo "$out" | grep -q "verdict: sound" && echo "$out" | grep -q "self-preference"; } \
    && ok "--allow-same-vendor で claude backend が通り、bias 注意が出る" \
    || no "--allow-same-vendor 指定時の claude backend が期待どおりでない（rc=$rc: $out）"
grep -q "claude target" "$FIX/cap_claude.txt" && ok "claude backend: stdin にレビュー対象本文が渡る" \
    || no "claude への stdin にレビュー対象が含まれていない"

# ---- (d) 全バックエンドでのシークレットマスク ----
secret_in='token sk-abcdefghij1234567890 and Bearer xyz123abcXYZ and ghp_1234567890abcd'

printf '%s' "$secret_in" | env PATH="$SAFE_PATH" \
    FAKE_CODEX_RESPONSE="$FIX/resp_codex_sound.jsonl" FAKE_CODEX_CAPTURE="$FIX/cap_codex_mask.txt" \
    sh "$CC" --backend codex >/dev/null 2>&1
if grep -q "sk-abcdefghij1234567890\|xyz123abcXYZ\|ghp_1234567890abcd" "$FIX/cap_codex_mask.txt"; then
    no "codex backend: 生シークレットが残っている"
else
    ok "codex backend: 生シークレットは除去されている"
fi
grep -q '\[MASKED\]' "$FIX/cap_codex_mask.txt" && ok "codex backend: [MASKED] に置換されている" || no "codex backend: [MASKED] が見当たらない"

printf '%s' "$secret_in" | env PATH="$SAFE_PATH" \
    FAKE_GEMINI_RESPONSE="$FIX/resp_gemini_sound.json" FAKE_GEMINI_CAPTURE="$FIX/cap_gemini_mask.txt" \
    sh "$CC" --backend gemini >/dev/null 2>&1
if grep -q "sk-abcdefghij1234567890\|xyz123abcXYZ\|ghp_1234567890abcd" "$FIX/cap_gemini_mask.txt"; then
    no "gemini backend: 生シークレットが残っている"
else
    ok "gemini backend: 生シークレットは除去されている"
fi
grep -q '\[MASKED\]' "$FIX/cap_gemini_mask.txt" && ok "gemini backend: [MASKED] に置換されている" || no "gemini backend: [MASKED] が見当たらない"

printf '%s' "$secret_in" | env PATH="$SAFE_PATH" \
    FAKE_CLAUDE_RESPONSE="$FIX/resp_claude_sound.json" FAKE_CLAUDE_CAPTURE="$FIX/cap_claude_mask.txt" \
    sh "$CC" --backend claude --allow-same-vendor >/dev/null 2>&1
if grep -q "sk-abcdefghij1234567890\|xyz123abcXYZ\|ghp_1234567890abcd" "$FIX/cap_claude_mask.txt"; then
    no "claude backend: 生シークレットが残っている"
else
    ok "claude backend: 生シークレットは除去されている"
fi
grep -q '\[MASKED\]' "$FIX/cap_claude_mask.txt" && ok "claude backend: [MASKED] に置換されている" || no "claude backend: [MASKED] が見当たらない"

printf '%s' "$secret_in" | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" \
    FAKE_CURL_RESPONSE="$FIX/resp_sound.json" FAKE_CURL_CAPTURE="$FIX/cap_openrouter_mask.json" \
    sh "$CC" --backend openrouter >/dev/null 2>&1
if grep -q "sk-abcdefghij1234567890\|xyz123abcXYZ\|ghp_1234567890abcd" "$FIX/cap_openrouter_mask.json"; then
    no "openrouter backend: 生シークレットが残っている"
else
    ok "openrouter backend: 生シークレットは除去されている"
fi
grep -q '\[MASKED\]' "$FIX/cap_openrouter_mask.json" && ok "openrouter backend: [MASKED] に置換されている" || no "openrouter backend: [MASKED] が見当たらない"

# ---- 以降は openrouter backend を明示して既存契約を検証（--nda / --cheap / --model 上書き / verdict / HTTP エラー） ----

# ---- --nda と --cheap 併用 -> openrouter ではエラー終了 ----
out=$(printf 'hello' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" sh "$CC" --backend openrouter --nda --cheap 2>&1); rc=$?
{ [ "$rc" = "3" ] && echo "$out" | grep -q "併用不可"; } \
    && ok "openrouter: --nda + --cheap -> エラー" || no "openrouter: --nda + --cheap は併用不可エラーのはず（rc=$rc: $out）"

# ---- --nda と --cheap 併用でも openrouter 以外なら通る（NDA は注意表示のみに緩和） ----
out=$(printf 'hello' | env PATH="$SAFE_PATH" \
    FAKE_CODEX_RESPONSE="$FIX/resp_codex_sound.jsonl" \
    sh "$CC" --backend codex --nda --cheap 2>&1); rc=$?
{ [ "$rc" = "0" ] && echo "$out" | grep -q "NDA 案件での注意"; } \
    && ok "codex backend: --nda + --cheap も通り、注意表示のみが出る" \
    || no "codex backend では --nda + --cheap を禁止しないはず（rc=$rc: $out）"

# ---- モデル解決が model-policy.json から行われる（openrouter） ----
out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" \
    FAKE_CURL_RESPONSE="$FIX/resp_sound.json" FAKE_CURL_CAPTURE="$FIX/cap_default.json" \
    sh "$CC" --backend openrouter --mode diff 2>&1); rc=$?
model=$(jq -r '.model' "$FIX/cap_default.json" 2>/dev/null)
[ "$model" = "x-ai/grok-build-0.1" ] && ok "既定モデルが policy の openrouter.default から解決される" \
    || no "既定モデルは x-ai/grok-build-0.1 のはず（got: $model）"
echo "$out" | grep -q "x-ai/grok-build-0.1" && ok "出力にも既定モデル名が現れる" || no "出力にモデル名が出ていない: $out"

out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" \
    FAKE_CURL_RESPONSE="$FIX/resp_sound.json" FAKE_CURL_CAPTURE="$FIX/cap_cheap.json" \
    sh "$CC" --backend openrouter --mode claim --cheap 2>&1); rc=$?
model=$(jq -r '.model' "$FIX/cap_cheap.json" 2>/dev/null)
[ "$model" = "deepseek/deepseek-v4-flash" ] && ok "--cheap が policy の openrouter.cost_optimized から解決される" \
    || no "--cheap モデルは deepseek/deepseek-v4-flash のはず（got: $model）"

out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" \
    FAKE_CURL_RESPONSE="$FIX/resp_sound.json" FAKE_CURL_CAPTURE="$FIX/cap_nda.json" \
    sh "$CC" --backend openrouter --nda 2>&1); rc=$?
model=$(jq -r '.model' "$FIX/cap_nda.json" 2>/dev/null)
[ "$model" = "x-ai/grok-build-0.1" ] && ok "--nda は openrouter.default モデルを強制する" \
    || no "--nda は default を強制するはず（got: $model）"

out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" \
    FAKE_CURL_RESPONSE="$FIX/resp_sound.json" FAKE_CURL_CAPTURE="$FIX/cap_override.json" \
    sh "$CC" --backend openrouter --model custom/override-model 2>&1); rc=$?
model=$(jq -r '.model' "$FIX/cap_override.json" 2>/dev/null)
[ "$model" = "custom/override-model" ] && ok "--model 上書きが最優先される" \
    || no "--model 上書きが効いていない（got: $model）"

# ---- verdict のパースと exit code 対応（openrouter backend） ----
out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" FAKE_CURL_RESPONSE="$FIX/resp_sound.json" sh "$CC" --backend openrouter 2>&1); rc=$?
{ [ "$rc" = "0" ] && echo "$out" | grep -q "verdict: sound"; } && ok "sound -> exit 0" || no "sound は exit 0 のはず（rc=$rc）"

out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" FAKE_CURL_RESPONSE="$FIX/resp_flawed.json" sh "$CC" --backend openrouter 2>&1); rc=$?
{ [ "$rc" = "1" ] && echo "$out" | grep -q "verdict: flawed" && echo "$out" | grep -q "issue1"; } \
    && ok "flawed -> exit 1（issues も出力）" || no "flawed は exit 1 のはず（rc=$rc: $out）"

out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" FAKE_CURL_RESPONSE="$FIX/resp_uncertain.json" sh "$CC" --backend openrouter 2>&1); rc=$?
{ [ "$rc" = "2" ] && echo "$out" | grep -q "verdict: uncertain"; } && ok "uncertain -> exit 2" || no "uncertain は exit 2 のはず（rc=$rc）"

out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" FAKE_CURL_RESPONSE="$FIX/resp_unparsable.json" sh "$CC" --backend openrouter 2>&1); rc=$?
{ [ "$rc" = "2" ] && echo "$out" | grep -q "解析に失敗"; } && ok "verdict 解析失敗 -> exit 2（fail-safe で uncertain 扱い）" \
    || no "解析失敗は exit 2 のはず（rc=$rc: $out）"

# ---- HTTP エラー応答 -> exit 3 ----
out=$(printf 'x' | env OPENROUTER_API_KEY=dummy PATH="$SAFE_PATH" FAKE_CURL_RESPONSE="$FIX/resp_sound.json" FAKE_CURL_HTTP_CODE=401 sh "$CC" --backend openrouter 2>&1); rc=$?
[ "$rc" = "3" ] && ok "HTTP 401 -> exit 3" || no "HTTP エラーは exit 3 のはず（rc=$rc: $out）"

# ---- codex 実行そのものが失敗（rc!=0）-> exit 3 ----
out=$(printf 'x' | env PATH="$SAFE_PATH" FAKE_CODEX_EXIT=1 sh "$CC" --backend codex 2>&1); rc=$?
[ "$rc" = "3" ] && ok "codex backend: 実行失敗（rc!=0）-> exit 3" || no "codex backend の実行失敗は exit 3 のはず（rc=$rc: $out）"

echo "cross-check tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
