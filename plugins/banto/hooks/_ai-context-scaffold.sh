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

# store root 確保 → project dir 解決（resolver hit / derive + mapping 登録）→ store 側 skeleton。
# repo 側（local .ai-context / .gitignore）には一切書かない。
# Usage: _ai_context_scaffold <CWD>
# 戻り値: 0=成功（登録済み or 新規登録 or ガードによるスキップ）、1=引数不正
# stdout: 初回登録時のみメッセージを 1 行出力
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

    # grandfather: 既存の repo 内 .ai-context/ はそのまま尊重（store 登録しない）。
    # 移行は人間ゲート（migrate-to-store.sh / SessionStart の 1 行提案）。
    if [ -d "$_ais_top/.ai-context" ]; then
        unset _ais_cwd _ais_top
        return 0
    fi

    # mapping 登録・derive には jq が必要（banto の必須要件。無ければ静かに何もしない）
    command -v jq >/dev/null 2>&1 || { unset _ais_cwd _ais_top; return 0; }

    # paths helper（derive / store_root）を未 source なら取り込む
    if ! command -v _ai_context_derive_dir >/dev/null 2>&1; then
        if [ -f "$_AIS_SCRIPTS_DIR/_ai-context-paths.sh" ]; then
            AI_PATHS="$_AIS_SCRIPTS_DIR/_ai-context-paths.sh"
            . "$AI_PATHS"
        fi
    fi
    command -v _ai_context_derive_dir >/dev/null 2>&1 || { unset _ais_cwd _ais_top; return 0; }

    # store root を確保（初回必要時に自動作成: marker + .mapping.json + store 用 .gitignore）
    _ais_root=$(_ai_context_store_root)
    _ais_map="${AI_CONTEXT_MAPPING:-$_ais_root/.mapping.json}"
    mkdir -p "$_ais_root" 2>/dev/null || { unset _ais_cwd _ais_top _ais_root _ais_map; return 0; }
    [ -f "$_ais_root/.ai-context-store" ] || touch "$_ais_root/.ai-context-store" 2>/dev/null
    if [ ! -f "$_ais_map" ]; then
        printf '{\n  "version": 2,\n  "store_root": "%s",\n  "projects": {}\n}\n' "$_ais_root" > "$_ais_map" 2>/dev/null
    fi
    # store 用 .gitignore（store-init と同一パターン。git 化は store-init の明示操作のまま）
    if [ ! -f "$_ais_root/.gitignore" ]; then
        cat > "$_ais_root/.gitignore" <<'AI_STORE_GITIGNORE'
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
AI_STORE_GITIGNORE
    fi

    # project dir 解決: 登録済みなら resolver hit、未登録なら derive + mapping 登録
    _ais_dir=""
    _ais_registered=1
    if [ -f "$_AIS_SCRIPTS_DIR/resolve-store-path.sh" ]; then
        _ais_dir=$(sh "$_AIS_SCRIPTS_DIR/resolve-store-path.sh" --store-dir "$_ais_top" 2>/dev/null) || _ais_dir=""
    fi
    if [ -z "$_ais_dir" ]; then
        _ais_dir=$(_ai_context_derive_dir "$_ais_top")
        _ais_proj=$(basename "$_ais_dir")
        # mapping 登録（scaffold 時のみ。derive と同じ衝突判定なので決定論的に一致する）
        if jq --arg top "$_ais_top" --arg p "$_ais_proj" \
              '.projects[$top] = {"project": $p}' "$_ais_map" > "$_ais_map.tmp" 2>/dev/null; then
            mv "$_ais_map.tmp" "$_ais_map"
        else
            rm -f "$_ais_map.tmp" 2>/dev/null
            unset _ais_cwd _ais_top _ais_root _ais_map _ais_dir _ais_proj _ais_registered
            return 0
        fi
        _ais_registered=0
        unset _ais_proj
    fi

    # store 側 skeleton（idempotent。バケットは legacy scaffold と同一）
    mkdir -p \
        "$_ais_dir/decisions" \
        "$_ais_dir/docs/research" \
        "$_ais_dir/docs/knowledges/drafts" \
        "$_ais_dir/sessions" \
        "$_ais_dir/tasks/old" \
        "$_ais_dir/workspaces" \
        2>/dev/null

    # 初回登録時のみ通知（1 行）
    if [ "$_ais_registered" = "0" ]; then
        echo "[AI Context] Registered this repo in the central store. Knowledge base: $_ais_dir (the repo itself stays clean)."
        # 初回セットアップ確認（1 回だけ）。.setup-asked マーカーで二度と出さない。
        # fail-open: マーカー書込み失敗でも処理を止めない。
        if [ ! -f "$_ais_dir/.setup-asked" ]; then
            printf '%s\n' "[AI Context - 初回セットアップ] このプロジェクトを ai-context-store ($_ais_dir) に登録しました。2点ご確認ください:"
            printf '%s\n' "  (a) この store を git で commit/push しますか？（チーム共有/バックアップ用。不要なら「除外」と言えば ~/.claude/banto-ignore に登録し、以後このプロジェクトでは scaffold しません）"
            printf '%s\n' "  (b) CONCEPT（北極星）を CLAUDE.md に @import で常駐させますか？ no なら store の concept/CONCEPT.md に置き、SessionStart 注入で参照します（CLAUDE.md は触りません）。"
            touch "$_ais_dir/.setup-asked" 2>/dev/null || true
        fi
    fi

    unset _ais_cwd _ais_top _ais_root _ais_map _ais_dir _ais_registered
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
