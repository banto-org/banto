#!/bin/sh
# odd-kill-switch.sh — Phase 5 第 2 段（全 4 ルール block + 個別 escape ハッチ）
# 各 skill の odd.yaml に書かれた kill_switch_conditions を集約し、
# PreToolUse で risky パターンに該当する操作を検出する。
#
# 設計判断:
#   - .ai-context/decisions/2026-05-17_layer4-phase1-and-remaining-tasks_*.md
#   - .ai-context/decisions/2026-05-17_phase5-kill-switch-responsibility-split_*.md (F.3.1-F.3.3 全段)
# 概念: .ai-context/decisions/2026-05-16_layer4-operations-engineering-conceptual-framework_*.md
# 運用: .ai-context/docs/[Index] odd-spec.md
#
# **責務分担**（重複防止）:
#   - シークレット保護 (.env 生読み / printenv / bash -x 等) → safety-guard.sh (block)
#     ※ v5.16.0 で security-guidance 委譲として削除されたが、委譲先に PreToolUse block が
#       無いことが判明し v5.21.26 で最小復活（decisions/2026-06-05-135057）
#   - lockfile / build 成果物の Write/Edit → lint-guard.sh (block)
#   - PII / 内部名の客先 egress → egress-guard.sh (block)
#   - main 直 commit / gh pr merge / 公開系コマンド / push 時検査 → release-guard.sh (block)
#   - 当ファイル → 上記でカバーされない横断 kill switch のみ
#
# **ステータス**: 4 ルール全 block（全 escape ハッチ付き）+ 1 ルール warn のみ
#   - git push origin main/master   → ODD_ALLOW_MAIN_PUSH=1 で escape
#   - --no-verify                   → ODD_ALLOW_NO_VERIFY=1 で escape
#   - --force push (--force-with-lease は通過) → ODD_ALLOW_FORCE_PUSH=1 で escape
#   - rm -rf root/home/$HOME        → ODD_ALLOW_RM_RF_ROOT=1 で escape
#   - rm が git 管理下ファイルを対象とする → warn のみ（block しない。escape 不要）
#
# Sibling: odd-gate.sh is the test-failure circuit breaker (opt-in, default off); this hook blocks dangerous git / secret / destructive actions.
#
# 入力: Claude Code hook 経由で stdin に JSON が渡される（payload に tool_name / tool_input 等）
# 出力: block 時は stderr + exit 2、escape/warn 時は stderr + exit 0。

set -u

# プラグインルートを推定（CLAUDE_PLUGIN_ROOT 環境変数優先、無ければスクリプト相対）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# stdin から payload を読む（hook 標準フォーマット）。空でも続行。
PAYLOAD=$(cat 2>/dev/null || true)

# tool_name / tool_input を取り出す。jq を優先する:
# grep ベース抽出はエスケープ済み引用符 \" で command が途中切断され、それ以降の
# `git push origin main` 等が**全ルールを bypass** していた（`git commit -m "msg" && git push
# origin main` という最頻出形が素通り。2026-06-05 監査で実証・修正）。
extract_field() {
    printf "%s" "$1" | grep -oE "\"$2\":[[:space:]]*\"[^\"]*\"" | head -1 | sed -E "s/.*\"$2\":[[:space:]]*\"([^\"]*)\".*/\1/"
}
extract_command() {
    # jq 不在時のフォールバック（既知の限界: \" 以降は読めない・単一行のみ）
    printf "%s" "$1" | grep -oE '"command":[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"command":[[:space:]]*"([^"]*)".*/\1/'
}

if command -v jq >/dev/null 2>&1; then
    TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
    CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
    FILE_PATH=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    HOOK_CWD=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
else
    TOOL_NAME=$(extract_field "$PAYLOAD" "tool_name")
    CMD=$(extract_command "$PAYLOAD")
    FILE_PATH=$(extract_field "$PAYLOAD" "file_path")
    HOOK_CWD=$(extract_field "$PAYLOAD" "cwd")
fi
[ -z "$HOOK_CWD" ] && HOOK_CWD=$PWD

# 注: 以前は「odd.yaml が一つも無ければ早期 exit」していたが、本 hook の 4 ルールは
# odd.yaml を実際には読まない横断安全ルール（safety.md 由来）であり、プラグインルート解決の
# 失敗だけで安全ガードが黙って全無効になる構造だった（2026-07-02 監査で指摘）。ガードを撤去。

warn() {
    printf "[ODD warn] %s\n" "$1" >&2
}

# ---- 検出ルール 1: git push origin main / master ---- (BLOCK)
# ODD_ALLOW_MAIN_PUSH=1 で escape 可能（feature branch + PR を強く推奨）
#
# **セグメント単位判定**: コマンドを区切り記号（; & | 改行。&& || も分解される）で分割し、
# 「git の push 操作であるセグメント」の中だけで main/force を判定する。
# 旧実装の全文 glob は (a) `git -C <dir> push` 取りこぼし、(b) 別コマンドのフラグ混入
# （`docker build -f Dockerfile . && git push origin feat` の -f を force と誤認）、
# (c) 引数中の "push" 文字列での誤発火（`git log --grep=push --force`）を起こしていた
# （2026-06-05 監査で実証・修正）。
# 既知の限界: クォート内の区切り記号も分割される（`git commit -m "a; b"` 等）が、
# 分割後セグメントが push 操作の形を成さない限り誤発火しない（安全側）。
_main_push=0
_force_push=0
_segments=$(printf '%s\n' "$CMD" | tr ';&|' '\n')
while IFS= read -r _seg; do
    # push がサブコマンド位置の単語として現れる git コマンドか
    case " $_seg " in
        *" git push "*|*" git "*" push "*) ;;
        *) continue ;;
    esac
    case "$_seg" in
        *"origin main"*|*"origin master"*|*"origin HEAD:main"*|*"origin HEAD:master"*|\
        *"main:main"*|*"master:master"*|*"HEAD:refs/heads/main"*|*"HEAD:refs/heads/master"*)
            _main_push=1 ;;
    esac
    case "$_seg" in
        *"--force-with-lease"*)
            : ;;  # 安全寄り force、通過
        *"--force"*)
            _force_push=1 ;;
        *)
            case " $_seg " in *" -f "*) _force_push=1 ;; esac ;;
    esac
done <<KILL_SWITCH_SEGMENTS
$_segments
KILL_SWITCH_SEGMENTS
if [ "$_main_push" = "1" ]; then
        # ai-context 知識 store（marker `.ai-context-store`）は main 直 push を許可。
        # push ポリシー分離: コード repo=PR ゲート / 知識 store=auto-push（decisions/2026-05-29_005, 2026-05-30_002）。
        store_ok=0
        [ -f ".ai-context-store" ] && store_ok=1
        if [ "$store_ok" = "0" ]; then
            # `git -C <dir>` / `cd <dir>` から対象 dir を抽出して marker で knowledge store を判定。
            cand=$(printf '%s' "$CMD" | grep -oE 'git -C +[^ ;&|]+' | head -1 | sed -E 's/^git -C +//')
            [ -z "$cand" ] && cand=$(printf '%s' "$CMD" | grep -oE '(^|[;&|] *)cd +[^ ;&|]+' | head -1 | sed -E 's/.*cd +//')
            # クォート除去 → 先頭チルダを手動展開する。コマンド文字列内の `~` はリテラルで
            # シェル展開されないため、従来は絶対パスだけ通りチルダ指定の store を marker 見失いで
            # 誤 block していた（"絶対パスなら OK" は対処になっていなかった）。
            cand=${cand#\"}; cand=${cand%\"}
            cand=${cand#\'}; cand=${cand%\'}
            case "$cand" in
                "~")   cand="$HOME" ;;
                "~/"*) cand="$HOME/${cand#"~/"}" ;;
            esac
            [ -n "$cand" ] && [ -f "$cand/.ai-context-store" ] && store_ok=1
        fi
        if [ "$store_ok" = "1" ]; then
            warn "main push to ai-context store (allowed: knowledge store)"
        elif [ "${ODD_ALLOW_MAIN_PUSH:-0}" = "1" ]; then
            warn "push to main/master (allowed via ODD_ALLOW_MAIN_PUSH=1)"
        else
            cat >&2 << 'BLOCK_MAIN_PUSH'
[ODD kill switch] Direct push to the main/master branch is blocked.

Reason: safety valve of the self-driving harness (safety.md: direct push to main/master is forbidden). Risk of updating main without review.

Options:
  1. Create a feature branch and merge via PR (recommended)
       git switch -c feature/topic && git push -u origin feature/topic && gh pr create
  2. Ask the user to push manually (hooks do not run for them)
  3. Temporary escape (explicit per-commit permission):
       ODD_ALLOW_MAIN_PUSH=1 git push origin main
BLOCK_MAIN_PUSH
            exit 2
        fi
fi

# ---- 検出ルール 2a: --no-verify ---- (BLOCK)
case "$CMD" in
    *"--no-verify"*)
        if [ "${ODD_ALLOW_NO_VERIFY:-0}" = "1" ]; then
            warn "--no-verify (allowed via ODD_ALLOW_NO_VERIFY=1)"
        else
            cat >&2 << 'BLOCK_NO_VERIFY'
[ODD kill switch] --no-verify is blocked.

Reason: bypassing pre-commit / pre-push hooks disables automated lint / format / test checks.
        Also forbidden by safety.md.

Options:
  1. Fix the root cause of the hook failure (recommended)
  2. Manual execution by the user (hooks do not run for them)
  3. Temporary escape: ODD_ALLOW_NO_VERIFY=1 git commit ... / git push ...
BLOCK_NO_VERIFY
            exit 2
        fi
        ;;
esac

# ---- 検出ルール 2b: --force push ---- (BLOCK、--force-with-lease は除外)
# 判定本体はルール 1 のセグメントループ内（push セグメント限定で --force / -f を見る）。
# 旧実装は *"--force"* を全文 match していたため `git worktree remove --force` /
# `npm install --force` 等の push と無関係な --force を誤 block していた（2026-06-05 修正）。
if [ "$_force_push" = "1" ]; then
        if [ "${ODD_ALLOW_FORCE_PUSH:-0}" = "1" ]; then
            warn "force push (allowed via ODD_ALLOW_FORCE_PUSH=1)"
        else
            cat >&2 << 'BLOCK_FORCE_PUSH'
[ODD kill switch] force push (--force / -f) is blocked.

Reason: it rewrites remote history. Disasters include losing other people's commits, breaking CI/CD, and invalidating PRs.

Options:
  1. Use --force-with-lease (recommended; a safer force push that this hook allows)
  2. Manual execution by the user
  3. Temporary escape: ODD_ALLOW_FORCE_PUSH=1 git push --force ...
BLOCK_FORCE_PUSH
            exit 2
        fi
fi

# ---- 検出ルール 3: rm -rf / ~ $HOME 系 ---- (BLOCK)
# safety-guard / lint-guard でカバーされない横断 kill switch
# 削除先が "/" "~" "$HOME" 単体で終わる場合のみ検知（"/tmp/..." 等は除外）
# 引用符除去（rm -rf "/" 回避封鎖）+ 分割フラグ許容（rm -r -f /。2026-07-02 監査）
CMD_NOQ=$(printf '%s' "$CMD" | tr -d '\042\047')
if printf "%s" "$CMD_NOQ" | grep -E '\brm[[:space:]]+(-[rf]+[[:space:]]+)+(/|~|\$HOME)([[:space:]]|;|&|\||$)' >/dev/null 2>&1; then
    if [ "${ODD_ALLOW_RM_RF_ROOT:-0}" = "1" ]; then
        warn "rm -rf root/home (allowed via ODD_ALLOW_RM_RF_ROOT=1)"
    else
        cat >&2 << 'BLOCK_RM_RF'
[ODD kill switch] rm -rf (root / ~ / $HOME) is blocked.

Reason: unrecoverable. A single typo can wipe out massive amounts of data.

Options:
  1. Specify a concrete path (rm -rf /tmp/foo, rm -rf ./build etc. are allowed)
  2. Manual execution by the user (after final confirmation)
  3. Temporary escape: ODD_ALLOW_RM_RF_ROOT=1 rm -rf /target
BLOCK_RM_RF
        exit 2
    fi
fi

# ---- 検出ルール 5: rm が git 管理下ファイルを対象にしている ---- (WARN only, no block)
# 削除自体は git 履歴から復元できるため block しない。誤って追跡ファイルを rm した際の
# 気づきを与える通知のみ。判定できるのは literal パス（引用符除去後）のみ — グロブ
# （*?[）や変数展開（$）を含むトークンは判定不能として黙って通す（安全側の fail-open）。
if command -v git >/dev/null 2>&1; then
    _rm_hit=""
    _rm_segments=$(printf '%s\n' "$CMD" | tr ';&|' '\n')
    while IFS= read -r _rmseg; do
        _rmrest=${_rmseg#"${_rmseg%%[![:space:]]*}"}
        _rmfirst=${_rmrest%% *}
        case "$_rmfirst" in
            sudo|command|nohup|time)
                _rmrest=${_rmrest#"$_rmfirst"}
                _rmrest=${_rmrest#"${_rmrest%%[![:space:]]*}"}
                _rmfirst=${_rmrest%% *}
                ;;
        esac
        [ "$_rmfirst" = "rm" ] || continue
        _rmargs=${_rmrest#rm}
        for _rmtok in $_rmargs; do
            case "$_rmtok" in
                -*) continue ;;
                *'*'*|*'?'*|*'['*|*'$'*) continue ;;
            esac
            _rmtok_noq=$(printf '%s' "$_rmtok" | tr -d '\042\047')
            [ -z "$_rmtok_noq" ] && continue
            if git -C "$HOOK_CWD" ls-files --error-unmatch -- "$_rmtok_noq" >/dev/null 2>&1; then
                _rm_hit="$_rmtok_noq"
            fi
        done
    done <<KILL_SWITCH_RM_SEGMENTS
$_rm_segments
KILL_SWITCH_RM_SEGMENTS
    if [ -n "$_rm_hit" ]; then
        warn "rm targets a git-tracked file ($_rm_hit). Deletion is recoverable from git history (checkout/reset), but double-check this was intentional. This is a warning only; the command was not blocked."
    fi
fi

# 注記: 以下は別 hook で block 済みのため当ファイルでは検出しない:
#   .env 生読み / printenv / bash -x → safety-guard.sh (exit 2 block, v5.21.26 で最小復活)
#   lockfile / dist|build|node_modules の Write|Edit → lint-guard.sh (exit 2 block)

# 警告のみ。常に exit 0 で通す。
exit 0
