# Contributing to Banto

Issues and pull requests are welcome. Banto is young — bug reports from real
environments (especially Windows / Linux) are as valuable as code.

## Before you open a PR

Run the same gates CI runs — all local, all fast:

```bash
# syntax
for f in $(git ls-files '*.sh'); do sh -n "$f"; done
for f in $(git ls-files '*.json'); do jq empty "$f"; done

# naming gate (CI runs both scopes)
sh scripts/check-legacy-names.sh --code
sh scripts/check-legacy-names.sh

# unit tests — run them all (same set as CI; new test-*.sh are picked up automatically)
for t in plugins/banto/scripts/test-*.sh; do sh "$t" || exit 1; done
```

CI additionally gates declaration sync (plugin.json / marketplace.json versions and the
skill count in both READMEs) — if you add or remove a skill or registered hook, update
`README.md` / `README.ja.md` / `CLAUDE.md` counts in the same PR.

Optionally run the full clean-room suite in an Ubuntu container (dash / GNU coreutils):

```bash
sh scripts/clean-room-test.sh
```

In a Claude Code session with Banto installed you can also self-audit:
`/plugin-audit <skill>` (14-axis skill quality audit) and `/harness-audit`
(whole-harness consistency, including declaration-vs-reality drift).

## Content hygiene (hard requirement)

Banto is developed under NDA discipline. Anything you submit must be free of:

- real personal names, company names, internal project names
- personal absolute paths (`/Users/<name>/...`) and email addresses
- pasted session output (terminal logs, tool results, timestamps)

Use placeholders instead (`<author>`, `/path/to/project`, "Person A"). The
plugin-audit content-hygiene axis (Axis 14) checks for exactly this.

## Design ground rules

`CONCEPT.md` is the judgment filter for every change. In short:

- **lean** — reuse proven mechanisms (git, Claude Code built-ins, official plugins)
  before writing new ones
- **deterministic** — enforcement belongs in hooks (exit codes), not in prose
  instructions; the hook contract is documented in `plugins/banto/hooks/CONTRACT.md`
- **no approval gates, no instruction walls, no dead features** — every skill must be
  reachable by natural language; commands are aliases, not the interface

Proposing a new skill? Open a *skill proposal* issue first (template provided) — it
asks for the trigger phrases, the ODD autonomy level, and why an existing skill
can't cover the job.

## Commit convention

`<type>(<scope>): <subject>` — e.g. `fix(hooks): guard scaffold to git toplevel`.

When behavior changes, bump `plugins/banto/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` **in the same commit** — CI fails on version drift.

## License

MIT. By contributing you agree your contribution is licensed under the same terms.
