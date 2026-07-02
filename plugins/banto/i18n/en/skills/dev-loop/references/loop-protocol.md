# Dev-Loop protocol details

Supplements SKILL.md: the concrete iteration, state files, cadence, and the swap point for the ML training loop.

## State files (written by the existing ② build-and-verify · canonical)

| File | Writer | Content |
|---|---|---|
| `$HOME/.cache/banto/verify-last-<session>` | `verify-run.sh` | `green` / `green (no verify commands detected)` / `red:<failed steps>` |
| `$HOME/.cache/banto/test-failures-<session>` | `auto-test.sh` / `verify-run.sh` | TF counter (reset to 0 on green · +1 on red) |

`<session>` resolves in 3 steps: `BANTO_SESSION_ID` / `CLAUDE_SESSION_ID` (env) → the per-cwd pointer `session-current-<cwd_id>` that odd-gate leaves on PreToolUse:Write|Edit (in an implementation loop a preceding Edit always writes it) → `manual` when neither exists. State dir is `ODD_STATE_DIR` (default `$HOME/.cache/banto`). The pointer key is a cksum of the cwd, so **call verify-run from the session cwd (the repository root)** — pointing it at a subdirectory splits the key and falls back to manual.

## How to run a full verify

```sh
sh "$CLAUDE_PLUGIN_ROOT/hooks/verify-run.sh" <project_dir>
# exit 0 = green (or no verify commands) / exit 2 = red
# detection is canonical in verify-detect.sh (BUILD_CMD / TEST_CMD / API_SMOKE_CMD)
# the result is one line in verify-last-<session>
```

On red, stderr carries each step's PASS/FAIL plus the last 8 lines of the failed step. Hand that to the debugger agent to get the root cause.

### no-commands fallback (markdown / config / docs repos)

In repos with no build/test/api commands (markdown-centric plugins, config repos, etc.) `verify-run.sh` returns "nothing to verify (exit 0)". This means "out of scope for the generic runner," not "verification skipped" — so **fall back to a domain-specific check**:

| Repo kind | Fallback verification |
|---|---|
| The banto plugin itself | Re-run the audit script that flagged it (`plugin-audit-interface.sh` / `-collect.sh` etc.) + the active=canonical diff after i18n materialize |
| Shell scripts | `sh -n` (syntax) / shellcheck |
| YAML / JSON config | Schema / parser validation (`jq empty` / `yaml.safe_load`) |
| Docs only | Broken-link / reference-exists / leftover-placeholder checks |

The green/red decision is the same (pass the fallback check → treat as green and move on; fail → red and fix).

## Iteration pseudocode (Phase 1)

```
while tasks.md has a [ ]:
    task = ai-context next (the first [ ] with dependencies cleared)
    if task is in a parallel-flagged group:
        fan out multiple Agents in one message (no shared file is the precondition)
    else:
        implement (Edit/Write)
    sh verify-run.sh <project>
    if red:
        if TF counter >= 3 (odd-gate already blocked edits):
            STOP → escalate to owner (do not churn)
        else:
            fix with the debugger agent → re-run verify-run.sh
    else (green):
        mark the tasks.md line [x]
        git add -A && git commit (branch only · do not push)
```

## Escalation conditions (the bantō brings only exceptions to the owner)

- 3 consecutive test failures (odd-gate's TF threshold reached)
- About to claim "done" while verify-last is red (verify-claim-guard blocks it on Stop)
- goal fork (A/B changes acceptance criteria / impact surface / security meaning, or depends on owner-specific business knowledge)
- ambiguous spec where no adopted interpretation holds
- request for an irreversible / outward-facing op (push・PR・main・delete・external post)

In every case, **stop and escalate to the owner**. Do not push it through inside the self-driving loop.

## Choosing a cadence

| Situation | Driver | Why |
|---|---|---|
| Run it all now within this session | inline (run Phase 1 in order) | fastest · no extra machinery |
| Run unattended / poll while working | native `/loop` (self-paced · one iteration = next task) | in-session · 7-day expiry |
| Persistent / overnight / PC-off | Routine (cloud · `schedule` skill) | runs on schedule / GitHub trigger |

Using `/loop` with no args is self-paced (the model decides the next wake-up). Follow the native `/loop` skill for details.

## ML training loop (variant)

Same skeleton as the dev loop, **swapping only the verify step**:

| dev loop | ML training loop |
|---|---|
| implement (Edit/Write) | train step (small task: 1 epoch / 1 config) |
| `verify-run.sh` (build/test/api) | the training script's **eval** (emits a metric in one line) |
| green = tests PASS | green = metric hits target or improves |
| red = tests FAIL | red = metric regresses / misses |
| retry cap = odd-gate (3 consecutive) | retry cap = no improvement for N iterations (plateau detection) |
| done = tasks.md exhausted | done = target reached or plateau |

If the eval writes its green/red as a verify-last-compatible one-liner (`green` / `red:<metric>`), the verify-claim-guard and escalation machinery carry over as-is. To wire a training skill like `moe-pruning`, plug its eval into the verify step.

## tasks.md ledger

- Location: per-ws `workspaces/<author>/[scope] topic/tasks.md` (under the store base).
- Format: `- [ ]` (todo) / `- [x]` (done) / `- [~]` (in progress · partial).
- next / phase-done are owned by the `ai-context` skill. dev-loop just calls them and does not reimplement the ledger logic.
