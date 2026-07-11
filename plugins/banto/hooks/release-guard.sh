#!/bin/sh
# release-guard.sh — PR / merge / commit / 公開操作の deterministic ガード + push 時自動検査
#
# spec: docs/specs/2026-06-12_release-guard-hooks_spec.md（store 側）
#
# **責務分担**（重複防止）:
#   - git push origin main / --no-verify / --force / rm -rf root → odd-kill-switch.sh (block)
#   - シークレット生読み → safety-guard.sh / lockfile 等 Write → lint-guard.sh / PII egress → egress-guard.sh
#   - 当ファイル → commit / PR merge / パブリック公開操作 + push 時の repo 所有検査のみ
#
# ルール（全 block・全 escape ハッチ付き。対話的承認ゲートは作らない = CONCEPT anti-goal）:
#   R1: main/master 上の git commit         → BANTO_ALLOW_MAIN_COMMIT=1 で escape（store repo は常時許可）
#   R2: gh pr merge                          → BANTO_ALLOW_PR_MERGE=1 で escape（自分の PR のみ）
#   R3: パブリック公開系コマンド             → BANTO_ALLOW_PUBLISH=1 で escape（--dry-run は通過）
#   R4: git push 時に repo の scripts/pre-push-check.sh を実行、fail で block
#                                            → BANTO_SKIP_PUSH_CHECK=1 で escape
#                                              スクリプト不在時は block せず warn のみ
#   R5: gh pr create                         → BANTO_ALLOW_PR_CREATE=1 で escape（owner の確認を得てから設定する）
#                                              または {base}/meta/grants.json の pr_create: allow で
#                                              repo 単位の常設許可（deny なら escape 案内なしで block）
#
# 入力: stdin に hook payload JSON（tool_name / tool_input.command / cwd）
# 出力: block 時 stderr + exit 2。fail-open: jq / git 不在・payload 不正は exit 0。

set -u

# grants リゾルバ（{base}/meta/grants.json）。サブシェルで呼び、release-guard 自身の
# 変数（set -u 下）を汚さない。解決不能時は "confirm" = 既存の確認必須動作を維持（fail-open）。
_grant() {
    _g_paths="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts}"
    [ -z "$_g_paths" ] && _g_paths=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
    [ -n "$_g_paths" ] && [ -f "$_g_paths/_ai-context-paths.sh" ] || { echo confirm; return 0; }
    # AI_PATHS を明示: sourced 時は $0 が呼び出し元（本ファイル）のままなので、_ai-context-paths.sh
    # 自身の $0 フォールバックでは scripts/ を指せない。ai-context-postcommit.sh と同じ作法で渡す。
    ( AI_PATHS="$_g_paths/_ai-context-paths.sh"; . "$AI_PATHS"; _ai_context_grant "$1" "$2" )
}

PAYLOAD=$(cat 2>/dev/null || true)

command -v jq >/dev/null 2>&1 || exit 0
TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
HOOK_CWD=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
[ "$TOOL_NAME" = "Bash" ] || exit 0
[ -n "$CMD" ] || exit 0
[ -n "$HOOK_CWD" ] || HOOK_CWD=$PWD

warn() { printf '[release guard] %s\n' "$1" >&2; }

# コマンド文字列から対象 dir を推定（kill-switch ルール 1 と同手法: git -C → cd → payload cwd）
_target_dir() {
    _cand=$(printf '%s' "$CMD" | grep -oE 'git -C +[^ ;&|]+' | head -1 | sed -E 's/^git -C +//')
    [ -z "$_cand" ] && _cand=$(printf '%s' "$CMD" | grep -oE '(^|[;&|] *)cd +[^ ;&|]+' | head -1 | sed -E 's/.*cd +//')
    _cand=${_cand#\"}; _cand=${_cand%\"}
    _cand=${_cand#\'}; _cand=${_cand%\'}
    case "$_cand" in
        "~")   _cand="$HOME" ;;
        "~/"*) _cand="$HOME/${_cand#"~/"}" ;;
    esac
    [ -n "$_cand" ] && printf '%s' "$_cand" || printf '%s' "$HOOK_CWD"
}

# セグメント単位判定（kill-switch と同じ: `; & |` で分割し誤検知を避ける）
_commit=0
_pr_merge=0
_pr_merge_esc=0
_pr_create=0
_pr_create_esc=0
_publish=0
_publish_what=""
_push=0
_segments=$(printf '%s\n' "$CMD" | tr ';&|' '\n')
while IFS= read -r _seg; do
    [ -n "$_seg" ] || continue
    _padded=" $_seg "
    # R1: git commit（サブコマンド位置）
    case "$_padded" in
        *" git commit "*|*" git "*" commit "*) _commit=1 ;;
    esac
    # R2: gh pr merge（R5 と同方式: 先頭トークン列のみ判定 — 引用文字列・heredoc 本文・
    # ドキュメント中の言及を誤検知しない。先行する VAR=val 代入は読み飛ばし、代入列に
    # BANTO_ALLOW_PR_MERGE=1 があれば escape として記録する — コマンド前置の代入は
    # hook プロセスの環境には届かないため、ここで拾う）
    _first3m=$(printf '%s\n' "$_seg" | awk '{i=1; while (i<=NF && $i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { if ($i == "BANTO_ALLOW_PR_MERGE=1") esc=1; i++ }; if (i+2<=NF) print ((esc)?"esc ":"") $i, $(i+1), $(i+2); exit}')
    case "$_first3m" in
        "gh pr merge")     _pr_merge=1 ;;
        "esc gh pr merge") _pr_merge=1; _pr_merge_esc=1 ;;
    esac
    # R5: gh pr create（先頭トークン列のみ判定 — 引用文字列やコミットメッセージ内の言及を誤検知しない。
    # 先行する VAR=val 代入は読み飛ばす。代入列に BANTO_ALLOW_PR_CREATE=1 があれば escape として
    # 記録する — コマンド前置の代入は hook プロセスの環境には届かないため、ここで拾う）
    _first3=$(printf '%s\n' "$_seg" | awk '{i=1; while (i<=NF && $i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { if ($i == "BANTO_ALLOW_PR_CREATE=1") esc=1; i++ }; if (i+2<=NF) print ((esc)?"esc ":"") $i, $(i+1), $(i+2); exit}')
    case "$_first3" in
        "gh pr create")     _pr_create=1 ;;
        "esc gh pr create") _pr_create=1; _pr_create_esc=1 ;;
    esac
    # R3: パブリック公開系（--dry-run のみ通過。汎用 " -n " 許容は publish 系以外の -n を
    # 巻き込んで block を迂回させ得たため廃止 — 2026-07-02 監査）
    case "$_padded" in
        *"--dry-run"*) ;;
        *" gh repo create "*)
            case "$_padded" in *"--public"*) _publish=1; _publish_what="gh repo create --public" ;; esac ;;
        *" gh repo edit "*)
            case "$_padded" in *"--visibility public"*|*"--visibility=public"*) _publish=1; _publish_what="gh repo edit --visibility public" ;; esac ;;
        *" npm publish"*|*" pnpm publish"*|*" yarn publish"*|*" bun publish"*)
            _publish=1; _publish_what="package registry publish" ;;
        *" cargo publish"*)   _publish=1; _publish_what="cargo publish" ;;
        *" gem push"*)        _publish=1; _publish_what="gem push" ;;
        *" twine upload"*)    _publish=1; _publish_what="twine upload" ;;
        *" dart pub publish"*|*" flutter pub publish"*)
            _publish=1; _publish_what="pub publish" ;;
    esac
    # R4: git push（kill-switch ルール 1 と同じサブコマンド位置判定）
    case "$_padded" in
        *" git push "*|*" git "*" push "*) _push=1 ;;
    esac
done <<RELEASE_GUARD_SEGMENTS
$_segments
RELEASE_GUARD_SEGMENTS

DIR=$(_target_dir)

# ---- R1: main/master 上の git commit ---- (BLOCK)
if [ "$_commit" = "1" ] && command -v git >/dev/null 2>&1; then
    _branch=$(git -C "$DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
    case "$_branch" in
        main|master)
            if [ -f "$DIR/.ai-context-store" ]; then
                warn "commit on main in ai-context store (allowed: knowledge store)"
            elif [ "${BANTO_ALLOW_MAIN_COMMIT:-0}" = "1" ]; then
                warn "commit on main/master (allowed via BANTO_ALLOW_MAIN_COMMIT=1)"
            else
                cat >&2 << 'BLOCK_MAIN_COMMIT'
[release guard] Committing directly on main/master is blocked.

Reason: the harness norm is branch-first (commits land on main only via PR).
        Direct pushes to main are already blocked, so commits made here would strand.

Options:
  1. Create a branch first (recommended):
       git switch -c feature/topic   # your work-in-progress moves with you
  2. Temporary escape (explicit, per command):
       BANTO_ALLOW_MAIN_COMMIT=1 git commit ...
BLOCK_MAIN_COMMIT
                exit 2
            fi
            ;;
    esac
fi

# ---- R2: gh pr merge ---- (BLOCK)
if [ "$_pr_merge" = "1" ]; then
    if [ "${BANTO_ALLOW_PR_MERGE:-0}" = "1" ] || [ "${_pr_merge_esc:-0}" = "1" ]; then
        warn "gh pr merge (allowed via BANTO_ALLOW_PR_MERGE=1 — your own PR only)"
    else
        cat >&2 << 'BLOCK_PR_MERGE'
[release guard] `gh pr merge` is blocked.

Reason: safety.md — never merge a PR created by someone else, even with the user's
        permission; the author cannot be verified offline, so all merges are gated.

Options:
  1. Ask the user to merge the PR themselves (recommended; required for others' PRs)
  2. For a PR you authored in this session, temporary escape:
       BANTO_ALLOW_PR_MERGE=1 gh pr merge ...
     (never use the escape for someone else's PR)
BLOCK_PR_MERGE
        exit 2
    fi
fi

# ---- R5: gh pr create ---- (BLOCK, grants-aware)
if [ "$_pr_create" = "1" ]; then
    _g_pr_create=$(_grant pr_create "$DIR")
    if [ "$_g_pr_create" = "deny" ]; then
        printf '[release guard] `gh pr create` is blocked (grants: pr_create = deny in {base}/meta/grants.json).\n' >&2
        exit 2
    elif [ "$_g_pr_create" = "allow" ]; then
        warn "gh pr create (allowed via grants: pr_create)"
    elif [ "${BANTO_ALLOW_PR_CREATE:-0}" = "1" ] || [ "${_pr_create_esc:-0}" = "1" ]; then
        warn "gh pr create (allowed via BANTO_ALLOW_PR_CREATE=1)"
    else
        cat >&2 << 'BLOCK_PR_CREATE'
[release guard] `gh pr create` is blocked.

Reason: creating a PR is outward-facing (safety.md: posting to external services requires
        explicit confirmation first).

Options:
  1. Confirm with the user in text, then get the owner's approval before setting the escape:
       BANTO_ALLOW_PR_CREATE=1 gh pr create ...
  2. Ask the user to create the PR themselves
  3. Standing per-repo approval: write "pr_create": "allow" to {base}/meta/grants.json
     (managed by the ai-context skill)
BLOCK_PR_CREATE
        exit 2
    fi
fi

# ---- R3: パブリック公開系コマンド ---- (BLOCK)
if [ "$_publish" = "1" ]; then
    if [ "${BANTO_ALLOW_PUBLISH:-0}" = "1" ]; then
        warn "public release command (allowed via BANTO_ALLOW_PUBLISH=1): $_publish_what"
    else
        cat >&2 << BLOCK_PUBLISH
[release guard] Public release command is blocked: $_publish_what

Reason: publishing is outward-facing and effectively irreversible (safety.md:
        posting to external services requires explicit confirmation first).

Options:
  1. Confirm with the user in text, then escape explicitly:
       BANTO_ALLOW_PUBLISH=1 <command>
  2. Dry-run first where supported (--dry-run passes this guard)
BLOCK_PUBLISH
        exit 2
    fi
fi

# ---- R4: git push 時の repo 所有検査 (scripts/pre-push-check.sh) ---- (BLOCK on fail)
if [ "$_push" = "1" ] && [ "${BANTO_SKIP_PUSH_CHECK:-0}" != "1" ]; then
    _check="$DIR/scripts/pre-push-check.sh"
    if [ -f "$_check" ]; then
        _out=$(cd "$DIR" && sh "$_check" 2>&1)
        _rc=$?
        if [ "$_rc" -ne 0 ]; then
            {
                printf '[release guard] pre-push check failed (exit %s) — push blocked.\n\n' "$_rc"
                printf '%s\n' "$_out" | tail -20
                printf '\nFix the findings above, or escape explicitly: BANTO_SKIP_PUSH_CHECK=1 git push ...\n'
            } >&2
            exit 2
        fi
        warn "pre-push check passed ($_check)"
    else
        warn "no scripts/pre-push-check.sh found in $DIR — push proceeding without a pre-push check"
    fi
fi

exit 0
