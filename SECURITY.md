# Security Policy

## Reporting a vulnerability

Please report vulnerabilities **privately** via GitHub Security Advisories
("Report a vulnerability" on the repository's Security tab). Do not open a public
issue for security reports. You can expect an initial response within 7 days.

In scope, in particular:

- Bypasses of the deterministic safety hooks (`odd-kill-switch.sh`, `safety-guard.sh`,
  `egress-guard`, `release-guard.sh`, `lint-guard.sh`) — e.g. a command form that
  reaches `git push origin main`, raw `.env` output, or an internal-name egress
  without the documented escape hatches
- Ways to make a hook write outside its documented filesystem footprint
  (`hooks/CONTRACT.md`)
- Secret or PII leakage through Banto's own artifacts (telemetry, store scaffolding)

## Supported versions

Only the latest released version on the marketplace is supported. Banto follows
semver; security fixes ship as patch releases.

## Design notes for researchers

- Hooks are **fail-open on missing dependencies** (no `jq` → the plugin disables
  itself) but **fail-safe on positive detection** — see `hooks/CONTRACT.md`.
- Escape hatches (`ODD_ALLOW_*`, `BANTO_ALLOW_*`) are deliberate, documented,
  per-invocation opt-outs; reports that only use them are not vulnerabilities.
- The safety cores carry synthetic payload test suites
  (`plugins/banto/scripts/test-odd-kill-switch.sh`, `test-egress-guard.sh`,
  `test-hook-payloads.sh`, `test-release-guard.sh`) — a reproducing test case in
  that style makes a report immediately actionable.
