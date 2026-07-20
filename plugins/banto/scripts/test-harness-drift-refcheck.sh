#!/bin/sh
# test-harness-drift-refcheck.sh — harness-drift-check.sh の参照生存チェック検証（issue #102）
#
# 検証:
#   1. クロススキル参照（skills/<other>/references/X.md）が実在する → 警告しない
#      （旧実装は部分一致で skill-local と誤解釈し偽陽性を出していた）
#   2. クロススキル参照が欠落 → skills/... のフルパスで missing を警告する（生存チェックは維持）
#   3. skill-local 参照の欠落 → 従来どおり missing を警告する（リグレッションガード）
#   4. skill-local 参照が空ファイル → 従来どおり empty を警告する
#
# 隔離: 合成 repo + 同一 version の合成 live plugin.json（autoupdate 経路を発火させない）
#   + 合成 TMPDIR（スロットル marker を実 TMPDIR に残さない）。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$DIR/scripts/harness-drift-check.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/drift-refcheck.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

REPO="$TMP/repo"
SK="$REPO/plugins/banto/skills"
mkdir -p "$REPO/plugins/banto/.claude-plugin" \
         "$SK/alpha/references" "$SK/beta/references" "$SK/gamma" "$SK/delta/references"
printf '{"name":"banto","version":"1.0.0"}\n' > "$REPO/plugins/banto/.claude-plugin/plugin.json"

LIVE="$TMP/live"
mkdir -p "$LIVE/.claude-plugin"
printf '{"name":"banto","version":"1.0.0"}\n' > "$LIVE/.claude-plugin/plugin.json"

# alpha: 実在する local 参照 + 実在するクロススキル参照 → 一切警告されないこと
cat > "$SK/alpha/SKILL.md" <<'EOF'
# alpha
Local: `references/local-ok.md` を参照。
Cross: 受け手調整は `skills/beta/references/shared.md` を直接参照する。
EOF
echo "body" > "$SK/alpha/references/local-ok.md"
echo "body" > "$SK/beta/references/shared.md"

# beta: 欠落したクロススキル参照 → skills/... フルパスで missing
cat > "$SK/beta/SKILL.md" <<'EOF'
# beta
Cross: `skills/alpha/references/nope.md` を参照する。
EOF

# gamma: 欠落した local 参照 → missing（従来挙動）
cat > "$SK/gamma/SKILL.md" <<'EOF'
# gamma
Local: `references/gone.md` を参照。
EOF

# delta: 空ファイルの local 参照 → empty（従来挙動）
cat > "$SK/delta/SKILL.md" <<'EOF'
# delta
Local: `references/blank.md` を参照。
EOF
: > "$SK/delta/references/blank.md"

T1="$TMP/t1"; mkdir -p "$T1"
OUT=$(TMPDIR="$T1" CLAUDE_PLUGIN_ROOT="$LIVE" sh "$HOOK" "$REPO" 2>/dev/null)

# === 1: クロススキル実在参照は偽陽性を出さない（#102 の再現ケース） ===
case "$OUT" in
    *"alpha/SKILL.md"*) bad "1: alpha (existing local + existing cross-skill) was wrongly flagged: $OUT" ;;
    *) ok "1: existing cross-skill ref is not misread as skill-local (#102)" ;;
esac

# === 2: 欠落クロススキル参照はフルパスで missing ===
case "$OUT" in
    *'`beta/SKILL.md` → `skills/alpha/references/nope.md` (missing)'*) ok "2: missing cross-skill ref is flagged with its full path" ;;
    *) bad "2: missing cross-skill ref not flagged correctly: $OUT" ;;
esac

# === 3: 欠落 local 参照は従来どおり missing ===
case "$OUT" in
    *'`gamma/SKILL.md` → `references/gone.md` (missing)'*) ok "3: missing local ref still flagged" ;;
    *) bad "3: missing local ref regression: $OUT" ;;
esac

# === 4: 空 local 参照は従来どおり empty ===
case "$OUT" in
    *'`delta/SKILL.md` → `references/blank.md` (empty)'*) ok "4: empty local ref still flagged" ;;
    *) bad "4: empty local ref regression: $OUT" ;;
esac

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
