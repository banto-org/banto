---
name: banto-port
description: |
  Port changes from the private dev repo into the public Banto tree safely: allowlist review → naming / i18n / hygiene → the full gate suite (brand gate / NDA sweep / syntax / unit tests / clean-room) → export. Every step is a deterministic command with an explicit PASS condition, so it stays safe even on a lower-capability model. Publishing (commit / push) is always a human gate.
  Triggers: "port changes to the public Banto tree", "run the public export gates", "export the public tree". Also invocable via /banto-port. NEVER fires on "release" / "ship" — those are the ws ship intent (a different, human-gated operation); banto-port is the public-export PORT procedure, not the publish action.
  Do not use when: auditing quality (plugin-audit / harness-audit), editing a single file (direct Edit), publishing to GitHub (the owner's manual gate, out of scope), or merging to main / releasing (ws ship).
user-invocable: true
argument-hint: "[export-target-dir (defaults to /tmp/banto-public-export)]"
allowed-tools: Read Write Edit Glob Grep Bash
compatibility: Claude Code (requires bash, git, jq; docker optional for clean-room)
---

# Banto Port — Private → Public Porting Procedure

**WORKFLOW SKILL**

If the user converses in Japanese, respond in Japanese.

Run the steps **in order**. Each step states the command and the PASS condition. If a step FAILs, **stop, fix, and re-run that step** — never skip forward past a failing gate. Report adopted interpretations at the end (spec-fidelity).

Repo root: the checkout containing `plugins/banto/` and `scripts/export-public.sh`. All commands below run from the repo root.

## Step 0: Preflight

```bash
git status --porcelain        # PASS: empty (commit or stash everything first)
git branch --show-current     # record the branch in the final report
```

If the working tree is dirty: stop and ask the user whether to commit first. Porting from a dirty tree makes the export irreproducible.

## Step 1: Allowlist review (default-deny)

Open `scripts/export-public.sh` and read the `ALLOW` list and `PLUGIN_EXCLUDE`.

- Anything **not** listed is **not** exported (NDA-safe default). New top-level files stay private until consciously added.
- Check: `git log --name-only --since="2 weeks ago" -- . ':!plugins'` — if a new top-level file/dir appears that should ship publicly, propose adding it to `ALLOW` as text and apply; otherwise leave it private (no action).
- Never add to `ALLOW`: `catalog.tsv` / root `skills/` (standalone) / `CHANGELOG.md` (internal history) / `.claude/` / audit artifacts.

## Step 2: Porting conventions (apply to any content being ported)

1. **Naming**: no legacy brand names.
2. **i18n**: EN canonical for descriptions and user-facing messages; Japanese trigger phrases in skill descriptions are preserved **verbatim** (they are routing contracts). Tokens consumed by hooks/scripts keep their bytes (look for `i18n: consumed-by` notes).
3. **Hygiene (Axis 14)**: no internal names / client names / personal absolute paths (`/Users/<real-name>`), no pasted run output (terminal result lines, timestamps, tool tmp paths), no internal decision-file pointers in public docs. Use placeholders (`/Users/you/...`, "Person A", "Company X").
4. **Shell**: POSIX sh only (`#!/bin/sh`, no bash arrays, no `&>`). GNU-first command fallbacks (e.g. `stat -c %Y ... || stat -f %m ...`) — CI runs on dash/GNU.

## Step 3: Gate suite (all must PASS before export)

```bash
sh scripts/check-legacy-names.sh --code   # PASS: "OK: no legacy brand names found (scope: --code)"
sh scripts/check-legacy-names.sh          # PASS: "OK: ... (scope: full)"
for f in $(git ls-files '*.sh'); do sh -n "$f" || echo "SH FAIL: $f"; done   # PASS: no FAIL lines
for f in $(git ls-files '*.json'); do jq empty "$f" || echo "JSON FAIL: $f"; done  # PASS: no FAIL lines
sh plugins/banto/scripts/test-ai-context-paths-wiring.sh   # PASS: "ALL GREEN"
sh plugins/banto/scripts/test-resolve-store-path.sh        # PASS: "ALL GREEN"
```

## Step 4: Export (allowlist copy + internal gates re-run)

```bash
TARGET="${1:-/tmp/banto-public-export}"   # $ARGUMENTS first token; target must not exist
rm -rf "$TARGET"
sh scripts/export-public.sh "$TARGET"
```

PASS: ends with `Export ready: ... (N files staged, NOT committed)` and both gates inside the export print OK. Record N (baseline: 194; investigate any large unexplained jump or drop).

## Step 5: NDA sweep on the export (registry + manual patterns)

```bash
cd "$TARGET"
grep -rnE '[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' . --exclude-dir=.git | grep -vE 'noreply@anthropic|example\.com'
grep -rnE '/Users/[a-z]+|/home/[a-z]+' . --exclude-dir=.git | grep -vE '/Users/(you|me|<)|/home/(you|me|<)'
```

PASS: both commands print **nothing**. If `~/.claude/banto-name-registry` exists, additionally grep the export for each registry entry (PASS: 0 hits). If the registry is absent, note in the report that the registry check was a no-op.

## Step 6: Clean-room (if docker is available; otherwise note as skipped)

```bash
docker run --rm -v "$TARGET":/src:ro -v "$PWD/scripts/clean-room-test.sh":/t.sh:ro ubuntu:24.04 sh /t.sh
```

PASS: last line `CLEAN-ROOM: ALL PASS` (9 categories: syntax on dash / jq / py / yaml / brand gates / unit tests / audit pipeline / hook synthetic payloads / state migration).

## Step 7: Report (and stop — publishing is the human gate)

Report as text: branch / file count / gate results / NDA sweep result / clean-room result / adopted interpretations. Then **stop**:

- Never `git commit` inside the export target, never `git push`, never create or modify a GitHub repo. The export dir is staged-only by design; review → commit → publish is the owner's manual decision.

## Prohibited

- Skipping a failing gate or reordering steps past a FAIL
- Adding private skills / internal artifacts to the allowlist
- Pushing or publishing the export (human gate)
- Weakening the brand gate (removing exclusions)
