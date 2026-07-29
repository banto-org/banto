# Change safety rules

Code of conduct for AI behavior in general (always applied). Editing constraints for lockfiles / manifests are split into `dependencies.md` (path-scoped).

## Operational safety

- File edits, test runs, local operations → run freely
- File deletion, git push, PR creation, posting to external services → confirm with the user first. Approval given in the conversation is sufficient — once the user approves, execute without re-asking. A standing per-repo approval can be recorded in the ai-context store grants file (`{base}/meta/grants.json`, keys: `pr_create` / `push_feature` / `prod_ops`); `allow` there counts as the user's confirmation for that repo (enforced by `release-guard.sh` / `prod-guard.sh`).
- --no-verify, force-push, direct push to main/master → forbidden
  - Exception: direct push to main is allowed for ai-context knowledge stores (repos with the marker `.ai-context-store` at the repo root).
    Push policy is separated from code repos (PR-gated) — same marker check as the existing kill-switch.
    This exception is limited to store paths carrying the marker and never extends to code repos.
- Never merge a PR created by someone else. Even with the user's explicit permission, don't execute it yourself — have the user merge it themselves
- Production-environment operations (deploys, prod DB / infra changes) → blocked by default (`prod-guard.sh`); allowed only via conversation approval (escape) or a standing `prod_ops: allow` grant.

## Secret protection

- Never commit .env, credentials, or secrets
- Never display files containing .env / credentials / API keys in raw `cat` / `diff` / `grep` output in the terminal or chat. Always mask values:
  - When values are needed: print key names only with `sed 's/=.*/=***/'`
  - Diff checks: mask both sides before comparing with `diff`
  - grep targets: restrict to prefixes like `grep "^AWS_"` so tokens (`HF_TOKEN`, `GH_TOKEN`, `*_API_KEY`, `*_SECRET`, `Bearer *`) aren't swept in
  - Delete backup files (`.env.old`, etc.) as soon as they've served their purpose
- **Never use `bash -x`, `set -x`, `env`, `set`, `declare -p`, `printenv` for debugging** — values from a sourced `.env` leak into the trace and stay in chat history. Instead:
  - Echo individual variables explicitly masked (`echo "KEY=[${#VAR} chars]"`)
  - Or temporarily use a stub `.env` without secrets (`MY_API_KEY=dummy bash script.sh ...`)
- If a secret is ever exposed, notify the user immediately and strongly recommend revoke / rotation (it remains in chat history)
