# CLAUDE.md — banto

Development repo for **Banto**, a Claude Code plugin (self-driving harness: SDD workflow + AI
context store + deterministic safety hooks). The plugin itself lives in `plugins/banto/`.

## North star (ideology layer)

@CONCEPT.md

The CONCEPT.md above is this repo's judgment filter. **Never implement against it; optimize toward
it.** (The concept → spec → autonomous-implementation pipeline is dogfooded on this repo itself.)

## Project facts

- Type: Claude Code plugin (marketplace distribution). Core: `plugins/banto/`.
- Layout: 18 skills (15 in v1 public scope; 3 dev-only via PLUGIN_EXCLUDE: status [pending telemetry
  review] + harness-audit [meta self-audit] + banto-port [maintainer-only: ports banto's own dev tree
  to public]) / 6 agents / 41 registered
  hooks (47 script files — 6 unregistered helpers invoked indirectly: scaffold / dashboard /
  pending-channel / egress-guard.py / verify-detect / verify-run; model-lab adds repro-gate /
  model-claim-guard / compute-cost-gate + scripts/ helpers repro-check / eval-stats / claim-link) / 9 rules. No bundled MCP.
  Version: `plugins/banto/.claude-plugin/plugin.json`.
- Languages: POSIX sh (hooks) + Markdown (skills / rules / docs). `jq` required.
- Knowledge base (store-first): the ai-context base injected at SessionStart — central store
  `~/ai-context-store/<project>/` (decisions / docs/research / tasks / sessions / workspaces;
  model-lab adds experiments/ for its claim ledger).
  Save design decisions under `{base}/decisions/`. (No in-repo `.ai-context/` since 5.30.)

## Development flow (specific to this repo)

- **Keep the edit repo = the live plugin in sync**: after editing skills/hooks, bump the version and run
  `claude plugin marketplace update banto-marketplace && claude plugin update banto@banto-marketplace`,
  then restart Claude Code. Never leave same-version different-content drift.
- Meta tools: `/plugin-audit` (15-axis skill quality) / `/harness-audit` (5-axis whole-harness system
  audit) / `/plugin-dev` (generate & refactor). Self-check consistency with harness-audit after changes.
- Install: `claude plugin marketplace add <marketplace>` + `claude plugin install banto@<marketplace>`,
  then run `scripts/harness-setup.sh` (deterministic user-level setup; CLAUDE.md via native `/init`).
- Tests: hooks via `sh -n` + synthetic transcript/payload unit tests; skills via dogfooding.
  Brand gate: `scripts/check-legacy-names.sh` (--code / full scopes).

## Rules

- Behavioral rules (quality / safety / PII / evidence-first / spec-fidelity) are deployed to
  `~/.claude/rules/` (user scope); distribution templates live in `plugins/banto/templates/rules/`.
- Direct pushes to main/master are blocked by `odd-kill-switch.sh` (go through PRs).
- Confirm before deleting files, pushing, creating PRs, or posting externally. Never commit secrets.
