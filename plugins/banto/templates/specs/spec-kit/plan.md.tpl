# Plan: {{TOPIC}}

**Date**: {{DATE}}
**Author**: {{AUTHOR}}
**Corresponding spec**: `docs/specs/{{DATE}}_{{TOPIC}}_spec.md`

## Context & Scope

{{3-5 line summary of spec.md + the technical context for this work}}

## Goals / Non-Goals

### Goals
- {{Technical goal 1}}
- {{Technical goal 2}}

### Non-Goals
- {{Not handled this time 1}}
- {{Not handled this time 2}}

## The Actual Design

### Architecture overview

```
{{ASCII diagram or description of the component diagram}}
```

### Component breakdown

| Component | Responsibility | Dependencies |
|---|---|---|
| {{Component A}} | {{what it does}} | {{dependencies}} |
| {{Component B}} | {{what it does}} | {{dependencies}} |

### Data model

```
{{Schema definitions, ER diagram, type definitions, etc.}}
```

### API / interfaces

```
{{API endpoints, function signatures, event definitions, etc.}}
```

### Key flows

1. {{Step 1}}
2. {{Step 2}}
3. {{Step 3}}

## Alternatives Considered

### Option A: {{adopted approach}}

**Pros**: {{...}}
**Cons**: {{...}}
**Reason for adoption**: {{...}}

### Option B: {{rejected}}

**Reason for rejection**: {{...}}

## Technology choices

| Item | Choice | Reason |
|---|---|---|
| Language | {{...}} | {{...}} |
| Framework | {{...}} | {{...}} |
| DB | {{...}} | {{...}} |

Per the `dependencies` rule, pin the newest version that is stable and free of known vulnerabilities right before implementation.

## Dependencies / assumptions

- **Assumptions**: {{preconditions this design rests on}}
- **Dependencies**: {{dependencies on existing components / external services}}

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| {{Risk 1}} | High / Medium / Low | {{...}} |

## Test strategy

- **Unit tests**: {{targets, tools}}
- **Integration tests**: {{targets, tools}}
- **E2E**: {{targets, tools}}
- **Performance tests**: {{if needed}}

## Implementation phases

tasks file: `docs/specs/{{DATE}}_{{TOPIC}}_tasks.md`

## Open questions

- Q1: {{undecided design item}}
- Q2: {{...}}

## Related documents

- spec: `docs/specs/{{DATE}}_{{TOPIC}}_spec.md`
- tasks: `docs/specs/{{DATE}}_{{TOPIC}}_tasks.md`
- Similar past designs: `decisions/...`
