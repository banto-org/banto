# Banto

**Self-driving harness for Claude Code.** You set the vision; Banto runs the development.

A *bantō* (番頭) is the head clerk of an Edo-period merchant house: the owner decides direction,
the bantō runs everything end to end and brings only the exceptions back. Banto applies that
contract to AI-driven development — it holds your ideology, decisions, and knowledge, feeds them
to Claude, and self-drives. Exceptions arrive as checkpoints; safety is enforced by deterministic
hooks, not promises.

[日本語 README](README.ja.md)

> **Status: beta.** Banto is dogfooded daily on its own development, but the public packaging is
> young. Expect rough edges; issues and PRs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## What you get

- **SDD pipeline** — `concept` (ideology) → `spec` (industry-standard design docs) → autonomous
  implementation. `dev-loop` drives the self-driving build cycle (decompose → implement → verify →
  fix until tests are green, escalating only exceptions). The philosophy layer is injected into
  CLAUDE.md as a judgment filter.
- **AI context that survives sessions** — decisions / research docs / tasks / checkpoints live in
  a central knowledge store (`~/ai-context-store/<project>/`) and are re-injected at session
  start. **Your repos stay clean** — knowledge goes to the store, code stays in the repo.
  Claude-native internal search (query expansion + ranking) over everything you've accumulated.
  The store layout is a stable read contract for external tools:
  [directory structure](plugins/banto/i18n/en/skills/ai-context/references/directory-structure.md).
- **Deterministic safety hooks** — kill-switch (no direct push to main, no `--no-verify`, no
  force-push), egress guard (blocks internal names / PII from leaking into client deliverables,
  driven by a private name registry), verify-before-claim (no "done" without verified output).
- **Optional OS sandbox (opt-in)** — a second, deterministic layer beneath the hooks: Claude's bash
  can run inside an OS sandbox (macOS Seatbelt / Linux & WSL2 bubblewrap) that blocks reads of
  credential dirs (`~/.ssh`, `~/.aws`, …) and outbound network outside a small allowlist
  (github / npm / pypi / anthropic). **Off by default** — `harness-setup.sh` ships the hardened
  block disabled; flip `sandbox.enabled: true` in settings.json to turn it on. Only Claude's bash is
  affected — your own terminal and the permission prompts are unchanged. Defense-in-depth with the
  egress guard. See [Sandboxing docs](https://code.claude.com/docs/en/sandboxing).
- **Workspace & fleet operations** — topic-based workspaces with a 3-tier branch model
  (main ← epic ← task worktree, orchestrated via git-town), session registry with collision
  detection for parallel sessions.
- **Self-auditing** — 14-axis plugin quality audit (including content-hygiene checks) and a
  5-axis whole-harness audit that watches for drift between declarations and reality.
- **Japanese-canonical, switchable language** — skills and agents are authored in Japanese; the
  English set is generated from them and kept in sync by a deterministic gate. `/set-language ja|en`
  swaps the whole set to one language, and the choice survives plugin updates (public default: English).

21 skills / 6 agents / 49 hooks / 7 behavioral rules. No bundled MCP servers. Security review and
code review are deliberately **delegated to Anthropic's official plugins** rather than reimplemented.

## Requirements

- [Claude Code](https://code.claude.com/) (CLI or desktop)
- `git`, `jq` (required) — `gh`, `git-town`, `python3` unlock optional features (author detection,
  3-tier branching, egress guard / web extraction); everything degrades gracefully without them

macOS / Linux supported. Windows runs on Git Bash (bundled with Git for Windows) — statically
audited, real-device verification pending. Known limitations:

- `jq` is required there too — without it every hook silently no-ops (`winget install jqlang.jq`)
- python3-gated features (PII egress guard, search-index rebuild) skip gracefully when absent
- Obsidian vault integration is macOS-only and exits with a clear message elsewhere
- hooks spawn background processes on file edits, which is slower on Windows — expect minor latency

## Install

```bash
claude plugin marketplace add banto-org/banto
claude plugin install banto@banto-marketplace
```

Restart Claude Code. On a project without a CLAUDE.md, the SessionStart hook prompts the one-time
setup with the exact command. To run the user-level harness setup yourself:

```bash
sh "$(ls -d ~/.claude/plugins/cache/*/banto/*/ | sort -V | tail -1)scripts/harness-setup.sh"
```

This deterministic script deploys the behavioral rules, statusline, minimal permissions, and the
**disabled** OS-sandbox block (opt-in; flip `sandbox.enabled: true` to use it), and initializes the
central knowledge store; `--plan` previews without applying. CLAUDE.md is generated
by **native `/init`**; per-project rules via `harness-setup.sh --project`. Code review and security
review delegate to the native `/code-review` / `/security-review` (Banto does not reimplement or
auto-install them). The store is **bootstrapped once, interactively**: on a repo's first session the
SessionStart hook asks (instead of silently creating a local store) whether you already have a GitHub
`ai-context-store` to register, want to create one (and in which org), or prefer local-only — the
chosen org is remembered for later projects. git-sync the store when working as a team.

### Migrating from a local store (`~/ai-context-local`)

If a project's first session ran before any central store existed (or you chose local-only), its
knowledge lives in `~/ai-context-local/<project>/`. Once you adopt a central `~/ai-context-store`,
path resolution prefers the central mapping — a leftover local store is silently shadowed and stops
receiving new records. Migrate it once, then remove it:

```bash
# 1. see which projects are still local
ls ~/ai-context-local

# 2. copy the knowledge into the central store (derived artifacts excluded; never overwrites)
rsync -a --ignore-existing \
  --exclude '*-combined.txt' --exclude 'project-index/' --exclude 'full-index/' --exclude '.obsidian/' \
  ~/ai-context-local/<project>/ ~/ai-context-store/<project>/

# 3. register the repo in the central mapping (key = the repo's git toplevel path)
jq --arg top "/path/to/repo" --arg p "<project>" '.projects[$top] = {project: $p}' \
  ~/ai-context-store/.mapping.json > /tmp/m.json && mv /tmp/m.json ~/ai-context-store/.mapping.json

# 4. after verifying the copy, drop the local side (mapping entry + project dir)
jq 'del(.projects["/path/to/repo"])' ~/ai-context-local/.mapping.json > /tmp/l.json \
  && mv /tmp/l.json ~/ai-context-local/.mapping.json
rm -rf ~/ai-context-local/<project>
```

Start a new session in the repo and check the SessionStart banner: the injected base should now be
`~/ai-context-store/<project>`. Or skip the commands and ask Claude in that repo's session —
*"migrate this project's ai-context-local into the central store"* — these steps are exactly what it
runs. (In-repo `.ai-context/` directories from pre-store versions have their own guided path:
`/ai-context migrate`.)

### Staying up to date

`harness-setup.sh` also sets `autoUpdate: true` for the Banto marketplace in your `settings.json`
(third-party marketplaces default to off), so new releases are picked up automatically at session
start. To apply an update mid-session, run the interactive `/reload-plugins` command (hooks and MCP
servers reload; a full restart is only needed for monitors). Manual update, if you prefer:
`claude plugin marketplace update banto-marketplace && claude plugin update banto@banto-marketplace`.

## Language (default is English)

To switch the skill / agent set to Japanese, run this **once**:

```
/set-language ja
```

then run **/reload-plugins** (or restart Claude Code) to load the Japanese set. The choice is persisted and **survives plugin updates**, so you **never need to do it again** (use `/set-language en` + reload only to switch back).

## How it feels

You don't memorize commands — natural language is the primary path and commands are aliases:

| You say | Banto does |
|---|---|
| "start the payment redesign" / 「決済のリデザインを始める」 | opens an epic branch + workspace |
| "investigate X" / 「X を調べて」 | research agents fan out, findings saved to the knowledge store (`docs/research/`) |
| "what did we decide about auth?" / 「認証って前に決めたっけ」 | internal search over decisions and history |
| "this work is done" / 「この作業終わった」 | tests → merge to the epic → sync → cleanup |
| "ship it" / 「main に入れて」 | opens a PR — **irreversible/outward actions always stop at a human gate** |

## Philosophy (the short version)

- **Self-driving, not approval-gated** — enforcement belongs to hooks; approvals stay minimal.
- **Deterministic over promised** — anything that must never happen is blocked by a hook, not a prompt.
- **Lean** — delegate to proven mechanisms (git-town, official plugins) instead of reinventing.
- **Measure, then fold** — telemetry tracks skill usage; dead features get removed.

Full ideology: [CONCEPT.md](CONCEPT.md)

## For teams working under NDA

Banto was built inside a contract-development workflow where leaking one internal name into a
client deliverable is an incident. The egress guard blocks writes of registry-listed names into
client paths; the name registry lives in user scope and is never committed; content-hygiene audits
detect proprietary references and pasted session debris in docs.

## License

[MIT](LICENSE)
