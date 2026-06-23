---
name: dev-loop
description: |
  Self-driving development loop: auto-decompose a big task (spec / document / large task) into small tasks, then implement → verify (② build-and-verify) → detect problems → fix → re-verify, looping until tasks.md is green, escalating only exceptions to the owner. An orchestrator that ties together ② verify-run + ④ parallel decomposition + spec + debugger + /loop (no new scripts). Swap the verify step for an eval metric and it becomes the ML training loop (train→eval→adjust).
  Triggers: "self-drive the development", "decompose this big task and run it", "loop the development", "just do all of it (big task)", "auto-implement and test it", "dev loop", "training loop". Also invocable via /dev-loop.
  Do not use when: a small one-off edit (edit directly) / advancing just the next single task (ai-context next is enough) / design only (spec) / ideology only (concept) / branch・worktree operations (ws).
allowed-tools: Read Grep Glob Edit Write Bash Agent Skill
user-invocable: true
argument-hint: "[start|status|stop] (defaults to natural-language intent detection)"
model: opus
compatibility: Claude Code (requires bash, git, jq)
---

# Dev-Loop — self-driving development loop (decompose → implement → verify → fix → loop)

> **Storage base (store-first)**: Read/Write of `tasks.md` / decisions and other `.ai-context/...` paths happens under the 「ai-context ベース: &lt;絶対パス&gt;」 (absolute path) injected by the SessionStart/PreCompact hooks. If unknown: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`.

The owner hands over a big task → decompose into small tasks → implement each, verify with ② build-and-verify, fix and re-verify if red, move on if green. Self-drive until tasks.md is exhausted, escalating **only exceptions to the owner** (the bantō contract). Every part already exists — **no new scripts are created**.

## Activation conditions (all must hold)

- The owner asked to self-drive a big task (spec / doc / large task) — "run it", "do all of it", "dev loop"
- It decomposes into small tasks, and the implement → verify → fix cycle runs multiple times
- It is not a one-off edit

**Does not fire**: a small one-off edit (direct Edit) / advancing just the next task (`ai-context` next) / design only (`spec`) / ideology only (`concept`).

## Autonomy level (L3 · Autopilot)

odd.yaml = **L3 (Autopilot = continuous execution + user requested on exceptions)**. banto covers L0–L3 only (L4+ belongs to a separate plugin `banto-autonomy`). Explicit stops are deterministic hooks (`odd-gate` / `verify-claim-guard`); human gates are the Phase 0 decomposition-plan confirmation and push/PR/main.

## Loop procedure

### Phase 0: fix the input and decompose
1. Identify the input (the current ws's big task / a given spec / a document).
2. If there is no spec, use the `spec` skill to decompose requirements into small tasks → write them as `[ ]` in the per-ws `tasks.md`.
3. Using ④'s criteria (no shared file, no sequential dependency), flag independent small tasks as **parallel** (fan-out Agent candidates).
4. **Present the decomposition plan (small-task list + parallel strategy) to the owner once and confirm** (the L3 human gate). After confirmation, run until an exception.

### Phase 1: iterate (until tasks.md is exhausted)
For each task:
1. Get the next `[ ]` (with dependencies cleared) via `ai-context` next. Parallel-flagged groups fan out as multiple Agent calls in one message; the rest run serially.
2. **Implement** (Edit / Write). On each edit the PostToolUse `auto-test.sh` runs the related test. After 3 consecutive failures `odd-gate.sh` auto-blocks edits (churn prevention = the existing retry cap).
3. **Full verify**: `sh "$CLAUDE_PLUGIN_ROOT/hooks/verify-run.sh" <project>` (aggregates build → test → api; exit 0=green / 2=red; result in `$HOME/.cache/banto/verify-last-<session>` as `green` or `red:<steps>`).
4. **red** → fix the root cause with the `debugger` agent → back to 3. If you hit `odd-gate`'s 3-consecutive-failure guard, **stop the loop and escalate to the owner** (do not churn).
5. **green** → mark the `tasks.md` line `[x]`, commit to the branch (push / PR / main stay human-gated = existing safety).

### Phase 2: convergence / exception
- tasks.md exhausted → completion report (summary of implementation, verification, adopted interpretations). If a phase is complete, archive to `tasks-old/` via `ai-context` phase-done.
- Exception (consecutive failures / goal fork / ambiguous spec / request for an irreversible operation) → **stop and escalate to the owner**.

Detailed procedure, cadence, ML training loop: [`references/loop-protocol.md`](references/loop-protocol.md)

## Driving the loop (cadence)

- Default is **inline self-driving** (run Phase 1 in order within this session).
- To run unattended / long-running, wrap with native `/loop` (self-paced) so one iteration = the next task. For persistent / overnight / PC-off, use a Routine (cloud · `schedule` skill).

## Guardrails (deterministic · existing hooks)

| Guard | hook | Effect |
|---|---|---|
| Stop churn | `odd-gate.sh` (PreToolUse) | Block edits after 3 consecutive test failures → go to root cause |
| Prevent false green | `verify-claim-guard.sh` (Stop) | Block "done" claims while verify-last is red |
| External egress | `egress-guard.sh` + ⑤ sandbox | Block leakage of secrets / other-project names into client paths |
| Irreversible ops | safety rule | push / PR / main / delete are human-gated |

## ML training loop (variant)

A variant that **swaps only the verify step** (Phase 1 step 3) from "tests" to an **eval metric**. train step (small task) → eval → green/red by the metric → adjust and re-train → loop until target / plateau. Run the training script's eval instead of `verify-run.sh`; the green/red, retry cap, and escalation skeleton are identical. Details: [`references/loop-protocol.md`](references/loop-protocol.md).

## Usage (intent detection — no need to memorize commands)

- `/dev-loop` (no args): infer intent from the conversation (present the decomposition plan if a big task exists)
- `/dev-loop start`: start the self-driving loop (Phase 0 → confirm → Phase 1)
- `/dev-loop status`: current tasks.md progress · last verify result · retry counter
- `/dev-loop stop`: stop iterating (state remains in tasks.md)

## Related

Decompose: `spec` / task ledger & next: `ai-context` / parallelism call: `ws` (proactive parallelism proposal) / verify: ② build-and-verify (`hooks/verify-*.sh`) / fix: `debugger` agent.
