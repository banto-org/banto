# CONCEPT — Banto's North Star

> This file is the ideology layer that the concept skill prescribes, applied to this repo itself.
> It is injected from CLAUDE.md via `@CONCEPT.md` and acts as the judgment filter for every agent.

## ① WHY (reason to exist)

In an era where AI pushes the cost of building toward zero, the moat moves from execution to
**vision + empathy**. Banto is not a "dev workflow tool" — it is a **harness that holds your
ideology, decisions, and knowledge, feeds them to agents, and self-drives without putting a human
in the loop for routine choices**. It maximizes the leverage of one human commanding N AI sessions.

The name: a **bantō (番頭)** is the head clerk of an Edo-period merchant house. The owner sets the
vision; the bantō runs the shop end to end and brings only the exceptions to the owner. That is
exactly the contract this harness offers.

## ② Anti-goals (what Banto refuses to become)

- A tool that **binds you with approval gates** (enforcement belongs to hooks; approvals stay minimal).
- A **"wall of instructions"** — always-on rules stay lean (path-scoped injection trims constant context).
- **Modal questions** that split the dialogue (text conversation only; AskUserQuestion is not used).
- **Hoarding dead features** (measure invocations + artifacts via telemetry, fold what is unused).
- **Drift between the edit repo and the live plugin** (`harness-drift-check.sh` + `dead-skill-report.sh` watch continuously at SessionStart / nightly; the harness-audit skill is the deep manual audit, held dev-only).
- **A command-driven interface** — natural language is the primary path; commands are deterministic
  aliases. Every command must be reachable by users who don't know it exists (intent-first).

## ③ Tribe (who this resonates with)

Builders — solo or small teams — chasing large leverage. Contract and product developers who run AI
under NDA discipline across client projects. Lean-minded: ride proven tools, don't reinvent wheels.

## ④ Aesthetic signal

- **lean**: delegate to proven mechanisms (git-town, Anthropic official plugins, built-in agent fan-out).
- **deterministic**: enforcement is hooks (kill-switch / egress guard / verify-claim) — never promises.
- **conclusion-first**: assert, and mark uncertainty explicitly ("Unverified:" / 「未確認:」).
- **verify-before-claim**: never say "done" before verifying with fully successful output.

## ⑤ North star (qualitative definition of success)

**"Humans never think about invocation; the harness self-drives; exceptions arrive only as checkpoints."**
The subject of invocation is Claude's self-driving, not human skill calls. The safety valves are
deterministic hooks. The edit repo and the live plugin always match — declarations never drift from reality.
