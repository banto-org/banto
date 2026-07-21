# The 7 audit axes

Each axis lists a judgment procedure (2-4 mechanically traceable steps), a pass criterion, and one representative violation. The mechanical measurements come from `scripts/skill-audit-metrics.sh` (see procedure.md).

## A1: Information minimality

Checks whether SKILL.md and each file under references/ carries information that execution does not need — history, background narrative, or self-evident generalities.

Judgment procedure:
1. Read SKILL.md and every `.md` file under references/, and, paragraph by paragraph, ask whether it feeds a decision or a step.
2. Flag paragraphs that feed neither (backstory, generic preambles).
3. Cross-check `skill-audit-metrics.sh`'s line/byte counts against the actual number of steps to gauge density.

Pass criterion: every paragraph in SKILL.md and the references feeds either a decision or an execution step. No paragraph is there purely for execution-irrelevant context.

Representative violation: a backstory paragraph like "this skill was created by merging a legacy skill" persists in the body.

## A2: Leakage of human-only information

Checks for change history, author notes, TODOs, or process-history annotations (the same pattern group ja-lint.py detects).

Judgment procedure:
1. Check `skill-audit-metrics.sh`'s process-history pattern hits (the Japanese markers meaning "(latest)", "(new)", "newly added", "added this time", "previously was", "changed from", "in the old version").
2. Judge whether each hit line is canonical content or leftover edit residue.
3. Manually scan for TODOs, author notes, or review-comment-style sentences ("might be better to...") (covers SKILL.md and every file under references/).

Pass criterion: the body has no change history, author notes, TODOs, or process-history annotations.

Representative violation: a dated annotation like "(added 2026-07)" persists in the body.

## A3: Division of labor in structure

Checks whether SKILL.md sticks to being a router (when to use it / which references to read), and whether the same information is duplicated across SKILL.md and references, or between references.

Judgment procedure:
1. Confirm SKILL.md limits itself to guiding "when to use this" and "which references to read."
2. Run `skill-audit-metrics.sh`'s duplicate-paragraph detection (normalized lines of 30+ characters matching across files).
3. When a duplicate hits, decide which of SKILL.md or the reference is canonical, and shrink the other to a summary plus a link.

Pass criterion: no duplicated information between SKILL.md and references, or among references. SKILL.md does not carry a full procedure that belongs in a reference.

Representative violation: the same execution procedure is written out in full in both the SKILL.md body and `references/procedure.md`.

## A4: Appropriateness of the execution-model directive

Checks the odd.yaml declaration (only when ODD is adopted — ODD is an optional banto-originated mechanism), and — for skills that launch an Agent — whether a model directive is present and consistent with `templates/model-policy.json`.

Judgment procedure:
1. Check whether TARGET has an odd.yaml. If not, Glob the sibling skills (`../*/odd.yaml`): if at least one exists, flag WARN as partial-adoption drift; if none exist, treat ODD as not adopted and mark the odd items N/A (judge with steps 3+ only; presence itself is never a violation).
2. If odd.yaml exists, check its `autonomy_level` declaration (must fall within L0-L3).
3. Check whether the skill launches an Agent (whether `allowed-tools` includes Agent).
4. If it does, check `skill-audit-metrics.sh`'s model-directive extraction (`model:` / `model=` lines).
5. Cross-check the role against model-policy.json (roles: design=inherit / implement=sonnet / mechanical=haiku / audit=opus).

Pass criterion: every Agent launch carries a model directive matching its role (judgment work uses opus, implementation work uses sonnet, mechanical search uses haiku). When ODD is adopted, odd.yaml's `autonomy_level` is L0-L3 (when not adopted, the odd items are N/A).

Representative violation: a judgment-role Agent launch has no model directive and is left to the default model.

## A5: Context efficiency

Checks the quality of the frontmatter description, information density relative to body token count, and whether references form a progressive-disclosure structure.

Judgment procedure:
1. Confirm the description contains trigger phrases and stays roughly within 1,024 characters.
2. Use `skill-audit-metrics.sh`'s body byte/line counts to gauge density (is the body too long for the amount of information it conveys?).
3. Confirm references are explicitly linked from SKILL.md and are read only when needed.

Pass criterion: the description contains trigger phrases and stays within the character cap. The body does not carry volume that belongs in a reference.

Representative violation: the description is so abstract it has no trigger phrases, leaving it unclear what utterance activates the skill.

## A6: Stated-AI disclosure and consistency

Checks the stated target host/model. Absent any statement, assume Claude (Claude Code) and pass if the body is consistent with that. A skill that states "general-purpose" fails if Claude-specific wording remains.

Judgment procedure:
1. Check whether the skill body (SKILL.md + references/) states a target host/model ("general-purpose", "ChatGPT", "another AI," etc.).
2. If no statement is present, assume Claude (Claude Code).
3. For skills stating "general-purpose," check `skill-audit-metrics.sh`'s Claude-specific token counts (Task / Skill / CLAUDE_PLUGIN_ROOT / hook, etc.).
4. Judge whether the statement is consistent with the body's actual content (delegate the subjective call to an Agent).

Pass criterion: a skill with no statement passes if it is consistent with Claude-specific wording (tool names Task/Skill, `${CLAUDE_PLUGIN_ROOT}`, hook assumptions). A skill stating "general-purpose" fails if Claude-specific tokens remain.

Representative violation: a skill states "general-purpose, works with any AI" while its body still references `${CLAUDE_PLUGIN_ROOT}` or assumes hooks.

## A7: Division of labor with determinism

Checks whether the safety/quality discipline the skill's prose promises is clearly split between what a hook should enforce (or already enforces) and what remains a prose-level convention.

Judgment procedure:
1. Enumerate the safety/quality discipline the skill's prose (SKILL.md + references/; also scripts/ docstrings, if present) promises (enforcement wording such as "must" / "never").
2. Cross-check whether that discipline is already enforced by an existing hook (e.g. egress-guard.sh / lint-guard.sh / odd-kill-switch.sh).
3. Flag any enforcement wording not covered by a hook as a hook-enforcement candidate.

Pass criterion: among the safety rules the skill states as "must," any that a hook can enforce are explicitly named alongside that hook. Enforcement and mere suggestion are not conflated.

Representative violation: the skill body states "never print a secret" with no mention of the corresponding hook (e.g. egress-guard.sh).
