#!/bin/sh
# test-plugin-audit-odd.sh — tests for plugin-audit-odd.sh (Axis 10 schema lint + adoption gate)
# and the report.sh Axis 10 adoption gate.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHK="$SCRIPT_DIR/plugin-audit-odd.sh"
COLLECT="$SCRIPT_DIR/plugin-audit-collect.sh"
REPORT="$SCRIPT_DIR/plugin-audit-report.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT

mkskill() { # $1=plugin $2=skill
    mkdir -p "$FIX/$1/skills/$2"
    printf -- '---\nname: %s\ndescription: test skill\n---\n# t\n' "$2" > "$FIX/$1/skills/$2/SKILL.md"
}
valid_odd() { # $1=plugin $2=skill
    cat > "$FIX/$1/skills/$2/odd.yaml" <<EOF
schema_version: 1
skill: $2
autonomy_level: L1  # test
in_scope:
  - test scope
out_of_scope:
  - other work
EOF
}

# T1: non-adopting plugin (skills exist, zero odd.yaml) -> N/A line, exit 0 even with --strict
mkskill noadopt s1
mkskill noadopt s2
out=$(sh "$CHK" "$FIX/noadopt" 2>&1)
echo "$out" | grep -q "ODD not adopted" && ok "non-adopting -> N/A line" || no "expected N/A line: $out"
echo "$out" | grep -q "no odd.yaml |" && no "non-adopting must not emit per-skill warns" || ok "no per-skill warns for non-adopting"
sh "$CHK" "$FIX/noadopt" --strict >/dev/null 2>&1 && ok "non-adopting --strict -> exit 0" || no "non-adopting --strict should exit 0"

# T2: adopting plugin with one skill missing odd.yaml -> partial-adoption warn, strict still 0
mkskill partial s1
mkskill partial s2
valid_odd partial s1
out=$(sh "$CHK" "$FIX/partial" 2>&1)
echo "$out" | grep -q "| s2 | ⚠ no odd.yaml |" && ok "partial adoption -> per-skill warn for s2" || no "expected warn row for s2: $out"
echo "$out" | grep -q "| s1 | OK |" && ok "valid odd.yaml -> OK" || no "expected OK row for s1: $out"
sh "$CHK" "$FIX/partial" --strict >/dev/null 2>&1 && ok "missing-only --strict -> exit 0" || no "missing odd is warn, not FAIL"

# T3: structural violation (unknown key + L4) -> FAIL row, --strict exit 1
mkskill broken s1
valid_odd broken s1
printf 'human_oversight: none\n' >> "$FIX/broken/skills/s1/odd.yaml"
sed -i '' 's/^autonomy_level: L1/autonomy_level: L4/' "$FIX/broken/skills/s1/odd.yaml" 2>/dev/null || \
    sed -i 's/^autonomy_level: L1/autonomy_level: L4/' "$FIX/broken/skills/s1/odd.yaml"
out=$(sh "$CHK" "$FIX/broken" 2>&1)
echo "$out" | grep -q "❌ FAIL" && ok "structural violation -> FAIL row" || no "expected FAIL row: $out"
echo "$out" | grep -q "unknown-key:human_oversight" && ok "unknown key named" || no "should name unknown key: $out"
echo "$out" | grep -q "autonomy-out-of-banto:L4" && ok "L4 flagged out-of-banto" || no "should flag L4: $out"
sh "$CHK" "$FIX/broken" --strict >/dev/null 2>&1 && no "violation --strict should exit 1" || ok "violation --strict -> exit 1"

# T4: report.sh adoption gate — non-adopting plugin -> N/A, no "skills without ODD" warn section
rep=$(sh "$COLLECT" "$FIX/noadopt" 2>/dev/null | sh "$REPORT" 2>/dev/null | sed -n '/## Axis 10:/,/## References/p')
echo "$rep" | grep -q "ODD not adopted" && ok "report: non-adopting -> N/A" || no "report should say not adopted: $rep"
echo "$rep" | grep -q "skills without ODD" && no "report must not emit without-ODD warn table" || ok "report: warn section suppressed"

# T5: report.sh adopting plugin -> summary + warn table still present
rep=$(sh "$COLLECT" "$FIX/partial" 2>/dev/null | sh "$REPORT" 2>/dev/null | sed -n '/## Axis 10:/,/## References/p')
echo "$rep" | grep -q "Skills with ODD applied | 1 / 2" && ok "report: adoption rate kept for adopters" || no "expected 1 / 2 rate: $rep"
echo "$rep" | grep -q "skills without ODD" && ok "report: partial adoption keeps warn section" || no "warn section should remain for adopters"

echo ""
echo "plugin-audit-odd: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
