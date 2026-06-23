# Scope: {{PROJECT_NAME}}

**Date**: {{DATE}}
**Author**: {{AUTHOR}}
**Approvers**: {{APPROVERS}}
**Status**: Draft / Agreed / Locked

Agreement document on the project's boundary lines. Prevents rework.

## 1. Objectives

{{What the project must achieve, 3-5 items}}

- {{Objective 1 (per SMART principles)}}
- {{Objective 2}}
- {{Objective 3}}

## 2. In Scope

Items that will definitely be done:

### Features
- {{Feature A}}
- {{Feature B}}

### Technical areas
- {{Area X}}
- {{Area Y}}

### Target platforms / environments
- {{Platform 1}}
- {{Environment 2}}

## 3. Out of Scope

Items **explicitly not handled this time**. Prevents the "actually, please do it after all" accident later:

### Features
- 🚫 {{Feature 1 not done this time (reason: ...)}}
- 🚫 {{...}}

### Technical areas
- 🚫 {{...}}

### Not covered
- 🚫 {{No legacy browser support}}
- 🚫 {{...}}

## 4. Done When

Concrete criteria for calling this project "done":

- [ ] {{Criterion 1 (measurable)}}
- [ ] {{Criterion 2 (measurable)}}
- [ ] {{Criterion 3}}

When all completion criteria are met, change this Scope Doc to `Archived` status.

## 5. Constraints

### Time
- {{Milestones, deadlines}}

### Budget / resources
- {{Staffing, cost cap}}

### Technical
- {{Technologies to use / technologies that cannot be used}}

### Organizational
- {{Approval process, coordination with external stakeholders}}

## 6. Assumptions

Preconditions this scope rests on:

- {{Assumption 1 (e.g. XXX is complete by YYY)}}
- {{Assumption 2}}

If an assumption breaks, the Scope must be re-agreed.

## 7. Stakeholders

| Role | Name | Responsibility |
|---|---|---|
| Sponsor | {{...}} | Budget approval, direction |
| Product Owner | {{...}} | Requirements, priorities |
| Tech Lead | {{...}} | Technical direction |
| QA Lead | {{...}} | Quality assurance |

## 8. Change Management

Scope changes follow this process:

1. The proposer writes it up at `docs/specs/{{DATE}}_{{TOPIC}}_scope-change-{NNN}.md`
2. Stakeholders review
3. Sponsor approves / rejects
4. If approved, update this Scope Doc: `Agreed` → `Revised` → new `Agreed`

## 9. Related documents

- PRD: `docs/specs/{{DATE}}_{{TOPIC}}_prd.md`
- Design Doc: `docs/specs/{{DATE}}_{{TOPIC}}_design-doc.md`
- Spec Kit: `docs/specs/{{DATE}}_{{TOPIC}}_spec.md`
- ADR: `decisions/ADR-{{NNNN}}_{{...}}_.md`
