#!/bin/sh
# harness-setup.sh — Banto ユーザーレベル・ハーネスの決定論セットアップ
#
# プラグインマニフェストがネイティブにできないこと（~/.claude/rules への配置・settings.json の
# 改変・中央ストア init）を一発で冪等にセットアップする。init-harness skill の置き換え:
# 決定論的に書ける手順を skill（モデル解釈）に持たせるのは CONCEPT「enforcement は hook/script」
# に反するため、script に降ろした。CLAUDE.md のプロジェクト分析生成はネイティブ /init に委譲する
# （本 script は触らない）。
#
# モード:
#   --plan            変更内容を提示するだけ（適用しない）。settings.json/rules は読み取りのみ。
#   (引数なし)        ユーザーレベルを適用（~/.claude/rules・settings.json・~/ai-context-store）
#   --project [DIR]   プロジェクトの .claude/rules/ に templates/rules/ を配置（DIR 既定 = PWD）
#
# 公式プラグイン（security-guidance / code-review）の自動 install は**行わない**: banto は
# これらを機能的に一切呼ばず（実 enforcement は banto 自身の hooks）、過去に委譲前提で自前
# ガードを消して空白化した事故がある（v5.16.0 → v5.21.26 復活）。レビューが要るユーザーには
# 末尾で任意案内するに留める。
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
RULES_SRC="$PLUGIN_ROOT/templates/rules"
LANG_FILE="$HOME/.claude/banto-language"

MODE=user
PROJECT_DIR=$PWD
case "${1:-}" in
    --plan)    MODE=plan ;;
    --project) MODE=project; [ -n "${2:-}" ] && PROJECT_DIR=$2 ;;
    "")        ;;
    *) echo "usage: harness-setup.sh [--plan | --project [DIR]]"; exit 2 ;;
esac

# 現在の Banto 言語（set-language が永続化）。未設定なら公開既定の英語。
banto_lang() { [ -f "$LANG_FILE" ] && tr -d ' \n' < "$LANG_FILE" || echo en; }
LANG_NOW=$(banto_lang)
# 注: 日本語（多バイト）テキストに隣接する展開は ${LANG_NOW} とブレースで囲む（名前解釈の崩れ回避）

# writing-ja は言語固有かつ opt-in ルール: JA かつ preference=on のときだけ配置対象に含める。
# preference は ~/.claude/banto-writing-ja（writing-ja-toggle.sh が永続化。無し = off）。
# それ以外の rules は i18n 管理: 正本は i18n/<lang>/templates/rules/ にあり、set-language /
# i18n-reconcile が選択言語を active の templates/rules/ へ materialize 済み。ここはその
# active コピーを配るだけなので、配布物は常に選択言語版になる（ここに言語分岐は無い）。
WJ_FILE=${BANTO_WJ_FILE:-$HOME/.claude/banto-writing-ja}
wj_pref() { [ -f "$WJ_FILE" ] && tr -d ' \n' < "$WJ_FILE" || echo off; }
is_lang_specific() { [ "$(basename "$1")" = "writing-ja.md" ]; }
want_rule() {
    is_lang_specific "$1" || return 0          # i18n 管理ルール → 常に対象（中身は選択言語版）
    [ "${LANG_NOW}" = "ja" ] && [ "$(wj_pref)" = on ]  # 言語固有 → ja かつ opt-in のときだけ
}

# ── ルール配置（copy。差分があっても上書きせず報告。個人カスタムを保護）──────────
deploy_rules() {  # $1 = dest dir, $2 = plan|apply
    dest=$1; act=$2
    [ "$act" = apply ] && mkdir -p "$dest"
    for f in "$RULES_SRC"/*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f"); target="$dest/$base"
        if ! want_rule "$f"; then
            printf '    skip (JA 専用 opt-in: lang=%s, writing-ja=%s): %s\n' "${LANG_NOW}" "$(wj_pref)" "$base"
            continue
        fi
        if [ ! -e "$target" ]; then
            printf '    + %s\n' "$base"
            if [ "$act" = apply ]; then cp "$f" "$target"; fi
        elif cmp -s "$f" "$target"; then
            printf '    = %s (同一・skip)\n' "$base"
        else
            printf '    ! %s (差分あり・保護のため skip。手動 diff 推奨)\n' "$base"
        fi
    done
}

# ── settings.json 冪等マージ（その他を保持・hooks には絶対触れない）─────────────
merge_settings() {  # $1 = plan|apply
    act=$1; sj="$HOME/.claude/settings.json"
    command -v jq >/dev/null 2>&1 || { echo "    ⚠ jq 不在: settings.json マージ（statusLine 配線含む）を skip。jq を入れて再実行するまで statusline は表示されない"; return 0; }
    [ -f "$sj" ] || { [ "$act" = apply ] && { mkdir -p "$HOME/.claude"; echo '{}' > "$sj"; }; }
    # ours=banto の token-monitor（壊れた旧パスでも修復対象）/ custom=ユーザー独自（保護）/ none=未設定
    sl_kind=$(jq -r '
      if (.statusLine|type)=="object" and (((.statusLine.command // "")|test("token-monitor"))) then "ours"
      elif .statusLine then "custom" else "none" end' "$sj" 2>/dev/null || echo none)
    echo "    permissions.allow += mcp__playwright__* / mcp__ide__* / Bash(git -C ~/ai-context-store:*)"
    echo "                       + Bash(git push:*) / Bash(gh pr create:*)（会話承認で実行可 — main 直 push / force push / 未承認 PR 作成は hook が決定論で block）"
    echo "    permissions.deny  += AskUserQuestion（テキスト対話ポリシー）"
    echo "    env.CLAUDE_CODE_DISABLE_AUTO_MEMORY = \"1\""
    have_sb=$(jq -r 'if .sandbox then "yes" else "no" end' "$sj" 2>/dev/null || echo no)
    if [ "$have_sb" = yes ]; then
        echo "    sandbox: 既存設定を保持（skip）"
    else
        echo "    sandbox: 無効状態の hardening ブロックを配置（opt-in・既定 off）"
        echo "             有効化は settings.json の sandbox.enabled=true（bash の OS サンドボックス＝"
        echo "             egress-guard hook と二層安全弁。denyRead で秘匿 + allowedDomains で egress 制限）"
        echo "             failIfUnavailable=false（Windows/WSL1 で起動拒否を避ける）"
    fi
    case "$sl_kind" in
        ours)   echo "    statusLine: banto の token-monitor を正規パス（絶対）へ修復/更新" ;;
        custom) echo "    statusLine: 既存のカスタム設定を保持（skip）" ;;
        *)      echo "    statusLine = token-monitor.sh を配線" ;;
    esac
    # autoUpdate: サードパーティ marketplace は既定 off のため、banto-marketplace に autoUpdate=true を
    # 設定してリリース追従を自動化（source は known_marketplaces.json の実登録を優先して保持）
    km="$HOME/.claude/plugins/known_marketplaces.json"
    km_src='{"source":"github","repo":"banto-org/banto"}'
    if [ -f "$km" ]; then
        found=$(jq -c '.["banto-marketplace"].source // empty' "$km" 2>/dev/null)
        [ -n "$found" ] && km_src=$found
    fi
    echo "    extraKnownMarketplaces.banto-marketplace.autoUpdate = true（リリース自動追従）"
    [ "$act" = apply ] || return 0
    tmp=$(mktemp)
    jq --argjson kmsrc "$km_src" --arg slcmd "$HOME/.claude/statuslines/token-monitor.sh" '
      .extraKnownMarketplaces["banto-marketplace"] =
        ((.extraKnownMarketplaces["banto-marketplace"] // {source: $kmsrc}) + {autoUpdate: true}) |
      .permissions.allow = ((.permissions.allow // []) + [
        "mcp__playwright__*", "mcp__ide__*",
        "Bash(git -C ~/ai-context-store:*)",
        "Bash(git push:*)", "Bash(gh pr create:*)"
      ] | unique) |
      .permissions.deny = ((.permissions.deny // []) + ["AskUserQuestion"] | unique) |
      .env.CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1" |
      (if .sandbox then . else
        .sandbox = {
          enabled: false,
          failIfUnavailable: false,
          filesystem: { denyRead: [
            "~/.ssh", "~/.aws", "~/.gnupg", "~/.config/gcloud",
            "~/.claude/banto-name-registry"
          ] },
          network: { allowedDomains: [
            "github.com", "*.github.com", "registry.npmjs.org", "*.npmjs.org",
            "pypi.org", "files.pythonhosted.org", "api.anthropic.com", "*.anthropic.com"
          ] }
        }
      end) |
      (if (.statusLine|type)=="object" and (((.statusLine.command // "")|test("token-monitor"))) then
        .statusLine = {type:"command", command:$slcmd, padding:0, refreshInterval:10}
      elif .statusLine then .
      else
        .statusLine = {type:"command", command:$slcmd, padding:0, refreshInterval:10}
      end)
    ' "$sj" > "$tmp" && mv "$tmp" "$sj"
    # statusline 本体
    mkdir -p "$HOME/.claude/statuslines"
    cp "$PLUGIN_ROOT/statuslines/token-monitor.sh" "$HOME/.claude/statuslines/" \
        && chmod +x "$HOME/.claude/statuslines/token-monitor.sh"
}

# ── 中央ナレッジストア init（store-first・ユーザーデータなので冪等に warm-up）──────
init_store() {  # $1 = plan|apply
    act=$1; root=${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}
    if [ -e "$root/.ai-context-store" ]; then
        echo "    = ストア既存: $root"
    else
        echo "    + ストア init: ${root}（+ .ai-context-store マーカー）"
        if [ "$act" = apply ]; then mkdir -p "$root" && touch "$root/.ai-context-store"; fi
    fi
}

case "$MODE" in
  project)
    echo "[harness-setup --project] $PROJECT_DIR/.claude/rules/ に templates/rules/ を配置（言語=${LANG_NOW}）"
    deploy_rules "$PROJECT_DIR/.claude/rules" apply
    # 永続タスクリスト id（CLAUDE_CODE_TASK_LIST_ID）を ensure（DRY: hook を直接呼ぶ）。
    # hook は cwd を stdin payload か $PWD から取り fail-open。非 git なら no-op。
    echo "  永続タスクリスト ensure:"
    ( cd "$PROJECT_DIR" 2>/dev/null && sh "$PLUGIN_ROOT/hooks/task-list-id-ensure.sh" </dev/null ) || true
    echo "完了。CLAUDE.md のプロジェクト分析生成はネイティブ /init に委譲する。"
    ;;
  plan)
    echo "[harness-setup --plan] 適用される変更（言語=${LANG_NOW}・適用はしない）:"
    echo "  ルール → ~/.claude/rules/"; deploy_rules "$HOME/.claude/rules" plan
    echo "  settings.json マージ:";     merge_settings plan
    echo "  中央ストア:";               init_store plan
    echo "  ※ 公式プラグインの自動 install は行わない（機能依存なし）"
    ;;
  user)
    echo "[harness-setup] ユーザーレベル・ハーネスを適用（言語=${LANG_NOW}）"
    echo "  ルール → ~/.claude/rules/"; deploy_rules "$HOME/.claude/rules" apply
    echo "  settings.json マージ:";     merge_settings apply
    echo "  中央ストア:";               init_store apply
    cat <<'EOF'
  ── 任意（押しつけなし）──
  - PII / 内部名ガード: cp "<plugin>/templates/pii/name-registry.example" ~/.claude/banto-name-registry
  - コードレビュー / セキュリティ: ネイティブの /code-review・/security-review が利用可能
    （banto は再実装しない。自動 install もしない — 必要なら各自で導入）
EOF
    if command -v git-town >/dev/null 2>&1; then
        echo '  - git-town: 導入済み（3 階層の親子追跡 + 自動 sync が有効）'
    else
        echo '  - git-town 未導入: ws は degraded モードで動作する（3 階層の親子追跡と自動 sync のみ無効）。フル機能には `brew install git-town`'
    fi
    cat <<'EOF'
  完了。Claude Code を再起動すると新しいルール / 設定が反映される。
EOF
    ;;
esac
