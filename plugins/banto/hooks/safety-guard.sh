#!/bin/sh
# safety-guard.sh — シークレット exfil の deterministic block（PreToolUse: Bash）
#
# 経緯: 旧 safety-guard は v5.16.0 で security-guidance plugin へ委譲する前提で削除されたが、
# 委譲先は PostToolUse/Stop の**警告のみ**で PreToolUse block を持たないことが 2026-06-05 の
# hook 監査で判明（実行前に止める決定論ガードが空白化していた）。CONCEPT「強制は hook
# （口約束で守らせない）」に従い、safety.md のシークレット保護ルールのうち deterministic に
# 判定できる最小集合を block する形で復活（decisions/2026-06-05-135057）。
#
# 検出対象（safety.md のシークレット保護ルールに対応）:
#   1. .env 系ファイルの生読み出し（cat/head/tail/less/more/bat/strings/diff/grep 系）
#      - .env.example / .env.sample / .env.template / .env.dist は対象外（secret を含まない約束事）
#      - sed による mask 読み（`sed 's/=.*/=***/' .env`）は safety.md 公認のため**対象外**
#   2. 環境変数の一括ダンプ: printenv / 裸の env / 裸の set / declare -p / export -p
#   3. シェルトレース: bash -x / sh -x / zsh -x / set -x（source した .env の値が trace に出る）
#
# escape: BANTO_ALLOW_SECRET_READ=1（正当なデバッグ・stub .env 等。値がチャット履歴に
#         残ることを理解した上での明示 opt-out）
#
# 判定はセグメント単位（; & | 改行で分割。odd-kill-switch.sh と同方式 — 全文 substring の
# 誤爆を避ける）。コマンド位置（セグメント先頭トークン）のみ見るため、引数中の文字列
# （`echo "cat .env"` 等）では発火しない。
#
# 入力: PreToolUse hook payload (stdin JSON)
# 出力: block 時 stderr + exit 2 / それ以外 exit 0
# POSIX互換: macOS / Linux / WSL

set -u

[ "${BANTO_ALLOW_SECRET_READ:-0}" = "1" ] && exit 0

PAYLOAD=$(cat 2>/dev/null || true)

# command 抽出（jq 優先。grep fallback は \" 以降を読めない既知の限界 — kill-switch と同じ）
if command -v jq >/dev/null 2>&1; then
    CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
    CMD=$(printf "%s" "$PAYLOAD" | grep -oE '"command":[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"command":[[:space:]]*"([^"]*)".*/\1/')
fi
[ -z "$CMD" ] && exit 0

_env_read=0      # .env 系の生読み出し
_env_dump=0      # printenv / env / set / declare -p / export -p
_trace=0         # bash -x / set -x

_segments=$(printf '%s\n' "$CMD" | tr ';&|' '\n')
while IFS= read -r _seg; do
    # 先頭トークン（コマンド位置）を取る。sudo / command / nohup / time は 1 つ読み飛ばす
    _rest=${_seg#"${_seg%%[![:space:]]*}"}
    _first=${_rest%% *}
    case "$_first" in
        sudo|command|nohup|time)
            _rest=${_rest#"$_first"}
            _rest=${_rest#"${_rest%%[![:space:]]*}"}
            _first=${_rest%% *}
            ;;
    esac
    [ -z "$_first" ] && continue

    # ---- 3) シェルトレース ----
    case "$_first" in
        bash|sh|zsh|dash|ksh)
            case " $_seg " in *" -x "*|*" -x") _trace=1 ;; esac ;;
        set)
            _trimmed=$(printf '%s' "$_rest" | sed -e 's/[[:space:]]*$//')
            case "$_trimmed" in
                set) _env_dump=1 ;;          # 裸の set（全変数ダンプ）
                *" -x"*|*"-x "*) _trace=1 ;; # set -x（-e / -u 等は通過）
            esac ;;
    esac

    # ---- 2) 環境変数ダンプ ----
    case "$_first" in
        printenv) _env_dump=1 ;;
        env)
            _trimmed=$(printf '%s' "$_rest" | sed -e 's/[[:space:]]*$//')
            [ "$_trimmed" = "env" ] && _env_dump=1 ;;  # 裸の env のみ（env VAR=x cmd は通過）
        declare|typeset)
            case " $_seg " in *" -p "*|*" -p") _env_dump=1 ;; esac ;;
        export)
            _trimmed=$(printf '%s' "$_rest" | sed -e 's/[[:space:]]*$//')
            [ "$_trimmed" = "export -p" ] && _env_dump=1 ;;
    esac

    # ---- 1) .env 系の生読み出し ----
    case "$_first" in
        cat|head|tail|less|more|bat|strings|diff|grep|egrep|fgrep|rg)
            # 引用符を剥がしてから照合（cat "$HOME/.env" / cat '.env' の引用回避を塞ぐ）
            _seg_noq=$(printf '%s' "$_seg" | tr -d '\042\047')
            case " $_seg_noq " in
                *".env.example"*|*".env.sample"*|*".env.template"*|*".env.dist"*)
                    : ;;  # secret を含まない約束事ファイルは通過
                *"/.env "*|*"/.env"|*" .env "*|*" .env"|*"/.env."*|*" .env."*)
                    _env_read=1 ;;
            esac ;;
    esac
done <<SAFETY_GUARD_SEGMENTS
$_segments
SAFETY_GUARD_SEGMENTS

[ "$_env_read" = "0" ] && [ "$_env_dump" = "0" ] && [ "$_trace" = "0" ] && exit 0

cat >&2 << 'BLOCK_SECRET'
[safety guard] Blocked a command that risks exposing secrets.

Reason: raw output of .env / environment variables stays in the chat history and transcript and cannot be retracted (safety.md).

Alternatives:
  1. Show key names only:          sed 's/=.*/=***/' .env
  2. Show only the value length:   echo "KEY=[${#VAR} chars]"
  3. When grepping with a prefix, do not sweep in token-like vars (*_API_KEY / *_SECRET / *_TOKEN)
  4. Debug with a stub .env that contains no secrets (e.g. LAMBDA_API_KEY=dummy)

Temporary escape (understanding it stays in the history): BANTO_ALLOW_SECRET_READ=1 <command>
BLOCK_SECRET
exit 2
