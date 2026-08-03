---
name: policy
description: |
  **UTILITY SKILL** — a policy console that lists and edits the per-repo policy canon (`{store}/{project}/meta/policy.json` = grants + ignore) in a single-screen GUI. Changes save automatically in place and take effect on hooks immediately; commit + sync to the store is also automatic. The server auto-terminates on any of: clicking "Done, close", closing the tab, or 15 minutes of idle time (it does not stay resident). Changes made from conversation edit the same policy.json (same canon).
  Triggers: "show me the policy", "list the grants", "ignore settings", "policy console", "what have I already approved". Can also be launched with /policy.
  Do not use when: a one-off grants change made in conversation (the ai-context skill's grants management is enough).
user-invocable: true
allowed-tools: Read Edit Write Bash
compatibility: Claude Code (requires python3, git)
---

# Policy Console

The per-repo policy canon is `{store}/{project}/meta/policy.json`:

```json
{"grants": {"pr_create": "allow"}, "ignore": {"no_edit": ["*.env"], "no_sync": ["private/**"]}}
```

- `grants` (`pr_create` / `pr_merge` / `push_feature` / `prod_ops` + any custom key) is resolved by release-guard / prod-guard. Values are `allow` / `confirm` / `deny` (missing defaults to `confirm`). A time-boxed object form `{"value": "allow", "until": "YYYY-MM-DD"}` is also supported. Falls back to the legacy `meta/grants.json`
- `ignore.no_edit` is enforced by policy-guard.sh (blocks edits); `ignore.no_sync` is enforced by ai-context-sync.sh (via the store's `.git/info/exclude`)
- The target stores are listed in `~/.claude/banto-ai-context-stores` (one store path per line), falling back to `~/ai-context-store` if absent

## Launching (listing and editing share one screen)

Launch Bash with `run_in_background=true`, then `open` the URL (with token) printed on stdout:

```bash
# 1) Launch in the background (prints one URL line to stdout)
python3 "$CLAUDE_PLUGIN_ROOT/scripts/policy-console.py"
# example output: http://127.0.0.1:53201/?t=XXXX

# 2) Open the printed URL as-is
open "http://127.0.0.1:53201/?t=XXXX"
```

Screen behavior (tell the user about this):

- **Changes save automatically**. There is no save button — changing a select or a pattern field writes to policy.json in place, taking effect on hooks immediately. Commit + sync to the store runs automatically a few seconds later
- **Claude Code layer card (top of the screen)**: adds / removes `Bash(gh pr merge:*)` + `Bash(gh pr checks:*)` in the permissions.allow list of `~/.claude/settings.json` with one click (backs up to settings.json.bak before writing). This is layer 1 (a command-class allowance shared across all repos); whether a merge actually passes is decided by layer 2 = the per-repo `pr_merge` grant. **The only trigger for this write is a human click** — this split keeps the feature consistent with Claude Code's design of blocking AI self-authorization, and the AI must never edit this file directly
- **The server does not stay resident**. Clicking "Done, close" in the top right shuts down both the screen and the server. Closing the tab auto-terminates it within a few seconds; leaving it idle auto-terminates it after 15 minutes (change with `--idle-timeout <seconds>`, or `0` to disable)
- Bound to 127.0.0.1 and requires a random token (a mismatch returns 403). The URL changes on every launch
- For a project that only has grants.json, a change creates a new policy.json (grants.json is kept)

Because it auto-terminates, KillShell is normally unnecessary. Launch with `--idle-timeout 0` only if the user says to leave it open.

## Changes from conversation (same canon as the GUI)

Even without opening the GUI, changes edit the same policy.json:

1. Read → Edit `{store}/{project}/meta/policy.json` (if absent, create it by importing the grants from grants.json; grants.json is kept)
2. Sync to the store with `sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-sync.sh" <store>`
