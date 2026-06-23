# Tasks: {{TOPIC}}

**Date**: {{DATE}}
**Corresponding spec**: `docs/specs/{{DATE}}_{{TOPIC}}_spec.md`
**Corresponding plan**: `docs/specs/{{DATE}}_{{TOPIC}}_plan.md`

Break down in TDD structure (Red → Green → Refactor) and state dependencies explicitly.

## Phase 1: {{Phase name}} [0/N]

- [ ] T1.1: {{add tests}} | deps: none
- [ ] T1.2: {{implement to green}} | deps: T1.1
- [ ] T1.3: {{refactor}} | deps: T1.2

## Phase 2: {{Phase name}} [0/N]

- [ ] T2.1: {{add tests}} | deps: T1.3
- [ ] T2.2: {{implement}} | deps: T2.1
- [ ] T2.3: {{integration tests}} | deps: T2.2

## Phase 3: {{Phase name}} [0/N]

- [ ] T3.1: ...

## Task format

```
- [ ] T{X.Y}: {task name} | deps: {dependency tasks}
```

- `- [ ]` incomplete / `- [x]` complete
- `deps:` lists dependency task IDs (`none` or `T1.3` / `T1.3, T2.1`)
- While in progress, refer to the corresponding Phase in `active.md`

## Commit convention

```
<type>(<scope>): <subject>
```

Examples:
- `feat(auth): T2.2 implement JWT token issuance`
- `test(auth): T1.1 add acceptance tests for OAuth login`

## Task management rules

- On task completion: `- [ ]` → `- [x]`
- On Phase completion: run `/phase-done` (auto-archive)
- Never move to the next Phase with incomplete tasks remaining

## Additions / changes during implementation

- Changes not in spec.md / plan.md: **confirm with the user per the `spec-fidelity` rule before implementing**
- Changes that break acceptance criteria start with updating spec.md
