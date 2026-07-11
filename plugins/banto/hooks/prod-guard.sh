#!/bin/sh
# prod-guard.sh — PreToolUse(Bash) 本番環境操作ガード（deterministic block）
#
# 本番環境への書き込み系操作（deploy / infra apply / 本番ホストへの ssh）を検出し既定で block する。
# **責務分担**: git push / commit / PR 系 → release-guard.sh。本ファイルは本番オペレーションのみ。
#
# 検出パターン（セグメント先頭トークン列ベース。release-guard R5 の awk 先頭トークン抽出の作法を踏襲
# — 引用文字列や無関係な文中の言及を誤検知しない。先行する VAR=val 代入列は読み飛ばし、
# BANTO_ALLOW_PROD=1 があれば同じセグメントの escape として拾う）:
#   1. kubectl の --context / -n / --namespace 値に prod を含む
#   2. terraform apply / terraform destroy（-auto-approve 付きは what に明記）
#   3. vercel --prod、flyctl deploy、gcloud app deploy、aws ... --profile に prod を含む
#   4. npm/pnpm/yarn/bun run <script> でスクリプト名が deploy 系 + prod を含む
#   5. ssh 接続先ホスト名に prod を含む
# 追加パターンは環境変数 BANTO_PROD_PATTERNS（改行区切り正規表現、セグメント全体に対して grep -E）で拡張可能。
#
# 判定（grants: {base}/meta/grants.json の prod_ops キー。_ai_context_grant 経由）:
#   allow   → warn で通過
#   deny    → block（escape 案内なし）
#   confirm（既定・grants 未設定時も同じ）→ block + BANTO_ALLOW_PROD=1 で escape 可
#             （前置代入 `BANTO_ALLOW_PROD=1 vercel --prod` でも有効）+ grants 案内 1 行
#
# 入力: stdin に hook payload JSON（tool_name / tool_input.command / cwd）
# 出力: block 時 stderr + exit 2。fail-open: jq 不在・payload 不正・判定不能は exit 0。

set -u

PAYLOAD=$(cat 2>/dev/null || true)

command -v jq >/dev/null 2>&1 || exit 0
TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
HOOK_CWD=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
[ "$TOOL_NAME" = "Bash" ] || exit 0
[ -n "$CMD" ] || exit 0
[ -n "$HOOK_CWD" ] || HOOK_CWD=$PWD

warn() { printf '[prod guard] %s\n' "$1" >&2; }

# grants リゾルバ（{base}/meta/grants.json）。サブシェルで呼び、自身の変数（set -u 下）を汚さない。
# 解決不能時は "confirm" = block + escape の既定動作を維持（fail-open）。
_grant() {
    _g_paths="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts}"
    [ -z "$_g_paths" ] && _g_paths=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
    [ -n "$_g_paths" ] && [ -f "$_g_paths/_ai-context-paths.sh" ] || { echo confirm; return 0; }
    # AI_PATHS を明示: sourced 時は $0 が呼び出し元（本ファイル）のままなので、_ai-context-paths.sh
    # 自身の $0 フォールバックでは scripts/ を指せない。ai-context-postcommit.sh と同じ作法で渡す。
    ( AI_PATHS="$_g_paths/_ai-context-paths.sh"; . "$AI_PATHS"; _ai_context_grant "$1" "$2" )
}

# セグメントを「esc フラグ / 先頭コマンド / 残り引数」に分解する（release-guard R5 の _first3 と同じ
# 先頭代入スキップ方式。BANTO_ALLOW_PROD=1 が代入列にあれば esc を立てる。3 回の独立 awk 呼び出し
# ─ 1 回にまとめて詰めると区切り文字の復元が壊れやすいため、素直な独立呼び出しにしてある）。
_seg_esc() {
    printf '%s\n' "$1" | awk '{ e="noesc"; i=1; while (i<=NF && $i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { if ($i=="BANTO_ALLOW_PROD=1") e="esc"; i++ } print e }'
}
_seg_cmd() {
    printf '%s\n' "$1" | awk '{ i=1; while (i<=NF && $i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) i++; print (i<=NF ? $i : "") }'
}
_seg_rest() {
    printf '%s\n' "$1" | awk '{ i=1; while (i<=NF && $i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) i++; i++; out=""; for (; i<=NF; i++) out=(out==""?$i:out OFS $i); print out }'
}

_prod=0
_prod_esc=0
_prod_what=""

_segments=$(printf '%s\n' "$CMD" | tr ';&|' '\n')
while IFS= read -r _seg; do
    [ -n "$_seg" ] || continue
    _esc=$(_seg_esc "$_seg")
    _cmd=$(_seg_cmd "$_seg")
    _rest=$(_seg_rest "$_seg")
    _rest_padded=" $_rest "

    _hit=0
    _what=""
    case "$_cmd" in
        kubectl)
            if printf '%s' "$_rest" | grep -Eq -- '(--context|--namespace|-n)[= ][^ ]*prod'; then
                _hit=1; _what="kubectl (--context/-n/--namespace value contains 'prod')"
            fi
            ;;
        terraform)
            case "$_rest_padded" in
                *" apply"*)
                    _hit=1; _what="terraform apply"
                    case "$_rest_padded" in *" -auto-approve"*) _what="terraform apply -auto-approve" ;; esac
                    ;;
                *" destroy"*)
                    _hit=1; _what="terraform destroy"
                    case "$_rest_padded" in *" -auto-approve"*) _what="terraform destroy -auto-approve" ;; esac
                    ;;
            esac
            ;;
        vercel)
            case "$_rest_padded" in *" --prod"*) _hit=1; _what="vercel --prod" ;; esac
            ;;
        flyctl)
            case "$_rest_padded" in *" deploy"*) _hit=1; _what="flyctl deploy" ;; esac
            ;;
        gcloud)
            case "$_rest_padded" in *" app deploy"*) _hit=1; _what="gcloud app deploy" ;; esac
            ;;
        aws)
            if printf '%s' "$_rest" | grep -Eq -- '--profile[= ][^ ]*prod'; then
                _hit=1; _what="aws (--profile value contains 'prod')"
            fi
            ;;
        npm|pnpm|yarn|bun)
            _script=$(printf '%s' "$_rest" | awk '{ if ($1 == "run") print $2 }')
            if [ -n "$_script" ] && printf '%s' "$_script" | grep -Eqi 'deploy.*prod|prod.*deploy'; then
                _hit=1; _what="$_cmd run $_script"
            fi
            ;;
        ssh)
            _host=$(printf '%s' "$_rest" | awk '{ for (i = 1; i <= NF; i++) if ($i !~ /^-/) { print $i; exit } }')
            _hostonly=${_host#*@}
            case "$_hostonly" in *prod*) _hit=1; _what="ssh to host containing 'prod' ($_hostonly)" ;; esac
            ;;
    esac

    # BANTO_PROD_PATTERNS: 改行区切りの追加正規表現（セグメント全体に対して grep -E）
    if [ "$_hit" = "0" ] && [ -n "${BANTO_PROD_PATTERNS:-}" ]; then
        _old_ifs=$IFS
        IFS='
'
        for _pat in $BANTO_PROD_PATTERNS; do
            [ -n "$_pat" ] || continue
            if printf '%s' "$_seg" | grep -Eq -- "$_pat"; then
                _hit=1; _what="custom pattern: $_pat"
                break
            fi
        done
        IFS=$_old_ifs
    fi

    if [ "$_hit" = "1" ]; then
        _prod=1
        _prod_what="$_what"
        [ "$_esc" = "esc" ] && _prod_esc=1
        break
    fi
done <<PROD_GUARD_SEGMENTS
$_segments
PROD_GUARD_SEGMENTS

[ "$_prod" = "1" ] || exit 0

_g_prod=$(_grant prod_ops "$HOOK_CWD")

if [ "$_g_prod" = "deny" ]; then
    printf '[prod guard] production operation is blocked (grants: prod_ops = deny in {base}/meta/grants.json): %s\n' "$_prod_what" >&2
    exit 2
elif [ "$_g_prod" = "allow" ]; then
    warn "production operation allowed via grants: prod_ops — $_prod_what"
    exit 0
elif [ "${BANTO_ALLOW_PROD:-0}" = "1" ] || [ "$_prod_esc" = "1" ]; then
    warn "production operation allowed via BANTO_ALLOW_PROD=1 — $_prod_what"
    exit 0
else
    {
        printf '[prod guard] Production-environment operation is blocked: %s\n\n' "$_prod_what"
        printf 'Reason: prod deploys / infra changes are outward-facing and hard to reverse\n'
        printf '        (safety.md: production-environment operations are blocked by default).\n\n'
        printf 'Options:\n'
        printf '  1. Confirm with the user in text, then escape explicitly:\n'
        printf '       BANTO_ALLOW_PROD=1 <command>\n'
        printf '  2. Standing per-repo approval: write "prod_ops": "allow" to {base}/meta/grants.json\n'
        printf '     (managed by the ai-context skill)\n'
    } >&2
    exit 2
fi
