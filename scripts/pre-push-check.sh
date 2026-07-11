#!/bin/sh
# pre-push-check.sh — banto repo の push 前自動検査（release-guard.sh R4 が push 時に実行する）。
#
# 規約: repo 直下 scripts/pre-push-check.sh に置かれた検査は release-guard hook が
# `git push` 前に自動実行し、非 0 なら push を block する（検査内容は repo が所有する）。
# 速度要件: hook timeout 内で完走すること（数秒以内）。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
fail=0

# 1. brand gate（tracked コードのみ・高速）
sh "$DIR/scripts/check-legacy-names.sh" --code || fail=1

# 2. 宣言 JSON の妥当性（壊れた plugin.json / hooks.json を push しない）
for f in "$DIR/plugins/banto/.claude-plugin/plugin.json" \
         "$DIR/.claude-plugin/marketplace.json" \
         "$DIR/plugins/banto/hooks/hooks.json"; do
    jq empty "$f" 2>/dev/null || { echo "JSON invalid: $f"; fail=1; }
done

# 2b. i18n: EN 生成物が JA canonical と同期しているか（ドリフトを push しない）
sh "$DIR/plugins/banto/scripts/i18n-sync-check.sh" || fail=1

# 2b'. i18n: active な skills/ + agents/ が i18n 正本と一致するか（materialized copy 直編集の検知）
sh "$DIR/plugins/banto/scripts/i18n-materialize-check.sh" || fail=1

# 2b''. i18n: EN が翻訳でなく漏れたノート/スタブに破損していないか（hash では見えない内容 sanity）
sh "$DIR/plugins/banto/scripts/i18n-en-sanity.sh" "$DIR" --strict || fail=1

# 2c. markdown リンクが解決するか（壊れた相対リンク / README の言語フリップを push しない）
sh "$DIR/scripts/check-md-links.sh" || fail=1

# 2d. hook 実行ビット（+x 漏れは Permission denied で hook が fail-open になる）
for f in "$DIR"/plugins/banto/hooks/*.sh; do
    [ -x "$f" ] || { echo "hook not executable (chmod +x needed): $f"; fail=1; }
done

# 3. version 宣言の一致（plugin.json = marketplace.json = CHANGELOG 先頭）
PJ=$(jq -r '.version' "$DIR/plugins/banto/.claude-plugin/plugin.json")
MK=$(jq -r '.plugins[0].version' "$DIR/.claude-plugin/marketplace.json")
CL=$(grep -oE '## \[?[0-9]+\.[0-9]+\.[0-9]+' "$DIR/CHANGELOG.md" | head -1 | grep -oE '[0-9.]+')
if [ "$PJ" != "$MK" ] || [ "$PJ" != "$CL" ]; then
    echo "version declarations diverge: plugin.json=$PJ marketplace.json=$MK CHANGELOG=$CL"
    fail=1
fi

[ "$fail" -eq 0 ] && echo "pre-push check: all OK" || echo "pre-push check: FAILED"
exit "$fail"
