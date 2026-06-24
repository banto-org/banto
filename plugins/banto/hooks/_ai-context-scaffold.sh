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

# store 解決を検知し、未解決なら**黙って作らず**対話ブートストラップを 1 回だけ促す（A1）。
# repo 側（local .ai-context / .gitignore）にも store 側にも一切書かない（resolver hit で
# 登録済みなら skeleton を冪等確保するだけ。未登録なら prompt のみ・mkdir/登録はしない）。
# Usage: _ai_context_scaffold <CWD>
# 戻り値: 0=成功（登録済み skeleton 確保 or ブートストラップ案内 or ガードによるスキップ）、1=引数不正
# stdout: ブートストラップ案内（marker で 1 回だけ）or なし
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
    # 移行は人間ゲート（/ai-context migrate / SessionStart の 1 行提案）。
    if [ -d "$_ais_top/.ai-context" ]; then
        unset _ais_cwd _ais_top
        return 0
    fi

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

    # 登録済み（mapping / worktree / remote のいずれかで resolver hit）なら store 側
    # skeleton を冪等に確保するだけ。**未登録なら一切書かず**ブートストラップを促す（A1）。
    _ais_dir=""
    if [ -f "$_AIS_SCRIPTS_DIR/resolve-store-path.sh" ]; then
        _ais_dir=$(sh "$_AIS_SCRIPTS_DIR/resolve-store-path.sh" --store-dir "$_ais_top" 2>/dev/null) || _ais_dir=""
    fi

    if [ -n "$_ais_dir" ]; then
        # 登録済み: store 側 skeleton（idempotent。バケットは従来と同一）
        mkdir -p \
            "$_ais_dir/decisions" \
            "$_ais_dir/docs/research" \
            "$_ais_dir/docs/knowledges/drafts" \
            "$_ais_dir/sessions" \
            "$_ais_dir/tasks/old" \
            "$_ais_dir/workspaces" \
            2>/dev/null
        unset _ais_cwd _ais_top _ais_dir
        return 0
    fi

    # === ローカルのみ退避（option c / BANTO_BOOTSTRAP_LOCAL=1）: GitHub を使わず
    #     ローカル store だけ用意してこの repo を登録する（明示オプトインのみ。bootstrap
    #     対話のローカル退避 = SKILL.md の「store ブートストラップ」option 3 から呼ばれる）。
    if [ "${BANTO_BOOTSTRAP_LOCAL:-0}" = "1" ]; then
        _ais_root=$(_ai_context_store_root)
        _ais_map="${AI_CONTEXT_MAPPING:-$_ais_root/.mapping.json}"
        mkdir -p "$_ais_root" 2>/dev/null || { unset _ais_cwd _ais_top _ais_dir _ais_root _ais_map; return 0; }
        [ -f "$_ais_root/.ai-context-store" ] || touch "$_ais_root/.ai-context-store" 2>/dev/null
        if [ ! -f "$_ais_map" ]; then
            printf '{\n  "version": 2,\n  "store_root": "%s",\n  "projects": {}\n}\n' "$_ais_root" > "$_ais_map" 2>/dev/null
        fi
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
        _ais_dir=$(_ai_context_derive_dir "$_ais_top")
        _ais_proj=$(basename "$_ais_dir")
        if jq --arg top "$_ais_top" --arg p "$_ais_proj" \
              '.projects[$top] = {"project": $p}' "$_ais_map" > "$_ais_map.tmp" 2>/dev/null; then
            mv "$_ais_map.tmp" "$_ais_map"
        else
            rm -f "$_ais_map.tmp" 2>/dev/null
            unset _ais_cwd _ais_top _ais_dir _ais_root _ais_map _ais_proj; return 0
        fi
        mkdir -p \
            "$_ais_dir/decisions" \
            "$_ais_dir/docs/research" \
            "$_ais_dir/docs/knowledges/drafts" \
            "$_ais_dir/sessions" \
            "$_ais_dir/tasks/old" \
            "$_ais_dir/workspaces" \
            2>/dev/null
        echo "[AI Context] Registered this repo in a LOCAL-only central store (no GitHub). Knowledge base: $_ais_dir (the repo itself stays clean)."
        unset _ais_cwd _ais_top _ais_dir _ais_root _ais_map _ais_proj
        return 0
    fi

    # === 未登録（store 未解決）: 黙って作らず、対話ブートストラップを 1 回だけ促す（A1） ===
    # marker は user-scope（store 側に project dir を作らないため）。toplevel を slug 化して
    # ~/.claude/banto-bootstrap-asked/<slug> に置き、二度と nag しない。
    # fail-open: marker 書込み失敗でも処理を止めない（毎回出ても害は告知のみ）。
    _ais_asked_dir="$HOME/.claude/banto-bootstrap-asked"
    _ais_slug=$(printf '%s' "$_ais_top" | sed 's#[^A-Za-z0-9._-]#_#g')
    _ais_marker="$_ais_asked_dir/$_ais_slug"
    if [ -f "$_ais_marker" ]; then
        unset _ais_cwd _ais_top _ais_dir _ais_asked_dir _ais_slug _ais_marker
        return 0
    fi
    mkdir -p "$_ais_asked_dir" 2>/dev/null
    touch "$_ais_marker" 2>/dev/null || true
    printf '%s\n' "[AI Context - store 未セットアップ] このプロジェクトはまだ中央 ai-context-store に登録されていません（黙って作りません）。次のブートストラップ対話を進めてください:"
    printf '%s\n' "  (a) 既に GitHub に ai-context-store がありますか？ あれば repo（org/name）を教えてください → 登録します。"
    printf '%s\n' "  (b) 無ければ作成しますか？ どの org（または GitHub ユーザー名）に置きますか？ → 作成します。"
    printf '%s\n' "  (c) ローカルのみで使う退避も選べます（GitHub を使わない）。"
    printf '%s\n' "  → 進め方は ai-context skill の「store ブートストラップ」に従う（/ai-context bootstrap でも開始可能）。"
    printf '%s\n' ""
    unset _ais_cwd _ais_top _ais_dir _ais_asked_dir _ais_slug _ais_marker
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
