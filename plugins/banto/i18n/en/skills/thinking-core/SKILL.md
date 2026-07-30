---
name: thinking-core
description: |
  A thinking-procedure skill that loads the 7-section working contract (acceptance criteria → evidence → minimal change → boundary → verification → report → exceptions) only when needed. The on-demand version of the former always-on thinking-core rule.
  Triggers: attaching it to prompts when fanning out or running the main session on sonnet / haiku, temporarily using an older-generation model (Opus 4.8-class or earlier), "load the work contract", "apply thinking-core". Also invocable via /thinking-core.
  Do not use when: 5-generation Fable / Opus is the main model (strictly never use) — a prescriptive procedure constrains a frontier model's performance, so leave it to plain judgment without loading this skill.
user-invocable: true
allowed-tools: Read
compatibility: Claude Code
---

# Thinking Core — Working Contract (on demand)

The working contract for delivering quality through procedure, not by relying on model intelligence. **Load it only for sonnet / haiku and older-generation models (Opus 4.8-class or earlier). Never use it for 5-generation Fable / Opus (strictly never use)** — a boundary based on measured findings that a prescriptive procedure constrains a frontier model's performance.

## Usage

- **Fan-out attachment**: when the main AI launches a sonnet / haiku subagent, append the 7 sections below (or only the sections needed) to the end of the agent prompt. Do not attach it to 5-generation Fable / Opus agents
- **Main session on a weaker model**: in a session running sonnet / haiku or an older-generation model as the main model, manually load this skill (/thinking-core) and apply it as the working contract

Where a deterministic hook backs an item, it is marked "Enforced:" — breaking it still gets stopped by the hook, but following it is faster.

## 1. Before starting — state the acceptance criteria in one line

Before starting work, be able to state "target / check command / pass signal" in one line.
Example: "ja-lint.sh sentence-ending check / run test-ja-lint.sh / all 17 asserts green".
If you can't state it, you're not ready to start yet — decompose or investigate first.

Confirm with the human only on goal forks (choices that change the acceptance criteria, the order
of magnitude of the impact surface, or the security meaning); for everything else (naming,
placement, library choice, wording) proceed with an adopted interpretation and disclose it in the
final report.
Enforced: spec-fidelity rule / autonomy_level in odd.yaml.

## 2. Evidence — the real thing over memory

The order to rely on is: store (decisions / docs) → the repo's actual files → the web.
The moment you think "I believe the API worked like this" or "we must have decided this before" is
the moment to verify. If you write without verifying, prefix the sentence with "Unverified:". Don't
blur an assertion with "probably" or "maybe".
Enforced: webfetch-deny.sh (read the body text, not a summary) / websearch-gate.sh (store comes
first).

## 3. Design — the minimal correct change

Choose the minimal diff that satisfies the requirement. Before adding a new abstraction, file, or
dependency, look for an existing pattern and follow it.
When in doubt, take the reversible path (copy-then-migrate > destructive move, warn > block,
append > overwrite).
Don't add features, refactors, or improvements that weren't requested.

## 4. Implementation — fix the boundary before writing

List the files you're allowed to touch first, and treat everything outside that boundary as
read-only.
Match the surrounding code's conventions (naming, comment density, error handling); don't bring in
your own habits.
Don't write provenance metadata into deliverables (e.g. "(latest)", "newly added", "previously
was~") — git log and decisions own provenance. Comments are only for "constraints the code itself
can't show".
Enforced: lint-guard.sh (generated files / lockfiles) / ja-lint.sh (Japanese writing style /
metadata).

## 5. Verification — see fully successful output before you say so

Actually run the check command and see fully successful output before saying "done", "it works",
or "fixed". Don't report partial success, an unexecuted check, or a type-check-only pass as
"done". If it failed, report it as failed.
Enforced: verify-claim-guard.sh / auto-test.sh / model-claim-guard.sh.

## 6. Reporting — conclusion first, exact numbers

State the conclusion in the first sentence. Disclose the adopted interpretation, alternatives
considered, and verification performed.
Don't round numbers (don't write "about 30" for "32 items").

## 7. Exceptions — only 4 places to stop

Irreversible (deletion, history rewrite) · external-facing (push / PR / publish / post) ·
contractual (PII / NDA / paid) · goal fork.
Escalate only these 4 kinds to the owner / a checkpoint; for everything else, don't stop — keep
driving autonomously.
Enforced: odd-kill-switch.sh / release-guard.sh / egress-guard.sh / compute-cost-gate.sh.
