# Design Doc: {{TOPIC}}

**Date**: {{DATE}}
**Author**: {{AUTHOR}}
**Reviewers**: {{REVIEWERS}}
**Status**: Draft / In Review / Approved / Implemented
**Related PRD**: `docs/specs/{{DATE}}_{{TOPIC}}_prd.md`

Google-style Design Doc. Details the system design for engineers.

## 1. Context & Scope

### Context
{{Why this design became necessary, historical background, relationship to existing systems}}

### Scope (what this design covers)
{{What is designed, what is not designed}}

## 2. Goals & Non-Goals

### Goals
- {{Technical goal 1 (measurable)}}
- {{...}}

### Non-Goals
- {{Explicitly out-of-scope item 1}}
- {{...}}

## 3. The Actual Design

### 3.1 Overview diagram

```
{{System diagram (ASCII or Mermaid or a description of the diagram)}}
```

### 3.2 Components

#### Component A: {{name}}
- **Responsibility**: {{...}}
- **Interface**: {{API / function signatures}}
- **Dependencies**: {{...}}

#### Component B: {{name}}
...

### 3.3 Data model

```
{{Schema definitions, ER diagram, type definitions, etc.}}
```

### 3.4 Key flows

#### Flow 1: {{name}}

```
Client → API → Service → DB
```

1. Client {{...}}
2. API {{...}}
3. Service {{...}}

### 3.5 Error handling

- {{Error situation 1}} → {{handling}}
- {{Error situation 2}} → {{handling}}

### 3.6 Security

- Authentication: {{...}}
- Authorization: {{...}}
- Input validation: {{...}}
- Secret management: {{...}}

## 4. Alternatives Considered

### Alternative A: {{...}}
**Pros**: {{...}}
**Cons**: {{...}}
**Reason for rejection**: {{...}}

### Alternative B: {{...}}
...

## 5. Cross-Cutting Concerns

### Performance
- Targets: {{P95 / throughput}}
- Expected bottlenecks: {{...}}

### Observability
- Logs: {{levels, destinations}}
- Metrics: {{what to measure}}
- Traces: {{span structure}}

### Test strategy
- Unit: {{...}}
- Integration: {{...}}
- E2E: {{...}}

### Deployment / migration
- Deployment strategy: {{blue-green / canary / in-place}}
- Migration plan: {{handling of existing data / existing clients}}
- Rollback: {{...}}

## 6. Timeline

| Phase | Duration | Deliverables |
|---|---|---|
| Design review | {{...}} | This Design Doc |
| Implementation Phase 1 | {{...}} | {{...}} |
| Testing | {{...}} | {{...}} |
| Release | {{...}} | {{...}} |

## 7. Open Questions

- Q1: {{undecided item}}
- Q2: {{...}}

## 8. Appendix

### References
- {{link}}

### Abbreviations
- {{abbreviation → full name}}
