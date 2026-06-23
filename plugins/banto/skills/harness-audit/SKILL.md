---
name: harness-audit
description: |
  **ANALYSIS SKILL** — Audit the whole banto harness from a **system perspective** (vs plugin-audit, which scores individual skill quality). 5 axes: ideology alignment, actual usage (dead skills), freshness (edit-repo vs live-plugin drift), install-policy alignment, and Claude-feature alignment (allowed-tools / hooks).
  Triggers: "audit the whole harness", "system audit of banto", "is the harness healthy", "any dead skills or drift?". Also invocable via /harness-audit. The thorough (multi-agent Workflow) mode is opt-in — it never starts without an explicit "thorough" / "ultracode" cue; natural-language firing runs only the lightweight read-only inline audit.
  Do not use when: scoring a single skill's quality (plugin-audit), generating a skill / plugin (plugin-dev), code review (code-review), or security audit (security-guidance).
user-invocable: true
argument-hint: "[plugin path (defaults to plugins/banto)]"
allowed-tools: Read Grep Glob Bash Agent Workflow
compatibility: Claude Code (requires bash, git, jq)
---

# [Audit] Harness Audit — System Audit of the Whole Harness

> **Storage base (store-first)**: every `.ai-context/...` path in this skill refers to the ai-context base — the absolute path injected at SessionStart as 「ai-context ベース: &lt;absolute path&gt;」 (if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

**Division of labor with plugin-audit**: plugin-audit scores "is this skill a good skill on its own (description / triggers / boundaries / ODD)" on 14 axes. harness-audit checks "**is the harness as a whole working according to the principles**". Even if every skill scores perfectly, the system is broken if a skill is never invoked (dead), the editing repo and the live plugin have drifted apart, or declarations and reality diverge. Catching that is this skill's job.

Founding principle: the subject of invocation = self-driving Claude, exceptions are checkpoints only, enforcement belongs to hooks.

Target path: `$ARGUMENTS` (default `plugins/banto`). Referred to as `PLUGIN` below.

If the user converses in Japanese, write the report and respond in Japanese.

## Execution modes

- **Default (inline)**: run the 5 axes below in this session with Read/Grep/Bash, delegating only the subjective axes (e.g. dead-skill verdicts) to an Agent. Lightweight and immediate. **Use this normally.**
- **thorough (Workflow, opt-in only)**: a deterministic pipeline that audits the 5 axes with parallel agents → verifies each finding adversarially → synthesizes against the North Star. Only when the user **opts in** to multi-agent execution with "thorough", "ultracode", etc.:
  ```
  Workflow({ scriptPath: "$CLAUDE_PLUGIN_ROOT/workflows/harness-audit.workflow.js", args: { cwd: "<absolute path of the target repo>" } })
  ```
  Without opt-in, never launch the Workflow on your own; run inline (anti "modal questions" / Workflows consume a lot of tokens).
- **network (Workflow, opt-in only)**: the thorough Workflow with `args.mode: "network"` — beyond the 5 system axes it fans out **per-skill quality** in 3 tiers (Tier1 static all-skill scripts → Tier2 candidate-driven `general-purpose` judgment, model-tiered haiku/sonnet). One run covers system coherence **and** every skill's quality (dormancy uses the 3-condition AND: telemetry=0 ∧ git=0 ∧ artifact=0). Same opt-in gate as thorough; highest cost — reserve for pre-release / large refactors:
  ```
  Workflow({ scriptPath: "$CLAUDE_PLUGIN_ROOT/workflows/harness-audit.workflow.js", args: { cwd: "<absolute path>", mode: "network" } })
  ```

---

## Axis 1: Ideology alignment (consistency with the self-driving principle / North Star)

Check whether any "ritual that is merely a human approval gate" remains. Under the self-driving principle, enforcement belongs to hooks (deterministic); skills are capabilities, not approval gates.

Checks:
```sh
# 1a. Is the concept (North Star) @import injected into CLAUDE.md (is the ideology layer wired)?
grep -rl "CONCEPT.md\|北極星\|@import" "$PLUGIN"/.. 2>/dev/null | head

# 1b. Does any skill still list AskUserQuestion in allowed-tools (text-dialogue policy; disabled via askuser-deny)?
grep -rln "AskUserQuestion" "$PLUGIN"/skills/*/SKILL.md "$PLUGIN"/skills/*/odd.yaml 2>/dev/null

# 1c. Human-gate phrasing ("wait for approval" etc., JP + EN patterns) hiding in self-driving skills (needs contextual judgment)
grep -rln "承認を待\|許可を得てから\|ユーザーの指示を待\|wait for approval\|wait for the user\|ask before proceeding\|require user confirmation\|ask for permission" "$PLUGIN"/skills 2>/dev/null
```
Verdicts:
- ❌ No North Star injection → the ideology layer is floating (the concept skill's output is not alive)
- ❌ A skill holding AskUserQuestion → contradicts the disabled feature (overlaps axis 5, is_error)
- ⚠ Approval-gate phrasing → human gates other than checkpoints are eliminated in principle. Judge in context and propose self-driving alternatives

## Axis 2: Actual usage (dead-skill detection)

**Measure by artifacts, not invocations alone** (a skill with zero invocations can still be functioning through its artifacts).

Checks:
```sh
# 2a+2b+2c. Telemetry aggregation (recorded by telemetry-log.sh)
#   One command prints per-skill invocations + dead candidates + artifacts by prefix.
#   Lists every skill as the denominator; shows skills with 0 invocations in the window as dead candidates.
sh "$CLAUDE_PLUGIN_ROOT/scripts/telemetry-summary.sh" --days 30 "$PWD"

# For machine verdicts, use JSON (the dead_candidates array holds the dead candidates)
sh "$CLAUDE_PLUGIN_ROOT/scripts/telemetry-summary.sh" --json --days 30 "$PWD" \
  | jq '.dead_candidates'
```
Verdict: a skill with **both** invocation=0 and artifact=0 persisting within the window is a dead candidate. However, skills with "insurance value (an explicit intent signal)" are treated as a fork rather than deleted immediately. When telemetry history is shallow, state "insufficient data" explicitly and avoid a dead verdict. Delegate the final verdict to a general-purpose agent to avoid bias.

> Fallback when telemetry is absent (no jq / nothing accumulated): count artifact prefixes directly, e.g. `ls .ai-context/docs/ | grep -cF "[Audit]"` (measure at least the artifact side — measure by artifacts, not only invocations).

## Axis 3: Freshness (drift across editing repo ↔ live cache)

Permanently monitor "the repo being edited ≠ the plugin actually running".

Checks:
```sh
REPO_VER=$(jq -r '.version' "$PLUGIN"/.claude-plugin/plugin.json 2>/dev/null)
CHANGELOG_VER=$(grep -oE '## \[?[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md 2>/dev/null | head -1 | grep -oE '[0-9.]+')
LIVE_VER=$(jq -r '.plugins | to_entries[] | select(.key|startswith("banto@")) | .value[0].version' ~/.claude/plugins/installed_plugins.json 2>/dev/null | head -1)
echo "repo=$REPO_VER  changelog=$CHANGELOG_VER  live-cache=$LIVE_VER"
# Actual skill count vs the number declared in plugin.json
echo "actual skill count: $(ls -d "$PLUGIN"/skills/*/ | wc -l | tr -d ' ')"
grep -oE '[0-9]+ スキル' "$PLUGIN"/.claude-plugin/plugin.json

# 3b. Stale versions piling up in the cache (claude plugin update does not auto-delete old versions)
CACHE_DIR=$(ls -d ~/.claude/plugins/cache/*/banto 2>/dev/null | head -1)
if [ -d "$CACHE_DIR" ]; then
  for v in "$CACHE_DIR"/*/; do
    vv=$(basename "$v")
    [ "$vv" = "$LIVE_VER" ] && continue
    echo "STALE cache version: $vv (not active=$LIVE_VER → deletion candidate)"
  done
fi
```
Verdict: if the versions do not match, warn that a re-sync is needed — `claude plugin marketplace update <marketplace> && claude plugin update banto@<marketplace>`, then restart Claude Code. Also flag a mismatch between the skill count declared in plugin.json and the actual count. If non-active cache versions remain, warn "stale version buildup (wasted space) → propose GC via `rm -rf` (deletion requires confirmation)".

## Axis 4: Install-policy alignment (declaration vs reality)

Whether what plugin.json declares as "delegated to external" or "bundled" actually holds in the real environment.

Checks:
```sh
# 4a. Extract delegation declarations from plugin.json (Japanese declaration text)
grep -oE "(完全デリゲート|委譲|delegate)[^」]*" "$PLUGIN"/.claude-plugin/plugin.json
# 4b. Does delegation point to NATIVE features (/code-review, /security-review), not an auto-installed
#     plugin? Banto does NOT auto-install the official plugins (delegate != install). Any install claim left?
grep -rEln "plugin install .*(security-guidance|code-review)" "$PLUGIN" 2>/dev/null
# 4c. Do any references to deleted skills (init-harness, etc.) remain in declarations / kit / counts?
grep -rln "init-harness" "$PLUGIN"/skills "$PLUGIN"/.claude-plugin 2>/dev/null
```
Verdict: delegation assumes install / deleted-skill references remain → drift. Make declaration and reality match (history: v5.16.0 deleted self-guards assuming delegation = install, leaving a gap; restored in v5.21.26).

## Axis 5: Claude feature alignment (contradictions with current behavior)

Whether allowed-tools / hook registration events / frontmatter contradict current Claude Code behavior or this plugin's policies (disabled features).

Checks:
```sh
# 5a. Skills still listing the disabled AskUserQuestion in allowed-tools
grep -rln "AskUserQuestion" "$PLUGIN"/skills 2>/dev/null
# 5b. Do the hook scripts referenced by hooks.json exist (orphan registration detection)?
jq -r '.hooks[][]?.hooks[]?.command' "$PLUGIN"/hooks/hooks.json 2>/dev/null \
  | sed "s#\${CLAUDE_PLUGIN_ROOT}#$PLUGIN#g" | while read -r h; do
      [ -f "$h" ] || echo "MISSING hook: $h"
    done
# 5c. Do the hooks.json event names exist among the official 29 events (typo detection)?
jq -r '.hooks | keys[]' "$PLUGIN"/hooks/hooks.json 2>/dev/null
```
Verdict: report remnants of disabled features, orphan hooks, and unknown events as is_error.

---

## Output ([Audit] report)

Save to `.ai-context/docs/[Audit] harness-<YYYY-MM-DD>.md`. Format:

```
# [Audit] Harness Audit — <date>

## Summary
- Ideology alignment: ✅/⚠/❌ (one-line gist)
- Actual usage: N dead candidates (skill names)
- Freshness: repo=x / cache=y (match or drift)
- Install policy: K of M declarations match reality
- Claude feature alignment: N contradictions

## Details (per axis)
(Each axis's findings + remediation proposals. Critical → High order)

## Remediation actions
- [ ] ... (prioritized)
```

Report **Critical/High first**. Keep remediations as proposals; destructive operations such as deletion follow safety.md and require user confirmation.
