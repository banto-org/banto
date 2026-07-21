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
# writing-ja toggle isolation: never touch the real ~/.claude (rules dir + preference marker)
export BANTO_WJ_FILE="$FIX/banto-writing-ja"
export BANTO_RULES_DIR="$FIX/rules"
mkdir -p "$FIX/rules"

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

# 4c) DRIFT GUARD: hand-editing the active tree directly (without touching the canonical)
#     must make the next materialize call REFUSE rather than silently discard the edit.
printf 'EN skill\nHAND-EDITED\n' > "$FIX/skills/foo/SKILL.md"
if sh "$SC/i18n-materialize.sh" ja >/dev/null 2>&1; then no "materialize should REFUSE on hand-edited active tree"; else ok "drift guard refuses to overwrite a hand-edited active file"; fi
if grep -q 'HAND-EDITED' "$FIX/skills/foo/SKILL.md" 2>/dev/null; then ok "drift guard preserved the hand-edit (no silent revert)"; else no "hand-edit was silently discarded"; fi
if [ "$(cat "$FIX/skills/.banto-lang" 2>/dev/null)" = "en 1.0.0" ]; then ok "drift guard left marker unchanged (still en)"; else no "marker changed despite refused materialize"; fi
# BANTO_MATERIALIZE_FORCE=1 bypasses the guard for an intentional override
if BANTO_MATERIALIZE_FORCE=1 sh "$SC/i18n-materialize.sh" ja >/dev/null 2>&1; then ok "BANTO_MATERIALIZE_FORCE=1 bypasses the drift guard"; else no "force override should have succeeded"; fi
printf 'EN skill\n' > "$FIX/i18n/en/skills/foo/SKILL.md"   # restore fixture to the pre-drift state
sh "$SC/i18n-materialize.sh" en >/dev/null 2>&1             # re-sync active back to clean en

# 5) reconcile is a NO-OP when no preference exists (fail-open)
rm -f "$PREF"
before=$(cat "$FIX/skills/.banto-lang")
sh "$HK/i18n-reconcile.sh" >/dev/null 2>&1
if [ "$(cat "$FIX/skills/.banto-lang")" = "$before" ]; then ok "reconcile no-op without preference"; else no "reconcile mutated marker without preference"; fi

# 6) set-language ja → preference persisted + active == ja
sh "$SC/set-language.sh" ja >/dev/null 2>&1
if [ "$(cat "$PREF" 2>/dev/null)" = "ja" ]; then ok "preference persisted = ja"; else no "preference not persisted"; fi
if grep -q 'JA skill' "$FIX/skills/foo/SKILL.md"; then ok "set-language materialized ja"; else no "active not ja after set-language"; fi

# 6b) LEGITIMATE canonical update must NOT be blocked as drift: editing i18n/ja (the correct
#     workflow) and re-materializing the SAME language must succeed — the guard compares against
#     the last-materialized state, not live canonical, so this must not false-positive.
printf 'JA skill\nupdated canonical\n' > "$FIX/i18n/ja/skills/foo/SKILL.md"
if sh "$SC/i18n-materialize.sh" ja >/dev/null 2>&1; then ok "legitimate canonical update re-materializes without being flagged as drift"; else no "canonical update was wrongly refused as drift"; fi
if grep -q 'updated canonical' "$FIX/skills/foo/SKILL.md" 2>/dev/null; then ok "active reflects the updated canonical"; else no "active did not pick up the canonical update"; fi
printf 'JA skill\n' > "$FIX/i18n/ja/skills/foo/SKILL.md"   # restore fixture

# 6c) writing-ja is OPT-IN: set-language ja alone must NOT deploy it (no preference = off)
if [ ! -e "$FIX/rules/writing-ja.md" ]; then ok "writing-ja not deployed by default (opt-in)"; else no "writing-ja deployed without opt-in"; fi
# 6d) toggle on (lang=ja) → preference persisted + rule deployed
sh "$SC/writing-ja-toggle.sh" on >/dev/null 2>&1
if [ "$(tr -d ' \n' < "$FIX/banto-writing-ja" 2>/dev/null)" = "on" ]; then ok "writing-ja preference persisted = on"; else no "writing-ja preference not persisted"; fi
if [ -e "$FIX/rules/writing-ja.md" ]; then ok "toggle on deployed writing-ja.md"; else no "toggle on did not deploy writing-ja.md"; fi
# 6e) language switch reconciles the rule: en removes it, ja (pref still on) redeploys it
sh "$SC/set-language.sh" en >/dev/null 2>&1
if [ ! -e "$FIX/rules/writing-ja.md" ]; then ok "en switch removed writing-ja.md"; else no "writing-ja.md survived en switch"; fi
sh "$SC/set-language.sh" ja >/dev/null 2>&1
if [ -e "$FIX/rules/writing-ja.md" ]; then ok "ja switch redeployed writing-ja.md (pref on)"; else no "writing-ja.md not redeployed on ja with pref on"; fi
# 6f) toggle off removes the unmodified copy; a personally edited copy is protected
sh "$SC/writing-ja-toggle.sh" off >/dev/null 2>&1
if [ ! -e "$FIX/rules/writing-ja.md" ]; then ok "toggle off removed unmodified copy"; else no "toggle off left unmodified copy"; fi
sh "$SC/writing-ja-toggle.sh" on >/dev/null 2>&1
printf 'personal edit\n' >> "$FIX/rules/writing-ja.md"
sh "$SC/writing-ja-toggle.sh" off >/dev/null 2>&1
if [ -e "$FIX/rules/writing-ja.md" ]; then ok "toggle off protected a modified copy"; else no "toggle off deleted a modified copy"; fi
rm -f "$FIX/rules/writing-ja.md"

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

# 9) AUTO-MODE SAFETY: a translate command that produces empty output must leave the existing
#    EN file untouched and the script must exit non-zero (regression guard: the translator used
#    to write its empty/hung stdout straight into the EN file, destroying it in place).
printf 'JA skill\nauto trigger\n' > "$FIX/i18n/ja/skills/foo/SKILL.md"
before_en=$(cat "$FIX/i18n/en/skills/foo/SKILL.md")
if BANTO_I18N_TRANSLATE_CMD=true sh "$SC/i18n-gen.sh" >/dev/null 2>&1; then
    no "i18n-gen should exit non-zero when translate output is empty"
else
    ok "i18n-gen exits non-zero on empty translate output"
fi
if [ "$(cat "$FIX/i18n/en/skills/foo/SKILL.md")" = "$before_en" ]; then ok "existing EN left untouched on translate failure"; else no "EN file was overwritten with empty/invalid output"; fi
printf 'JA skill\n' > "$FIX/i18n/ja/skills/foo/SKILL.md"   # restore fixture
sh "$SC/i18n-gen.sh" --record >/dev/null 2>&1

# 10) TEMPLATES: i18n-managed templates follow the language on materialize; files kept out of
#     the i18n trees (lang-specific assets like writing-ja.md) must survive untouched.
mkdir -p "$FIX/i18n/ja/templates/rules" "$FIX/i18n/en/templates/rules" "$FIX/templates/rules"
printf 'JA rule\n' > "$FIX/i18n/ja/templates/rules/r1.md"
printf 'EN rule\n' > "$FIX/i18n/en/templates/rules/r1.md"
printf 'lang-specific asset\n' > "$FIX/templates/rules/lang-only.md"
sh "$SC/i18n-gen.sh" --record >/dev/null 2>&1
sh "$SC/i18n-materialize.sh" en >/dev/null 2>&1
if grep -q 'EN rule' "$FIX/templates/rules/r1.md" 2>/dev/null; then ok "materialize en applied to managed template"; else no "managed template not materialized to en"; fi
sh "$SC/i18n-materialize.sh" ja >/dev/null 2>&1
if grep -q 'JA rule' "$FIX/templates/rules/r1.md" 2>/dev/null; then ok "materialize ja applied to managed template"; else no "managed template not materialized back to ja"; fi
if grep -q 'lang-specific asset' "$FIX/templates/rules/lang-only.md" 2>/dev/null; then ok "materialize preserves non-managed template (lang-specific invariant)"; else no "non-managed template wiped by materialize"; fi

# 11) COVERAGE: every language-bearing file must be managed or explicitly exempted.
#     Unclassified here: templates/rules/lang-only.md + skills/switcher/SKILL.md (active-only).
if sh "$SC/i18n-coverage-check.sh" >/dev/null 2>&1; then no "coverage should FAIL on unclassified files"; else ok "coverage flags unmanaged, unexempted files"; fi
{
    printf 'active-only skills/switcher/*\n'
    printf 'lang-specific templates/rules/lang-only.md\n'
} > "$FIX/i18n/.coverage-exemptions"
if sh "$SC/i18n-coverage-check.sh" >/dev/null 2>&1; then ok "coverage green once every file is classified (managed r1.md needs no exemption)"; else no "coverage still failing after exemptions"; fi

echo ""
echo "i18n tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
