# Harness Nightly Routine (native `/schedule` recipe)

> Leaning on battle-tested mechanisms, this recipe makes harness
> monitoring unattended via **Claude Code's built-in `/schedule` (cloud routine) or `/loop`**,
> not a home-grown launchd/cron. The plugin only provides this recipe; enabling it — and the
> billing — is the user's call (⚠️ routines are billed to the user).

## What gets automated

The SessionStart opportunistic trigger (24h throttle) runs "whenever a session is opened".
Add this routine only if you want fully unattended runs. Duplication is harmless — pending-channel is idempotent.

| Frequency | What runs | Output |
|---|---|---|
| Nightly (daily) | store sync health + `harness-drift-check.sh` (drift between the edit repo ↔ live cache) | drift section of `<base>/checkpoints/pending.md` |
| Weekly | `dead-skill-report.sh` (dead-skill candidates) + `lexicon-distill.sh` (search-lexicon candidates) | pending.md / append candidates to the search lexicon |

## Setup (recommended: native `/schedule`)

In a Claude Code session, launch:

```
/schedule
```

and create the following routine (cron: daily at 02:30). Example prompt:

```
In this repository, every day at 02:30, run banto's harness health checks.
Specifically, run scripts/harness-drift-check.sh and scripts/dead-skill-report.sh,
and aggregate the output into <store base>/checkpoints/pending.md (via pending-channel.sh).
If drift or dead-skill candidates appear, report only a summary. If there is no diff, do nothing.
```

Run it in an environment where `PLUGIN=$CLAUDE_PLUGIN_ROOT` can be resolved (a normal local setup).
In configurations where the cloud routine cannot touch the store's local paths (headless),
the SessionStart opportunistic trigger is sufficient.

## Alternative: `/loop` (self-pacing)

If you can keep a resident session, `/loop` works instead of an unattended cron:

```
/loop /harness-audit
```

## Alternative: launchd / cron (legacy, not recommended)

If you must use the OS scheduler, see `com.banto.ai-context-nightly.plist.example`
(for nightly store auto-push). But a home-grown scheduler is less lean — you own PATH /
auth / log management yourself. For new adoption, prefer the native `/schedule`.

## Why the plugin doesn't wire this up automatically

- Like the anti-goal "don't bind humans with approval gates", **never plant resident processes in the user's environment unasked**.
- Never silently enable a cloud routine that incurs billing (⚠️ Ask first).
- Self-driving "without thinking about activation" already works via the SessionStart opportunistic trigger; the routine is an add-on.
