# Quality scoring criteria for skill / agent / rule

The canonical source for quality scoring is `skills/plugin-audit/references/scoring.md` (15 axes). plugin-dev references it at scaffold time. The 15-axis scoring, the description char caps (1,024 / 1,536 chars), and the token budget (warn 500 / hard 1,000) live there as the single source of truth and are not duplicated in this file.

What this file owns is the **authoring aids** that are plugin-dev's own job: the bilingual detection-vocabulary table and the description templates (Japanese / English).

## Bilingual mapping of detection vocabulary

The mapping for the 4 blocks written in the skill description / body:

| Element | Japanese keyword | English keyword|
|------|-----------------|--------------------------|
| **Trigger** | `トリガー：`, `使うべき場面：` | `USE FOR:`, `Use when:`, `USE PROACTIVELY` |
| **Exclusion condition** | `使ってはいけない場面：`, `〜なら別`, `〜だけなら〜で十分` | `DO NOT USE FOR:`, `DO NOT USE` |
| **INVOKES** | `依存：`, `呼び出す：`, `〜に誘導` | `INVOKES:` |
| **Single-operation distinction** | `単純な〜なら〜で十分`, `軽微なら直接 Edit` | `FOR SINGLE OPERATIONS:` |

The English keywords are the standard adopted by microsoft/skills. The Japanese keywords are banto-specific.
Pick one and use it consistently to match your project.

## Recommended description template (Japanese version)

```yaml
description: |
  **WORKFLOW SKILL** — {何をするか、三人称、簡潔に}。
  トリガー：「{典型ユーザー発話 A}」「{B}」「{C}」
  使ってはいけない場面：{除外条件 / 別 skill との切り分け}
  依存：{INVOKES} search skill、Bash、research-agent
  単純な {小規模ケース} なら {代替手段} で十分。
```

## Recommended description template (English version / Open Standard compatible)

```yaml
description: |
  **WORKFLOW SKILL** — {What this skill does, 3rd person}.
  USE FOR: {trigger phrases A}, {B}, {C}.
  DO NOT USE FOR: {exclusion / other skill boundary}.
  INVOKES: {dependencies, e.g. Read, Grep, Agent(researcher)}.
  FOR SINGLE OPERATIONS: {fallback for trivial cases}.
```

Around 100–500 chars of conciseness is recommended (improves auto-fire decision accuracy). For the exact char-cap values, see "description char count" in `references/skill-md.md`.

## skill classification prefix

The canonical source is "skill classification prefix" in `references/skill-md.md`. Write `**WORKFLOW SKILL**` / `**UTILITY SKILL**` / `**ANALYSIS SKILL**` at the top of the description / body.

## Related

- HeavySkill 4-component → `references/heavyskill-template.md`
- skill design patterns → `references/skill-design-patterns.md`
- existing SKILL.md template → `references/skill-md.md`
