#!/bin/sh
# AI Context Scaffold — 共通関数（source 専用、直接実行しない）
# store-first（spec 2026-06-11_store-first-architecture）: repo 内 .ai-context/ は生成しない。
# 新責務: store root 確保 → project dir derive + mapping 登録 → store 側 skeleton 生成。
# CLI hook / skill 本体 / IDE-Desktop fallback の共通エントリ。
# POSIX互換: macOS / Linux / WSL
#
# 環境変数:
#   BANTO_AI_CONTEXT_CENTRAL_ONLY … 5.30.0 以降 no-op（常時 store-first。後方互換のため読み捨て）
#   AI_CONTEXT_STORE_ROOT / AI_CONTEXT_MAPPING … store root / mapping の上書き（テスト・チーム運用）

# 使い方:
#   source: . _ai-context-scaffold.sh  → 関数 _ai_context_scaffold が定義される
#   直接実行: _ai-context-scaffold.sh [CWD]  → 引数（省略時 $PWD）に対して scaffold を実行
#   skill / IDE / Desktop fallback はこのスクリプトを直接実行する

# resolver / paths helper の場所（source 時の $0 は呼び出し元 = hooks/ か scripts/ 配下）
_AIS_SCRIPTS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$_AIS_SCRIPTS_DIR" ] && _AIS_SCRIPTS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)

# CWD を処理対象外とすべきか判定する（.ai-context を作らず hook をスキップ）
# (1) 非プロジェクト場所ガード: HOME 直下 / FS ルート / git work tree 外（denylist 非依存の deterministic guard）
# (2) denylist: ~/.claude/banto-ignore （1 行 1 パス、# コメント可、~/ → $HOME 展開）
# 戻り値: 0=スキップすべき、1=処理続行
_ai_context_should_skip() {
    _aiss_cwd="$1"
    _aiss_cwd_norm="${_aiss_cwd%/}"

    # (1) 非プロジェクト場所には .ai-context を作らない（HOME / ルートでの誤生成を防ぐ）。
    #     非 git の新規プロジェクトは /init + harness-setup.sh で明示 scaffold する。
    case "$_aiss_cwd_norm" in
        ''|"$HOME"|/) return 0 ;;
    esac
    if command -v git >/dev/null 2>&1 \
       && ! git -C "$_aiss_cwd_norm" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 0
    fi

    # (2) denylist ファイル（任意）にマッチするか
    _aiss_ignore="${BANTO_IGNORE_FILE:-$HOME/.claude/banto-ignore}"
    [ ! -f "$_aiss_ignore" ] && return 1

    while IFS= read -r _aiss_line || [ -n "$_aiss_line" ]; do
        # コメント・空行をスキップ
        case "$_aiss_line" in
            ''|\#*) continue ;;
        esac
        # 前後の空白を削除（タブ含む）
        _aiss_line=$(printf '%s' "$_aiss_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -z "$_aiss_line" ] && continue
        # 行末コメントを削除（# の前にスペース必須）
        _aiss_line=$(printf '%s' "$_aiss_line" | sed -e 's/[[:space:]]\{1,\}#.*$//')
        # ~ を $HOME に展開（${var#~/} は zsh 等で意図通り動かないので sed 経由）
        case "$_aiss_line" in
            '~') _aiss_line="$HOME" ;;
            '~/'*) _aiss_line=$(printf '%s' "$_aiss_line" | sed "s|^~/|$HOME/|") ;;
        esac
        # 末尾スラッシュを正規化
        _aiss_line="${_aiss_line%/}"
        [ -z "$_aiss_line" ] && continue
        # プレフィックスマッチ（完全一致 or サブディレクトリ）
        case "$_aiss_cwd_norm" in
            "$_aiss_line"|"$_aiss_line"/*)
                unset _aiss_cwd _aiss_cwd_norm _aiss_ignore _aiss_line
                return 0
                ;;
        esac
    done < "$_aiss_ignore"

    unset _aiss_cwd _aiss_cwd_norm _aiss_ignore _aiss_line
    return 1
}

# store skeleton（バケット）を冪等生成する。central / ai-context-local どちらの root でも同一構成。
# learnings/（教訓 scope。既存フックが書込/読込）と meta/（store 自身のメタ: マッピング/索引/health）を含む（spec 2026-06-24）。
_ai_context_skeleton() {
    mkdir -p \
        "$1/decisions" \
        "$1/docs/research" \
        "$1/docs/knowledges/drafts" \
        "$1/sessions" \
        "$1/tasks/old" \
        "$1/workspaces" \
        "$1/learnings" \
        "$1/meta" \
        2>/dev/null
}

# legacy な in-repo .ai-context/ を store base へ**非破壊コピー**で自動移行する
# （decision 2026-07-08 abolish-in-repo-ai-context: in-repo .ai-context の完全廃止）。
# 同名は上書きせず・元 .ai-context/ は消さない（削除は人手）。再生成物 / VCS / per-machine は除外。
# 完了マーカーは store 側（<base>/meta/.migrated-from-inrepo）に置き repo を汚さない。1 回だけ実行。
# Usage: _ai_context_migrate_inrepo <repo_top> <base>
_ai_context_migrate_inrepo() {
    _aim_top="$1"
    _aim_base="$2"
    [ -n "$_aim_top" ] && [ -n "$_aim_base" ] || { unset _aim_top _aim_base; return 0; }
    [ -d "$_aim_top/.ai-context" ] || { unset _aim_top _aim_base; return 0; }
    _aim_marker="$_aim_base/meta/.migrated-from-inrepo"
    [ -f "$_aim_marker" ] && { unset _aim_top _aim_base _aim_marker; return 0; }  # 移行済み

    # 非破壊コピー（除外は migrate-to-store.sh と同一: 再生成物 / VCS / per-machine / .gitignore）
    ( cd "$_aim_top/.ai-context" 2>/dev/null || exit 0
      find . -type f 2>/dev/null | while IFS= read -r _rel; do
          _rel=${_rel#./}
          case "$_rel" in
              project-index/*|full-index/*|*-combined.txt|.obsidian/*|*/.obsidian/*|.git/*|*/.git/*|.DS_Store|*/.DS_Store|.gitignore) continue ;;
          esac
          _dst="$_aim_base/$_rel"
          [ -f "$_dst" ] && continue          # 同名は上書きしない
          mkdir -p "$(dirname "$_dst")" 2>/dev/null
          cp "$_aim_top/.ai-context/$_rel" "$_dst" 2>/dev/null
      done )

    mkdir -p "$_aim_base/meta" 2>/dev/null
    {
        echo "migrated from in-repo .ai-context at $(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
        echo "source: $_aim_top/.ai-context"
    } > "$_aim_marker" 2>/dev/null
    echo "[AI Context] Migrated in-repo .ai-context/ → $_aim_base (non-destructive copy; originals kept). The in-repo .ai-context/ is now unused and can be deleted after you verify the store copy."
    unset _aim_top _aim_base _aim_marker _rel _dst
}

# store 解決を検知し、未解決なら**ブロックせず**ローカル仮置き（~/ai-context-local/<project>/）を
# 作成・登録して 1 行だけ通知する（spec 2026-06-24 ai-context-subsystem-redesign が A1 を上書き）。
# repo 側（local .ai-context / .gitignore）には一切書かない。central / local-store の resolver hit で
# 登録済みなら skeleton を冪等確保するだけ。未登録なら ai-context-local に作成 + 登録（local:false）。
# Usage: _ai_context_scaffold <CWD>
# 戻り値: 0=成功（登録済み skeleton 確保 or 仮ローカル作成 or ガードによるスキップ）、1=引数不正
# stdout: 仮ローカル作成の 1 行通知（marker で 1 回だけ）or なし
_ai_context_scaffold() {
    _ais_cwd="$1"
    [ -z "$_ais_cwd" ] && return 1
    [ ! -d "$_ais_cwd" ] && return 1

    # denylist / HOME / FS ルート / 非 git ならサイレントスキップ（store 側にも登録しない）
    if _ai_context_should_skip "$_ais_cwd"; then
        unset _ais_cwd
        return 0
    fi

    # git work-tree の root でのみ scaffold する。repo のサブディレクトリ（や dotfiles
    # 管理の $HOME 配下）で起動したセッションは「間違えて入ったフォルダ」の可能性が
    # あるため、store 側にも登録・生成しない（should_skip は hook 全体の gate なので
    # 注入系はサブディレクトリでも動き続ける。git 不在環境は toplevel を特定できない
    # ためスキップ = git は必須要件）。
    command -v git >/dev/null 2>&1 || { unset _ais_cwd; return 0; }
    _ais_top=$(git -C "$_ais_cwd" rev-parse --show-toplevel 2>/dev/null)
    _ais_phys=$(cd "$_ais_cwd" 2>/dev/null && pwd -P)
    if [ -z "$_ais_top" ] || [ "$_ais_top" != "$_ais_phys" ]; then
        unset _ais_cwd _ais_top _ais_phys
        return 0
    fi
    unset _ais_phys

    # in-repo .ai-context/ grandfather は 2026-07-08 廃止（decision abolish-in-repo-ai-context）。
    # 以前は「その場で尊重・store 登録しない」だったが、いまは通常どおり store base を解決・登録し、
    # 末尾で legacy .ai-context/ を store へ自動移行する（非破壊）。in-repo は参照しない。

    # mapping 解決には jq が必要（banto の必須要件。無ければ静かに何もしない＝fail-open）
    command -v jq >/dev/null 2>&1 || { unset _ais_cwd _ais_top; return 0; }

    # paths helper（derive / store_root）を未 source なら取り込む
    if ! command -v _ai_context_derive_dir >/dev/null 2>&1; then
        if [ -f "$_AIS_SCRIPTS_DIR/_ai-context-paths.sh" ]; then
            AI_PATHS="$_AIS_SCRIPTS_DIR/_ai-context-paths.sh"
            . "$AI_PATHS"
        fi
    fi
    command -v _ai_context_derive_dir >/dev/null 2>&1 || { unset _ais_cwd _ais_top; return 0; }

    # base を解決（各分岐は early-return せず _ais_dir に集約。末尾で skeleton + legacy 自動移行を共通実行）。
    _ais_dir=""
    # (a) 中央 store に登録済み（mapping / worktree / remote のいずれかで resolver hit）
    if [ -f "$_AIS_SCRIPTS_DIR/resolve-store-path.sh" ]; then
        _ais_dir=$(sh "$_AIS_SCRIPTS_DIR/resolve-store-path.sh" --store-dir "$_ais_top" 2>/dev/null) || _ais_dir=""
    fi
    # (b) ローカル仮置き store に登録済み（bootstrap 前 / local 固定）
    if [ -z "$_ais_dir" ] && command -v _ai_context_local_lookup >/dev/null 2>&1; then
        _ais_dir=$(_ai_context_local_lookup "$_ais_top") || _ais_dir=""
    fi
    # (c) 未登録: ブロックせず ~/ai-context-local/<project>/ を作成・登録（local:false）して 1 行通知
    #     spec 2026-06-24 ai-context-subsystem-redesign（A1 prompt-only を上書き）。GitHub backing は後追い:
    #     /ai-context bootstrap で本物 store へ移行、/ai-context local でローカル固定（mapping local:true）。
    #     repo 側には一切書かない（store-first）。fail-open: jq / mkdir 失敗で no-op。
    if [ -z "$_ais_dir" ]; then
        command -v _ai_context_local_root >/dev/null 2>&1 || { unset _ais_cwd _ais_top _ais_dir; return 0; }
        _ais_root=$(_ai_context_local_root)
        _ais_map=$(_ai_context_local_mapping)
        mkdir -p "$_ais_root" 2>/dev/null || { unset _ais_cwd _ais_top _ais_dir _ais_root _ais_map; return 0; }
        [ -f "$_ais_root/.ai-context-local" ] || touch "$_ais_root/.ai-context-local" 2>/dev/null
        if [ ! -f "$_ais_map" ]; then
            printf '{\n  "version": 2,\n  "store_root": "%s",\n  "projects": {}\n}\n' "$_ais_root" > "$_ais_map" 2>/dev/null
        fi
        if [ ! -f "$_ais_root/.gitignore" ]; then
            cat > "$_ais_root/.gitignore" <<'AI_LOCAL_GITIGNORE'
.mapping.json
project-index/
full-index/
*-combined.txt
sessions-cache/
tmp/
sessions/
drafts/
.obsidian/
.DS_Store
\[Memo\]*
WORKSPACE.md
WORKSPACE-refs.md
DASHBOARD.md
AI_LOCAL_GITIGNORE
        fi
        # derive はローカル root に対して算出する（衝突時 -2/-3 suffix。AI_CONTEXT_STORE_ROOT /
        # AI_CONTEXT_MAPPING をローカル側へ一時的に向けて derive を流用する＝サブシェルで隔離）。
        _ais_proj=$(
            AI_CONTEXT_STORE_ROOT="$_ais_root" AI_CONTEXT_MAPPING="$_ais_map" \
            _ai_context_derive_dir "$_ais_top"
        )
        _ais_proj=$(basename "$_ais_proj")
        _ais_dir="$_ais_root/$_ais_proj"
        if jq --arg top "$_ais_top" --arg p "$_ais_proj" \
              '.projects[$top] = {"project": $p, "local": false}' "$_ais_map" > "$_ais_map.tmp" 2>/dev/null; then
            mv "$_ais_map.tmp" "$_ais_map"
        else
            rm -f "$_ais_map.tmp" 2>/dev/null
            unset _ais_cwd _ais_top _ais_dir _ais_root _ais_map _ais_proj; return 0
        fi
        # 通知は user-scope marker で 1 回だけ（毎回 nag しない。fail-open）。
        _ais_asked_dir="$HOME/.claude/banto-bootstrap-asked"
        _ais_slug=$(printf '%s' "$_ais_top" | sed 's#[^A-Za-z0-9._-]#_#g')
        _ais_marker="$_ais_asked_dir/$_ais_slug"
        if [ ! -f "$_ais_marker" ]; then
            mkdir -p "$_ais_asked_dir" 2>/dev/null
            touch "$_ais_marker" 2>/dev/null || true
            echo "[AI Context] Using a temporary local store at $_ais_dir (the repo stays clean). Run /ai-context bootstrap to back it with GitHub, or /ai-context local to keep it local-only."
        fi
    fi

    # 共通末尾: skeleton 冪等生成 + legacy in-repo .ai-context/ の自動移行（非破壊・store 側マーカーで 1 回だけ）
    [ -n "$_ais_dir" ] || { unset _ais_cwd _ais_top _ais_dir _ais_root _ais_map _ais_proj _ais_asked_dir _ais_slug _ais_marker; return 0; }
    _ai_context_skeleton "$_ais_dir"
    _ai_context_migrate_inrepo "$_ais_top" "$_ais_dir"
    unset _ais_cwd _ais_top _ais_dir _ais_root _ais_map _ais_proj _ais_asked_dir _ais_slug _ais_marker
    return 0
}

# 直接実行された場合（source されていない場合）は scaffold を実行。
# store-first では scaffold 自体が store 側にしか書かないため、旧 central gate は不要
# （登録済み repo は resolver hit で skeleton 確保のみ＝冪等。hook 不在環境
#   = Claude Desktop / IDE 拡張の fallback もこの 1 本で安全）。
case "${0##*/}" in
    _ai-context-scaffold.sh|ai-context-scaffold)
        _ai_context_scaffold "${1:-$PWD}"
        exit $?
        ;;
esac
