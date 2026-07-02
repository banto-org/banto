#!/bin/sh
# test-plugin-audit-consistency.sh — tests for plugin-audit-consistency.sh (Axis 15).
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
CHK="$SCRIPT_DIR/plugin-audit-consistency.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
mkfix() { d="$FIX/$1"; mkdir -p "$d/skills/s1" "$d/skills/s2"; }

# T1: clean fixture (one spelling) -> clean, exit 0
mkfix clean
printf 'save to {base}/docs/research/ and {base}/decisions/\n' > "$FIX/clean/skills/s1/SKILL.md"
printf 'reads {base}/docs/research/ too\n' > "$FIX/clean/skills/s2/SKILL.md"
out=$(sh "$CHK" "$FIX/clean" 2>&1)
echo "$out" | grep -q "clean" && ok "clean fixture -> clean" || no "clean fixture should be clean: $out"
sh "$CHK" "$FIX/clean" --strict >/dev/null 2>&1 && ok "clean fixture --strict -> exit 0" || no "clean --strict should exit 0"

# T2: divergent spelling ({base} vs {BASE} for same subpath) -> --strict exit 1, names subpath
mkfix diverge
printf 'A {base}/docs/research/ here\n' > "$FIX/diverge/skills/s1/SKILL.md"
printf 'B {BASE}/docs/research/ there\n' > "$FIX/diverge/skills/s2/SKILL.md"
sh "$CHK" "$FIX/diverge" --strict >/dev/null 2>&1 && no "divergence should make --strict exit nonzero" || ok "divergent spelling -> --strict exit nonzero"
sh "$CHK" "$FIX/diverge" 2>&1 | grep -q "docs/research" && ok "report names the divergent subpath" || no "should name docs/research"

# T3: <base> vs {base} divergence detected
mkfix angle
printf 'A {base}/sessions/ here\n' > "$FIX/angle/skills/s1/SKILL.md"
printf 'B <base>/sessions/ there\n' > "$FIX/angle/skills/s2/SKILL.md"
sh "$CHK" "$FIX/angle" --strict >/dev/null 2>&1 && no "<base> vs {base} should be nonzero" || ok "<base> vs {base} -> detected"

# T4: legacy-contrast line is NOT flagged (intentional)
mkfix legacy
printf 'use {base}/concept/CONCEPT.md (旧来のレガシーでは .ai-context/concept/CONCEPT.md)\n' > "$FIX/legacy/skills/s1/SKILL.md"
out=$(sh "$CHK" "$FIX/legacy" 2>&1)
echo "$out" | grep -q "clean" && ok "legacy-contrast .ai-context not flagged" || no "legacy contrast should be ignored: $out"

# T5: bare-path scan-exclude list (.ai-context/sessions,) is NOT flagged
mkfix exclude
{ printf 'real path {base}/sessions/ used here\n'; printf 'exclude dirs:\n'; printf '.ai-context/sessions,\n'; } > "$FIX/exclude/skills/s1/SKILL.md"
out=$(sh "$CHK" "$FIX/exclude" 2>&1)
echo "$out" | grep -q "clean" && ok "bare-path exclude-list not flagged" || no "exclude-list .ai-context should be ignored: $out"

# T6: real plugin tree is clean (regression guard — keeps the shipped harness consistent)
sh "$CHK" "$PLUGIN_ROOT" --strict >/dev/null 2>&1 && ok "real plugin tree -> clean (--strict exit 0)" || no "shipped tree has spelling divergence (run plugin-audit-consistency.sh)"

echo "plugin-audit-consistency tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
