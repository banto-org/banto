#!/bin/sh
# ai-context-prune-auto.sh — SessionStart hook: prune を自動化（軽量 housekeeping のみ）
#
# 目的（spec 2026-06-24 ai-context-subsystem-redesign）: 旧 `/ai-context prune` 手動サブコマンドを
#   廃止し、**安全な掃除だけ**を SessionStart で自動化する。破壊的な撤去（実データを持つ legacy
#   `.ai-context/` の削除・誤生成 dir の移動）は従来どおり人間ゲート（spec: prune の B/C は確認必須）。
#   自動化するのは「中身を失わない」掃除に限定する:
#     ・base 配下の空ディレクトリ（中身ゼロ）の除去 -- skeleton 固定 dir は残す
#     ・base/tmp/ 配下の 7 日より古いファイル GC
#     ・完了 Phase アーカイブ（tasks/old/・workspaces/*/tasks-old/）の 90 日より古いものを GC
#
# 出力契約 (SessionStart): stdout はコンテキストに追加される。掃除は静かに行い、件数があれば 1 行。
#   常に exit 0（never block）。
#
# 実行頻度: 日次 marker で 1 日 1 回に絞る（SessionStart は頻繁に走るため）。
# fail-open: jq / base 不在 → 静かに exit 0。
# POSIX互換: macOS / Linux / WSL
set -u

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || echo '{}')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
PATHS="$PLUGIN_ROOT/scripts/_ai-context-paths.sh"
[ -f "$PATHS" ] || exit 0

BASE=$(sh "$PATHS" --resolve "$CWD" 2>/dev/null)
[ -n "$BASE" ] || exit 0
[ -d "$BASE" ] || exit 0

# 安全ガード: base が HOME / FS ルート等でないこと（万一の解決ミスで掃除を暴発させない）。
case "$BASE" in
    ''|"$HOME"|/) exit 0 ;;
esac

# 日次 marker（base ごと）で 1 日 1 回に絞る。base を slug 化して衝突回避。
BASE_SLUG=$(printf '%s' "$BASE" | sed 's#[^A-Za-z0-9._-]#_#g')
MARKER="${TMPDIR:-/tmp}/banto-prune-${BASE_SLUG}-$(date +%Y%m%d 2>/dev/null || echo d)"
[ -f "$MARKER" ] && exit 0
touch "$MARKER" 2>/dev/null || true

REMOVED=0

# (1) base/tmp/ 配下の 7 日より古いファイルを GC（中身は揮発キャッシュ扱い）。
if [ -d "$BASE/tmp" ]; then
    _n=$(find "$BASE/tmp" -type f -mtime +7 2>/dev/null | grep -c .)
    if [ "$_n" -gt 0 ]; then
        find "$BASE/tmp" -type f -mtime +7 -delete 2>/dev/null
        REMOVED=$(( REMOVED + _n ))
    fi
fi

# (2) 完了 Phase アーカイブの 90 日より古いものを GC（新 layout tasks-old/ + legacy tasks/old/）。
for _ad in "$BASE/tasks/old" "$BASE"/workspaces/*/*/tasks-old; do
    [ -d "$_ad" ] || continue
    _n=$(find "$_ad" -type f -mtime +90 2>/dev/null | grep -c .)
    if [ "$_n" -gt 0 ]; then
        find "$_ad" -type f -mtime +90 -delete 2>/dev/null
        REMOVED=$(( REMOVED + _n ))
    fi
done

# (3) base 配下の空ディレクトリを除去（skeleton 固定 dir は残す）。
#     破壊的でない（中身ゼロのため）。base 直下は対象外（誤って base を畳まない）。
KEEP_RE='/(decisions|docs|docs/research|docs/knowledges|docs/knowledges/drafts|sessions|tasks|tasks/old|workspaces|lessons|meta)$'
PRUNED_DIRS=0
# 末端から畳む。空でなくなった親は次回以降に拾う。base 自身は対象外（mindepth 1）。
find "$BASE" -mindepth 1 -type d -empty 2>/dev/null | while IFS= read -r d; do
    rel="${d#"$BASE"}"
    case "$rel" in
        */.git|*/.git/*) continue ;;
    esac
    # skeleton 固定 dir は空でも残す（次セッションで使うため）。
    if printf '%s' "$rel" | grep -qE "$KEEP_RE"; then
        continue
    fi
    rmdir "$d" 2>/dev/null && PRUNED_DIRS=$(( PRUNED_DIRS + 1 ))
done

# subshell（while パイプ）の PRUNED_DIRS は親に伝わらないため、報告は REMOVED のみ簡潔に。
if [ "$REMOVED" -gt 0 ]; then
    echo "[AI Context] prune-auto: GC'd ${REMOVED} stale tmp/archive file(s) (safe housekeeping; destructive prune stays manual)."
    echo ""
fi
exit 0
