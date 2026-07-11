# Audit execution procedure

## 1. Identify the target

Determine the target skill directory from `$ARGUMENTS` or conversation context. Confirm `<dir>/SKILL.md` exists; if not, ask the user.

## 2. Gather mechanical measurements

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/skill-audit-metrics.sh" <skill-dir>
```

Output:
- (a) byte/line counts for SKILL.md and each reference
- (b) character count of the frontmatter description
- (c) hits of process-history patterns (the same group ja-lint.py's META_PATTERNS detects)
- (d) duplicate paragraphs across files (normalized lines of 30+ characters matching across multiple files, with filenames)
- (e) occurrence counts of Claude-specific tokens (Task / Skill / CLAUDE_PLUGIN_ROOT / hook / allowed-tools / SKILL.md)
- (f) extracted model-directive lines (`model:` / `model=`)

## 3. Judge the 7 axes

Follow each axis's judgment procedure in [`axes.md`](axes.md), cross-referencing the mechanical measurements against what you Read from SKILL.md and its references. Delegate subjective judgment calls — such as A6 (stated-AI consistency) — to an Agent (general-purpose, `model: opus`) — the Reviewer = Fresh Agent principle, using the same `audit` role from model-policy.json that plugin-audit and harness-audit use.

## 4. Report

Report each axis as PASS / WARN / FAIL with a supporting line number and a one-sentence fix proposal. Lead with the conclusion; state numbers as exact figures.

```
# Skill Audit: <skill-name>

## Summary
- A1 Information minimality: PASS/WARN/FAIL
- A2 Leakage of human-only information: PASS/WARN/FAIL
- A3 Division of labor in structure: PASS/WARN/FAIL
- A4 Execution-model directive: PASS/WARN/FAIL
- A5 Context efficiency: PASS/WARN/FAIL
- A6 Stated-AI disclosure and consistency: PASS/WARN/FAIL
- A7 Division of labor with determinism: PASS/WARN/FAIL

## Details (per axis)
(supporting line numbers + fix proposal per axis)
```

## 5. Applying fixes

Apply any fix only after user approval. The audit itself is read-only (Bash is used only to run `skill-audit-metrics.sh`).
