# PRD: {{PRODUCT_NAME}}

**Date**: {{DATE}}
**Owner**: {{OWNER}}
**Status**: Draft / In Review / Approved / Shipped / Deprecated
**Related Issue / Epic**: {{...}}

## 1. Overview

{{Describe the product / feature in one paragraph}}

## 2. Problem Statement

### Who is struggling
{{Target users and their current pain}}

### Why solve it now
{{Rationale for the timing (market / regulation / technology trends, etc.)}}

## 3. Goals

### Business goals
- {{Goal 1: measurable KPI}}
- {{Goal 2}}

### User goals
- {{What users want to achieve 1}}
- {{What users want to achieve 2}}

## 4. Non-Goals

- {{Out of scope 1}}
- {{Out of scope 2}}

## 5. User Personas

| Persona | Traits | Primary use case |
|---|---|---|
| {{Persona A}} | {{age/role/technical level}} | {{...}} |
| {{Persona B}} | ... | ... |

## 6. Requirements

### Functional Requirements

| # | Requirement | Priority | Acceptance criteria |
|---|---|---|---|
| FR-1 | {{requirement}} | Must / Should / Could | {{...}} |
| FR-2 | ... | ... | ... |

### Non-Functional Requirements

| # | Requirement | Target |
|---|---|---|
| NFR-1 | Response time | P95 < 200ms |
| NFR-2 | Concurrent connections | 10,000 |
| NFR-3 | Availability | 99.9% |
| NFR-4 | WCAG | AA compliant |

## 7. Success Metrics

- **North Star**: {{primary metric}}
- **Leading indicators**: {{...}}
- **Guardrail metrics**: {{things that must not get worse}}

## 8. Risks & Assumptions

### Assumptions
- {{Assumption 1}}
- {{Assumption 2}}

### Risks
| Risk | Impact | Mitigation |
|---|---|---|
| {{...}} | H/M/L | {{...}} |

## 9. Timeline & Milestones

| Milestone | Date | Deliverables |
|---|---|---|
| Alpha | {{...}} | {{...}} |
| Beta | {{...}} | {{...}} |
| GA | {{...}} | {{...}} |

## 10. Open Questions

- Q1: {{...}}
- Q2: {{...}}

## 11. Related documents

- Design Doc: `docs/specs/{{DATE}}_{{TOPIC}}_design-doc.md`
- Spec Kit: `docs/specs/{{DATE}}_{{TOPIC}}_spec.md`
- Past ADRs: `decisions/...`
