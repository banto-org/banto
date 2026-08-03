# Hook Contract

The compatibility contract for every hook in this directory — for contributors,
for other plugins coexisting with Banto, and for tools reading Banto's artifacts.
This documents existing deterministic behavior; it adds no new mechanism.

## Exit codes (all hooks)

| exit | meaning | effect |
|---|---|---|
| `0` | pass | stdout is consumed per event type (table below); empty stdout = silent no-op |
| `2` | deterministic block | the action is stopped; stderr is fed back to Claude as the reason |
| other | unexpected failure | non-blocking; the session continues (fail-open) |

One additional blocking path exists for PreToolUse: a hook may print
`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}`
to stdout with exit `0` (used by `askuser-deny.sh` to disable AskUserQuestion, and by
`webfetch-deny.sh` style guards). Claude Code treats the JSON decision as the block.

## Fail-open by design

A missing dependency must never break a user's session:

- `jq` absent → every hook exits 0 silently (the plugin effectively disables itself)
- `python3` absent → python-gated hooks (egress-guard, index-rebuild) skip,
  with at most a one-line stderr note
- optional config absent (name registry, `banto-ignore`, store mapping) → no-op

The inverse holds for the safety hooks: **fail-safe on positive detection**.
When egress-guard or the ODD kill-switch decides to block, it blocks with exit 2
regardless of what other plugins' hooks would allow — Claude Code stops the tool
call on the first blocking result. Hook execution order across plugins is not
guaranteed, and Banto does not depend on it.

## stdout consumption per event

| event | stdout (exit 0) goes to |
|---|---|
| SessionStart / UserPromptSubmit | injected into Claude's context |
| PreToolUse | not injected — block via exit 2 (stderr = reason) or via the `permissionDecision` JSON above |
| PostToolUse | fed back to Claude as tool feedback |
| Stop | background work; may request **one** extra turn via exit 2 (`ai-context-stop.sh` / `verify-claim-guard.sh`, re-entry guarded by `stop_hook_active` and a lock — never an infinite loop) |
| SessionEnd / PreCompact | background work only; never block |
| SubagentStart / SubagentStop / UserPromptExpansion | background tracking only (ODD parallel counter / skill telemetry); never blocks |

Hooks that inject context keep it to a few lines (anti-goal: instruction walls).

## Filesystem footprint

Hooks write only to:

- the resolved ai-context base — the central store (`~/ai-context-store/<project>/`,
  overridable via `AI_CONTEXT_STORE_ROOT`), or a grandfathered in-repo `.ai-context/`
  that existed before store-first
- `~/.cache/banto/` and `${TMPDIR:-/tmp}` (regenerable state)

**Nothing in the user's repo is ever created or modified by hooks — zero exceptions**
(store-first, since 5.30.0). Store-side registration/scaffolding happens only for a git
work-tree root — never for subdirectories, `$HOME`, the filesystem root, or non-git
directories (`hooks/_ai-context-scaffold.sh`, covered by
`scripts/test-scaffold-root-guard.sh` and `scripts/test-store-first-session.sh`).

## Build-and-verify loop (since 5.48.0)

Self-driving implementation verifies before claiming done (Option A — explicit; spec
`docs/specs/2026-06-22_build-and-verify-loop`):

- `verify-detect.sh <dir>` (helper) detects the project's build / full-test / API-smoke
  commands; `--runner <dir>` returns the test-runner token (shared with `auto-test.sh`,
  single source of truth).
- `verify-run.sh <dir>` (helper, invoked by the loop — not a registered hook) runs
  build → full test → API smoke, writes `~/.cache/banto/verify-last-<session>`
  (`green` | `red:<steps>`), and bumps / resets the shared `test-failures-<session>`
  counter, so a red verify also feeds `odd-gate.sh` (opt-in breaker: blocks only with
  `ODD_TEST_FAILURE_GATE=1`; default is counter-only, stopping is the loop protocol's job).
  API smoke runs the project's package
  script with `NODE_ENV=test BANTO_VERIFY=1` (staging / read-only convention; never production).
- `verify-claim-guard.sh` (Stop) blocks a completion claim while the most-recent
  `verify-last-*` is red (in addition to its error-trace heuristic; one-shot via `stop_hook_active`).

## Warn-only guard hooks

These never block (always exit 0); they surface a one-line stderr note and let the tool call proceed:

- `drift-commit-guard.sh` (PreToolUse Bash, `git commit` segments) — warns when `plugins/banto/`
  has staged changes but `plugin.json` is not part of the same commit (a possible missed version
  bump). No-op outside the banto repo itself (detected via the `plugin.json` marker) and when
  `jq`/`git` are missing.
- `ja-lint.sh` + `ja-lint.py` (PostToolUse Write|Edit on `.md`) — flags Japanese writes that
  deviate from `writing-ja.md` conventions. `ja-lint.sh` is the registered hook; the Unicode-range
  detection itself lives in `ja-lint.py` (python3-gated, same delegation pattern as
  `egress-guard.py`).
- `checkpoint-autofire.sh` (unregistered helper — not invoked directly; detached from both
  `idle-checkpoint-watch.sh` and `checkpoint-recommend.sh`) — shared auto-fire logic for
  `/save-checkpoint`, holding the per-session exclusive lock in one place so the two triggers can't
  double-fire.

## Identifiers other tools may rely on

- store marker: a `.ai-context-store` file at the store root (kill-switch / push-policy checks)
- plugin identity: `plugin.json` `.name = "banto"` (marker-based checks, never path heuristics)
- ODD schema: `templates/odd/odd.schema.yaml` (`banto/odd/v1`, versioned)
- pre-push check convention: if a repo contains `scripts/pre-push-check.sh`,
  `release-guard.sh` runs it before any `git push` and blocks on non-zero exit
  (opt-in per repo; the repo owns its check content; escape: `BANTO_SKIP_PUSH_CHECK=1`)
- `prod-guard.sh` (PreToolUse Bash, deterministic block) — blocks production-environment operations
  (kubectl against a `prod` context/namespace, `terraform apply`/`destroy`, `vercel --prod`,
  `flyctl deploy`, `gcloud app deploy`, `aws --profile *prod*`, `npm/pnpm/yarn/bun run` deploy
  scripts named with `prod`, `ssh` to a `prod` host; extend via `BANTO_PROD_PATTERNS`). Escape:
  `BANTO_ALLOW_PROD=1` (also honored as an in-command prefix assignment on the same segment).
  Fail-open on jq absence / undetected patterns.
- grants file convention: `{base}/meta/grants.json` (`.grants.<key>` = `allow`/`deny`/`confirm`)
  records standing per-repo approvals, resolved deterministically via `_ai_context_grant`
  (`scripts/_ai-context-paths.sh`). `release-guard.sh` reads `pr_create` and `pr_merge` (the
  latter covers others' PRs too — a standing owner decision); `prod-guard.sh` reads
  `prod_ops`. `allow` passes without the env escape, `deny` blocks with no escape guidance, and a
  missing/unset key falls back to `confirm` (today's escape-gated behavior, unchanged).
