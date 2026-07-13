#!/bin/sh
# test-skill-audit-metrics.sh — tests for skill-audit-metrics.sh.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MET="$SCRIPT_DIR/skill-audit-metrics.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
mkfix() { d="$FIX/$1"; mkdir -p "$d/references"; echo "$d"; }

# T1: file size section reports the synthetic SKILL.md
d=$(mkfix t1)
printf -- '---\nname: t1\ndescription: |\n  A short test description.\nallowed-tools: Read\n---\n\nbody\n' > "$d/SKILL.md"
out=$(sh "$MET" "$d" 2>&1)
echo "$out" | grep -q "SKILL.md	bytes=" && ok "(a) reports SKILL.md byte size" || no "(a) missing byte size: $out"

# T2: description length is reported and non-zero for a real description block
echo "$out" | grep -q "description chars=" && ok "(b) reports description chars line" || no "(b) missing description chars line"
desc_len=$(echo "$out" | grep "description chars=" | cut -d= -f2)
[ "${desc_len:-0}" -gt 0 ] 2>/dev/null && ok "(b) description chars > 0 for populated description" || no "(b) expected chars > 0, got $desc_len"

# T3: meta-info pattern hit detected
d=$(mkfix t3)
printf -- '---\nname: t3\ndescription: |\n  desc\n---\n\n本文（最新）の説明。\n' > "$d/SKILL.md"
out=$(sh "$MET" "$d" 2>&1)
echo "$out" | grep -q "（最新）" && ok "(c) detects meta-info pattern hit" || no "(c) did not detect （最新）: $out"

# T4: no false positive on a clean fixture (no meta-info pattern)
d=$(mkfix t4)
printf -- '---\nname: t4\ndescription: |\n  desc\n---\n\n普通の説明文だけ。\n' > "$d/SKILL.md"
out=$(sh "$MET" "$d" 2>&1)
sect=$(echo "$out" | awk '/\(c\)/{f=1;next}/\(d\)/{f=0}f')
[ -z "$(echo "$sect" | tr -d '[:space:]')" ] && ok "(c) no false positive on clean fixture" || no "(c) unexpected hit on clean fixture: $sect"

# T5: duplicate paragraph across SKILL.md and references/foo.md is detected with both filenames
d=$(mkfix t5)
DUPLINE="this exact thirty-plus character line repeats"
printf -- '---\nname: t5\ndescription: |\n  desc\n---\n\n%s\n' "$DUPLINE" > "$d/SKILL.md"
printf -- '# ref\n\n%s\n' "$DUPLINE" > "$d/references/foo.md"
out=$(sh "$MET" "$d" 2>&1)
echo "$out" | grep -q "SKILL.md" && echo "$out" | grep -q "foo.md" && echo "$out" | grep -q "$DUPLINE" \
  && ok "(d) detects cross-file duplicate paragraph with both filenames" \
  || no "(d) did not detect duplicate across SKILL.md/foo.md: $out"

# T6: no duplicate reported when reference content is distinct
d=$(mkfix t6)
printf -- '---\nname: t6\ndescription: |\n  desc\n---\n\nunique line only in the skill file here\n' > "$d/SKILL.md"
printf -- '# ref\n\nanother unrelated unique line entirely different\n' > "$d/references/foo.md"
out=$(sh "$MET" "$d" 2>&1)
sect=$(echo "$out" | awk '/\(d\)/{f=1;next}/\(e\)/{f=0}f')
[ -z "$(echo "$sect" | tr -d '[:space:]')" ] && ok "(d) no duplicate reported for distinct content" || no "(d) unexpected duplicate: $sect"

# T7: Claude-specific token occurrences counted (Task/Skill/CLAUDE_PLUGIN_ROOT)
d=$(mkfix t7)
printf -- '---\nname: t7\ndescription: |\n  desc\nallowed-tools: Task Skill\n---\n\nUse ${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh and a hook.\n' > "$d/SKILL.md"
out=$(sh "$MET" "$d" 2>&1)
task_n=$(echo "$out" | grep "^Task=" | cut -d= -f2)
root_n=$(echo "$out" | grep "^CLAUDE_PLUGIN_ROOT=" | cut -d= -f2)
[ "${task_n:-0}" -gt 0 ] 2>/dev/null && [ "${root_n:-0}" -gt 0 ] 2>/dev/null \
  && ok "(e) counts Claude-specific tokens (Task, CLAUDE_PLUGIN_ROOT)" \
  || no "(e) expected non-zero token counts, got Task=$task_n CLAUDE_PLUGIN_ROOT=$root_n"

# T8: model directive line extracted
d=$(mkfix t8)
printf -- '---\nname: t8\ndescription: |\n  desc\n---\n\nLaunch with model: opus for the judgment axis.\n' > "$d/SKILL.md"
out=$(sh "$MET" "$d" 2>&1)
echo "$out" | grep -q "model: opus" && ok "(f) extracts model directive line" || no "(f) did not extract model directive: $out"

# T9: missing SKILL.md fails with a clear error (non-zero exit)
d="$FIX/t9-empty"; mkdir -p "$d"
if sh "$MET" "$d" >/dev/null 2>&1; then no "(guard) should fail when SKILL.md is missing"; else ok "(guard) fails cleanly when SKILL.md is missing"; fi

echo "skill-audit-metrics tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
