# plugin-audit verify — functional verification (the eval that "Sensei" lacked)

Axis 4 measures **routing** (does the right skill fire for a prompt?). `verify` measures
**function** (once fired, does the skill actually produce what it claims?). Together they cover
routing → execution end-to-end. This is the eval layer decision `2026-05-14` flagged as missing —
plugin-audit had only the static frontmatter ("Sensei") checks, not real execution eval.

`verify` is a **subcommand**, not a 15th axis: it has side effects (runs skills end-to-end) and costs
minutes, so it cannot live in the read-only, seconds-scale axis framework. It is the functional
downstream of Axis 4.

## Tiers — which skills are verifiable

| Tier | meaning | skills | how |
|---|---|---|---|
| **A deterministic** | output path + required structure are declared in SKILL.md; side effects bounded to the ai-context base | memo, spec, save-checkpoint, status, ai-context (decisions) | deterministic assertions, ~no agent judgment |
| **B semi** | artifact is produced, but "is the content correct" needs judgment | search, research | deterministic (structure + invariants) + judge vote |
| **C judgmental** | output is dialogue / proposal / interpretation, no single correct answer | concept, architect, debugger, plugin-dev | verify-exempt → covered by Axis 4 routing + Axis 14 hygiene + dogfooding |

`verify-cases.yaml` lives at `skills/<name>/verify-cases.yaml` (schema in its header: `skill` / `tier` /
`cases[]` with `fixture` / `assert` / `invariants`). A skill with no verify-cases file is treated as Tier C
(exempt); `matrix` flags Tier A/B skills that are missing one.

## Procedure (per case, Tier A/B)

1. **Sandbox** — `base=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/verify-sandbox.sh" start)`. Creates a throwaway
   ai-context base under `$TMPDIR` and activates `verify-write-guard` (a PreToolUse hook): any Write/Edit
   outside `base` is **blocked deterministically**, so the verified skill cannot touch the real store or repo.
2. **Run the skill in isolation** — spawn a `general-purpose` subagent (Reviewer = Fresh Agent), granting it
   the skill's own `allowed-tools`: *"Load `<skill>`'s SKILL.md. Your ai-context base is `<base>`. Process this
   request: `<fixture.prompt>`. Do exactly what the skill says; write artifacts only under the base."* For a
   Tier B skill that mutates the repo via Bash git, also run the subagent with cwd in a throwaway `git worktree`.
3. **Assert (deterministic)** — `sh "$CLAUDE_PLUGIN_ROOT/scripts/plugin-audit-verify-assert.sh" --dir "$base"`
   with the flags translated from `case.assert`:
   `--glob` / `--headings "A|B"` / `--forbidden "x|y"` / `--no-template-vars "{{"` / `--writes-only-under "docs/"`.
   Exit 0 = all pass.
4. **Judge (Tier B only)** — a second subagent votes 0/1 "does this artifact satisfy the skill's claim?"
   (≥3 votes, majority). Tier A skips this.
5. **Teardown** — `sh "$CLAUDE_PLUGIN_ROOT/scripts/verify-sandbox.sh" stop "$base"`.

Report per case: pass/fail + the failing assertion. A skill passes `verify` only when all its cases pass.

## Invariants (enforced, not just asserted)
- `writes_only_under` — enforced at runtime by `verify-write-guard` (PreToolUse), in addition to the post-hoc
  `--writes-only-under` assertion.
- `no_web_access` — **structural**: the verify subagent is granted only the skill's own `allowed-tools`; a skill
  like search/webread that must not browse simply has no WebSearch/WebFetch grant, so the invariant holds by
  construction (the "make it structurally impossible" principle), not by a check.

## Cost / cadence (opt-in)
`verify` runs sandbox + per-case subagents = minutes; it is **not** in the default `plugin-audit`. It runs via
`plugin-audit verify`. Tier A cases are cheap (mostly deterministic);
Tier B adds judge votes. Telemetry counts `verify` invocations so Axis 11 (usage) catches it going stale.
