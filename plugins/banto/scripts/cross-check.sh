#!/bin/sh
# cross-check.sh — 主モデル（Claude）の成果物を別ベンダーモデルに反証レビューさせる（多モデル相互検証）。
#
# 設計: decisions/2026-07-10-070500（別プロバイダ judge は self-preference bias 緩和のため。
# 討議型は不採用、決定論チェックの後段に置く単発の反証レビューのみ）。
#
# owner 決定（2026-07-10）: OpenRouter 契約は不採用。各ユーザーが既存のサブスク契約範囲内で
# 実施できるよう、バックエンドをサブスク CLI 優先（codex → gemini）に切り替え、OpenRouter は
# APIキーがある場合の fallback として温存する。同一ベンダー（claude）は既定では judge に使わない
# （self-preference bias）。全バックエンドの非対話実行構文は公式ドキュメントで裏取り済み
# （codex: developers.openai.com/codex/noninteractive、gemini: geminicli.com/docs/cli/headless、
# claude: code.claude.com/docs/en/headless）。未確認の構文は無い。
#
# 使い方: レビュー対象を stdin か引数ファイルで渡す。
#   git diff | sh cross-check.sh --mode diff --nda
#   sh cross-check.sh --mode claim --backend gemini notes.md
#
# 依存: jq（全バックエンド共通）。バックエンドごとに以下のいずれかが必要:
#   codex      … codex CLI（ChatGPT サブスク認証を利用、非対話実行 = `codex exec`）
#   gemini     … gemini CLI（非対話実行 = ヘッドレスモード）
#   openrouter … curl + 環境変数 OPENROUTER_API_KEY（fallback）
#   claude     … claude CLI（同一ベンダーのため既定拒否、--allow-same-vendor で許可）
set -u

usage() {
    cat <<'EOF' >&2
usage: cross-check.sh [--mode diff|claim|design] [--backend auto|codex|gemini|openrouter|claude]
                       [--nda] [--cheap] [--model <name>] [--allow-same-vendor] [<file>]
  stdin か <file> でレビュー対象のテキストを渡す。
  --mode                reviewの種別（diff=差分 / claim=主張 / design=設計）。既定 diff。
  --backend              判定経路。既定 auto（検出順: codex → gemini → openrouter）。
  --nda                  NDA 案件向け。openrouter では cost_optimized を拒否し default を強制する。
                         サブスク CLI（codex/gemini/claude）ではデータ処理経路の確認を促す注意表示に留める。
  --cheap                openrouter のコスト最優先レビュー（DeepSeek V4 Flash）。--nda との併用は
                         openrouter でのみ不可（他バックエンドでは --cheap は無効化されるだけ）。
  --model                各バックエンドのモデルを明示的に上書きする（未指定ならバックエンド既定を使う）。
  --allow-same-vendor    --backend claude を許可する（既定は self-preference bias を理由に拒否）。
exit codes: sound=0 / flawed=1 / uncertain=2 / 実行エラー=3
EOF
}

MODE=diff
BACKEND=auto
NDA=0
CHEAP=0
MODEL_OVERRIDE=""
ALLOW_SAME_VENDOR=0
INPUT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE="${2:-}"; shift 2 ;;
        --backend) BACKEND="${2:-}"; shift 2 ;;
        --nda) NDA=1; shift ;;
        --cheap) CHEAP=1; shift ;;
        --model) MODEL_OVERRIDE="${2:-}"; shift 2 ;;
        --allow-same-vendor) ALLOW_SAME_VENDOR=1; shift ;;
        -h|--help) usage; exit 0 ;;
        --*) echo "cross-check: unknown option: $1" >&2; usage; exit 3 ;;
        *) INPUT_FILE="$1"; shift ;;
    esac
done

case "$MODE" in
    diff|claim|design) ;;
    *) echo "cross-check: --mode は diff|claim|design のいずれか（指定: $MODE ）" >&2; exit 3 ;;
esac

case "$BACKEND" in
    auto|codex|gemini|openrouter|claude) ;;
    *) echo "cross-check: --backend は auto|codex|gemini|openrouter|claude のいずれか（指定: $BACKEND ）" >&2; exit 3 ;;
esac

command -v jq >/dev/null 2>&1 || { echo "cross-check: jq が必要" >&2; exit 3; }

POLICY="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}/templates/model-policy.json"

# macOS 標準に timeout が無い（coreutils の gtimeout のみの環境あり）。無ければタイムアウトなしで実行する
# （typecheck.sh と同じフォールバック方針）。
TIMEOUT_BIN=$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)
run_with_timeout() {
    if [ -n "$TIMEOUT_BIN" ]; then
        "$TIMEOUT_BIN" 120 "$@"
    else
        "$@"
    fi
}

# ---- バックエンド解決 ----
# auto: サブスク CLI 優先（codex → gemini）、どちらも無ければ OPENROUTER_API_KEY 保有時のみ openrouter。
# claude は同一ベンダーのため auto の検出対象に含めない（--backend claude を明示し、かつ
# --allow-same-vendor を付けたときのみ許可）。
RESOLVED=""
case "$BACKEND" in
    auto)
        if command -v codex >/dev/null 2>&1; then
            RESOLVED=codex
        elif command -v gemini >/dev/null 2>&1; then
            RESOLVED=gemini
        elif [ -n "${OPENROUTER_API_KEY:-}" ]; then
            RESOLVED=openrouter
        else
            echo "cross-check: 利用可能な判定経路が無い。codex CLI（https://developers.openai.com/codex）か gemini CLI（https://geminicli.com）のインストール、または OPENROUTER_API_KEY の設定が必要。" >&2
            exit 3
        fi
        ;;
    codex)
        command -v codex >/dev/null 2>&1 || { echo "cross-check: codex CLI が見つからない（https://developers.openai.com/codex からインストール）" >&2; exit 3; }
        RESOLVED=codex
        ;;
    gemini)
        command -v gemini >/dev/null 2>&1 || { echo "cross-check: gemini CLI が見つからない（https://geminicli.com からインストール）" >&2; exit 3; }
        RESOLVED=gemini
        ;;
    openrouter)
        [ -n "${OPENROUTER_API_KEY:-}" ] || { echo "cross-check: OPENROUTER_API_KEY が未設定" >&2; exit 3; }
        RESOLVED=openrouter
        ;;
    claude)
        [ "$ALLOW_SAME_VENDOR" -eq 1 ] || {
            echo "cross-check: --backend claude は既定で拒否。主モデルと同一ベンダー（Claude ↔ Claude）は self-preference bias の懸念があるため、明示的に --allow-same-vendor を指定すること。" >&2
            exit 3
        }
        command -v claude >/dev/null 2>&1 || { echo "cross-check: claude CLI が見つからない" >&2; exit 3; }
        RESOLVED=claude
        ;;
esac

if [ "$NDA" -eq 1 ] && [ "$CHEAP" -eq 1 ] && [ "$RESOLVED" = "openrouter" ]; then
    echo "cross-check: --nda と --cheap は併用不可（NDA 案件で openrouter のコスト最優先モデルは使えない）" >&2
    exit 3
fi

if [ "$RESOLVED" = "openrouter" ]; then
    command -v curl >/dev/null 2>&1 || { echo "cross-check: curl が必要" >&2; exit 3; }
fi

if [ -n "$INPUT_FILE" ]; then
    [ -f "$INPUT_FILE" ] || { echo "cross-check: ファイルが見つからない: $INPUT_FILE" >&2; exit 3; }
    CONTENT=$(cat "$INPUT_FILE")
else
    CONTENT=$(cat)
fi
[ -n "$CONTENT" ] || { echo "cross-check: レビュー対象が空" >&2; exit 3; }

# 外部送信前の必須マスキング（sk-/ghp_/Bearer トークンをそのまま別ベンダーへ送らない。全バックエンド共通）
CONTENT=$(printf '%s' "$CONTENT" | sed -E \
    -e 's/sk-[A-Za-z0-9_-]{10,}/[MASKED]/g' \
    -e 's/ghp_[A-Za-z0-9]{10,}/[MASKED]/g' \
    -e 's/Bearer [A-Za-z0-9._-]+/Bearer [MASKED]/g')

if [ "$NDA" -eq 1 ] && [ "$RESOLVED" != "openrouter" ]; then
    echo "cross-check: NDA 案件での注意 — ${RESOLVED} は各自のサブスク契約経由で実行される。判定モデルが対象データを国外処理・第三者処理しないか契約条件を確認すること（DeepSeek 系 API への送信は引き続き拒否）。" >&2
fi

SYS_PROMPT="あなたは別ベンダー系統の反証レビュアーである。主モデル（Claude）が生成した${MODE}を REFUTE する視点で検証せよ。擁護や補足は行わず、致命的な欠陥・見落とし・誤った前提のみを列挙すること。最後に必ず他のテキストを含まない単独の JSON オブジェクトとして verdict を出力せよ: {\"verdict\": \"sound\"|\"flawed\"|\"uncertain\", \"issues\": [\"...\"]}。sound=欠陥なし。flawed=致命的な欠陥あり。uncertain=判断材料不足。"

TMP="${TMPDIR:-/tmp}"
RAWFILE="$TMP/cross-check-resp-$$.json"
ERRFILE="$TMP/cross-check-stderr-$$.log"
MSG=""
MODEL="$MODEL_OVERRIDE"

case "$RESOLVED" in
    openrouter)
        # モデル解決: --model 上書き > --nda（default 強制）> --cheap（cost_optimized）> policy の default
        if [ -n "$MODEL_OVERRIDE" ]; then
            MODEL="$MODEL_OVERRIDE"
        elif [ "$NDA" -eq 1 ]; then
            MODEL=$(jq -r '.roles.verify_external.openrouter.default // empty' "$POLICY" 2>/dev/null)
        elif [ "$CHEAP" -eq 1 ]; then
            MODEL=$(jq -r '.roles.verify_external.openrouter.cost_optimized // empty' "$POLICY" 2>/dev/null)
        else
            MODEL=$(jq -r '.roles.verify_external.openrouter.default // empty' "$POLICY" 2>/dev/null)
        fi
        [ -z "${MODEL:-}" ] && MODEL="x-ai/grok-build-0.1"

        REQFILE="$TMP/cross-check-req-$$.json"
        jq -n --arg model "$MODEL" --arg sys "$SYS_PROMPT" --arg mode "$MODE" --arg content "$CONTENT" \
            '{model: $model, temperature: 0, messages: [{role: "system", content: $sys}, {role: "user", content: ("mode=" + $mode + "\n\n" + $content)}]}' \
            > "$REQFILE"

        HTTP_CODE=$(curl -sS --max-time 120 -X POST \
            -H "Authorization: Bearer $OPENROUTER_API_KEY" \
            -H "Content-Type: application/json" \
            --data @"$REQFILE" \
            -o "$RAWFILE" \
            -w '%{http_code}' \
            "https://openrouter.ai/api/v1/chat/completions" 2>/dev/null)
        CURL_RC=$?
        rm -f "$REQFILE"

        if [ "$CURL_RC" -ne 0 ]; then
            echo "cross-check: curl 実行に失敗（rc=$CURL_RC ）" >&2
            exit 3
        fi
        case "$HTTP_CODE" in
            2??) ;;
            *) echo "cross-check: OpenRouter が HTTP $HTTP_CODE を返した。raw: $RAWFILE" >&2; exit 3 ;;
        esac
        MSG=$(jq -r '.choices[0].message.content // empty' "$RAWFILE" 2>/dev/null)
        ;;

    codex)
        # 非対話実行: `codex exec --json -`（stdin 全体をプロンプトとして読ませる、公式に明示されている強制形）。
        # 既定は read-only サンドボックス（ファイル編集は不要なので追加のサンドボックス指定はしない）。
        # --skip-git-repo-check: レビュー対象は git リポジトリ外のテキストであり得るため。
        FULL_PROMPT="$SYS_PROMPT

mode=$MODE

$CONTENT"
        if [ -n "$MODEL_OVERRIDE" ]; then
            printf '%s' "$FULL_PROMPT" | run_with_timeout codex exec --json --skip-git-repo-check -m "$MODEL_OVERRIDE" - > "$RAWFILE" 2>"$ERRFILE"
        else
            printf '%s' "$FULL_PROMPT" | run_with_timeout codex exec --json --skip-git-repo-check - > "$RAWFILE" 2>"$ERRFILE"
        fi
        BACKEND_RC=$?
        case "$BACKEND_RC" in
            0) ;;
            124) echo "cross-check: codex の実行がタイムアウト（120 秒）で打ち切られた。stderr: $ERRFILE" >&2; exit 3 ;;
            *) echo "cross-check: codex の実行に失敗（rc=$BACKEND_RC ）。stderr: $ERRFILE" >&2; exit 3 ;;
        esac
        # 最終の agent_message（item.completed イベント）だけを取り出す
        MSG=$(jq -rs '[.[] | select(.type=="item.completed" and .item.type=="agent_message") | .item.text] | last // empty' "$RAWFILE" 2>/dev/null)
        MODEL="${MODEL_OVERRIDE:-（codex 既定）}"
        ;;

    gemini)
        # 非対話実行: stdin をパイプするだけでヘッドレスモードになる（`cat file | gemini` と同型）。
        # --output-format json は {response, stats, error} を返す。
        FULL_PROMPT="$SYS_PROMPT

mode=$MODE

$CONTENT"
        if [ -n "$MODEL_OVERRIDE" ]; then
            printf '%s' "$FULL_PROMPT" | run_with_timeout gemini --output-format json -m "$MODEL_OVERRIDE" > "$RAWFILE" 2>"$ERRFILE"
        else
            printf '%s' "$FULL_PROMPT" | run_with_timeout gemini --output-format json > "$RAWFILE" 2>"$ERRFILE"
        fi
        BACKEND_RC=$?
        case "$BACKEND_RC" in
            0) ;;
            124) echo "cross-check: gemini の実行がタイムアウト（120 秒）で打ち切られた。stderr: $ERRFILE" >&2; exit 3 ;;
            *) echo "cross-check: gemini の実行に失敗（rc=$BACKEND_RC ）。stderr: $ERRFILE" >&2; exit 3 ;;
        esac
        MSG=$(jq -r '.response // empty' "$RAWFILE" 2>/dev/null)
        MODEL="${MODEL_OVERRIDE:-（gemini 既定）}"
        ;;

    claude)
        # 非対話実行: `claude -p '<指示>' --output-format json`。指示は -p 引数、レビュー対象は stdin
        # で渡す（公式ドキュメントの `cat file | claude -p '...'` と同型）。--bare でフック/スキル/
        # CLAUDE.md の自動読み込みを止め、再帰的な副作用を避ける。
        INSTRUCTION="$SYS_PROMPT

mode=$MODE"
        if [ -n "$MODEL_OVERRIDE" ]; then
            printf '%s' "$CONTENT" | run_with_timeout claude -p "$INSTRUCTION" --model "$MODEL_OVERRIDE" --output-format json --bare > "$RAWFILE" 2>"$ERRFILE"
        else
            printf '%s' "$CONTENT" | run_with_timeout claude -p "$INSTRUCTION" --output-format json --bare > "$RAWFILE" 2>"$ERRFILE"
        fi
        BACKEND_RC=$?
        case "$BACKEND_RC" in
            0) ;;
            124) echo "cross-check: claude の実行がタイムアウト（120 秒）で打ち切られた。stderr: $ERRFILE" >&2; exit 3 ;;
            *) echo "cross-check: claude の実行に失敗（rc=$BACKEND_RC ）。stderr: $ERRFILE" >&2; exit 3 ;;
        esac
        MSG=$(jq -r '.result // empty' "$RAWFILE" 2>/dev/null)
        MODEL="${MODEL_OVERRIDE:-（claude 既定）}"
        ;;
esac

if [ -z "$MSG" ]; then
    echo "cross-check: 応答形式が不正（${RESOLVED} からの本文抽出に失敗）。raw: $RAWFILE" >&2
    exit 3
fi

VERDICT_JSON=$(printf '%s' "$MSG" | grep -oE '\{[^{}]*"verdict"[^{}]*\}' | tail -1)
VERDICT=$(printf '%s' "$VERDICT_JSON" | jq -r '.verdict // empty' 2>/dev/null)
case "$VERDICT" in
    sound|flawed|uncertain) ;;
    *)
        echo "cross-check: verdict の解析に失敗（応答に規定 JSON が無い）。raw: $RAWFILE"
        echo "--- 応答本文 ---"
        printf '%s\n' "$MSG"
        exit 2
        ;;
esac

if [ "$RESOLVED" = "claude" ]; then
    echo "=== cross-check: 注意 — backend=claude は主モデルと同一ベンダー（self-preference bias の懸念あり） ==="
fi
echo "=== cross-check (mode=$MODE, backend=$RESOLVED, model=$MODEL) ==="
echo "verdict: $VERDICT"
ISSUES=$(printf '%s' "$VERDICT_JSON" | jq -r '.issues[]? // empty' 2>/dev/null)
if [ -n "$ISSUES" ]; then
    echo "issues:"
    printf '%s\n' "$ISSUES" | sed 's/^/- /'
fi
echo "raw response: $RAWFILE"

case "$VERDICT" in
    sound) exit 0 ;;
    flawed) exit 1 ;;
    uncertain) exit 2 ;;
esac
