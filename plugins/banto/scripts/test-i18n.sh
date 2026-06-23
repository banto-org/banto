#!/bin/sh
# test-i18n.sh — unit tests for the i18n mechanism.
# Builds a throwaway fixture plugin tree and exercises every script via BANTO_PLUGIN_ROOT /
# BANTO_LANG_FILE overrides. Covers: gen+sync-check, STALE/TAMPERED drift detection,
# materialize, set-language persistence, reconcile no-op, and sticky-across-update.
set -u

SC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HK=$(CDPATH= cd -- "$SC/../hooks" && pwd)
FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT
PREF="$FIX/banto-language"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  ok: $1"; }
no(){ fail=$((fail+1)); echo "  FAIL: $1"; }

# --- build fixture: canonical (ja) + generated (en) ---
mkdir -p "$FIX/.claude-plugin" "$FIX/i18n/ja/skills/foo" "$FIX/i18n/ja/agents" \
         "$FIX/i18n/en/skills/foo" "$FIX/i18n/en/agents" "$FIX/skills"
echo '{"version":"1.0.0"}' > "$FIX/.claude-plugin/plugin.json"
printf 'JA skill\n' > "$FIX/i18n/ja/skills/foo/SKILL.md"
printf 'EN skill\n' > "$FIX/i18n/en/skills/foo/SKILL.md"
printf 'JA agent\n' > "$FIX/i18n/ja/agents/bar.md"
printf 'EN agent\n' > "$FIX/i18n/en/agents/bar.md"
# active-only skill absent from every i18n tree (models set-language, the bilingual switcher
# that must survive materialization so a user on either language can switch back)
mkdir -p "$FIX/skills/switcher"
printf 'active-only switcher\n' > "$FIX/skills/switcher/SKILL.md"

export BANTO_PLUGIN_ROOT="$FIX"
export BANTO_LANG_FILE="$PREF"

# 1) record manifest + sync-check green
sh "$SC/i18n-gen.sh" --record >/dev/null 2>&1
if sh "$SC/i18n-sync-check.sh" >/dev/null 2>&1; then ok "sync-check green after record"; else no "sync-check should be green after record"; fi

# 2) STALE: canonical (ja) changed since last gen
printf 'changed\n' >> "$FIX/i18n/ja/skills/foo/SKILL.md"
if sh "$SC/i18n-sync-check.sh" >/dev/null 2>&1; then no "sync-check should FAIL on ja drift"; else ok "STALE detected when ja changes"; fi
printf 'JA skill\n' > "$FIX/i18n/ja/skills/foo/SKILL.md"   # restore
sh "$SC/i18n-gen.sh" --record >/dev/null 2>&1
if sh "$SC/i18n-sync-check.sh" >/dev/null 2>&1; then ok "re-record restores green"; else no "re-record did not restore green"; fi

# 3) TAMPERED: generated (en) hand-edited
printf 'tampered\n' >> "$FIX/i18n/en/skills/foo/SKILL.md"
if sh "$SC/i18n-sync-check.sh" >/dev/null 2>&1; then no "sync-check should FAIL on en tamper"; else ok "TAMPERED detected when en hand-edited"; fi
printf 'EN skill\n' > "$FIX/i18n/en/skills/foo/SKILL.md"   # restore
sh "$SC/i18n-gen.sh" --record >/dev/null 2>&1

# 4) materialize en → active set == en, marker stamped
sh "$SC/i18n-materialize.sh" en >/dev/null 2>&1
if grep -q 'EN skill' "$FIX/skills/foo/SKILL.md" 2>/dev/null; then ok "materialize en applied to active skill"; else no "active skill is not en"; fi
if grep -q 'EN agent' "$FIX/agents/bar.md" 2>/dev/null; then ok "materialize en applied to active agent"; else no "active agent is not en"; fi
if [ "$(cat "$FIX/skills/.banto-lang" 2>/dev/null)" = "en 1.0.0" ]; then ok "marker = 'en 1.0.0'"; else no "marker wrong: $(cat "$FIX/skills/.banto-lang" 2>/dev/null)"; fi
# 4b) INVARIANT: materialize overlays i18n onto active, it must NOT wipe active skills absent from
#     i18n (else set-language — active-only — would vanish on every language switch).
if grep -q 'active-only switcher' "$FIX/skills/switcher/SKILL.md" 2>/dev/null; then ok "materialize preserves active-only skill (set-language invariant)"; else no "materialize wiped active-only skill — set-language would be lost"; fi

# 5) reconcile is a NO-OP when no preference exists (fail-open)
rm -f "$PREF"
before=$(cat "$FIX/skills/.banto-lang")
sh "$HK/i18n-reconcile.sh" >/dev/null 2>&1
if [ "$(cat "$FIX/skills/.banto-lang")" = "$before" ]; then ok "reconcile no-op without preference"; else no "reconcile mutated marker without preference"; fi

# 6) set-language ja → preference persisted + active == ja
sh "$SC/set-language.sh" ja >/dev/null 2>&1
if [ "$(cat "$PREF" 2>/dev/null)" = "ja" ]; then ok "preference persisted = ja"; else no "preference not persisted"; fi
if grep -q 'JA skill' "$FIX/skills/foo/SKILL.md"; then ok "set-language materialized ja"; else no "active not ja after set-language"; fi

# 7) reconcile NO-OP when marker already matches preference + version
m1=$(cat "$FIX/skills/.banto-lang")
sh "$HK/i18n-reconcile.sh" >/dev/null 2>&1
if [ "$(cat "$FIX/skills/.banto-lang")" = "$m1" ]; then ok "reconcile no-op when already in sync"; else no "reconcile acted when already in sync"; fi

# 8) STICKY ACROSS UPDATE: version bump + active reverted to shipped EN → ja must be re-applied
echo '{"version":"1.1.0"}' > "$FIX/.claude-plugin/plugin.json"
sh "$SC/i18n-materialize.sh" en >/dev/null 2>&1   # simulate update reverting active to shipped default (en)
sh "$HK/i18n-reconcile.sh" >/dev/null 2>&1        # preference=ja → reconcile re-applies
if grep -q 'JA skill' "$FIX/skills/foo/SKILL.md" && [ "$(cat "$FIX/skills/.banto-lang")" = "ja 1.1.0" ]; then
    ok "sticky: ja re-applied after update (marker 'ja 1.1.0')"
else
    no "sticky failed: active='$(head -1 "$FIX/skills/foo/SKILL.md")' marker='$(cat "$FIX/skills/.banto-lang")'"
fi

echo ""
echo "i18n tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
