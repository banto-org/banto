# ADR-{{NUMBER}}: {{TITLE}}

**Date**: {{DATE}}
**Status**: Proposed / Accepted / Deprecated / Superseded by ADR-{{NNNN}}
**Deciders**: {{DECIDERS}}
**Tags**: architecture / security / performance / data / infra / process

Michael Nygard-style ADR. Record briefly **after the decision** (a different role from RFCs / Design Docs, which precede design).

## Context

{{The background, forces, and constraints that made this decision necessary, in 2-4 paragraphs. Preserve what the deciders knew and assumed}}

## Decision

{{Write the adopted policy in active voice: "We adopt X", "We prohibit Y", etc. 2-3 paragraphs}}

## Consequences

### Positive
- {{...}}

### Negative / trade-offs
- {{...}}

### Neutral
- {{...}}

### Implications for the future
- {{...}}

## Alternatives considered (optional)

- **Option A** (adopted): {{...}}
- **Option B** (rejected): {{reason for rejection}}
- **Option C** (rejected): {{reason for rejection}}

## Related

- Related ADRs: {{ADR-NNNN}}
- Related RFCs: `docs/specs/{{...}}_rfc.md`
- Related implementation: {{commit hash / PR URL}}

## Naming convention

- Filename: `decisions/ADR-{{NNNN}}_{{topic-slug}}_{{github-user}}.md`
- `NNNN` is a zero-padded 4-digit sequence number (e.g. `ADR-0042`)
- Find the latest number from existing ADRs in the `decisions/` directory
- The existing `YYYY-MM-DD_{topic}_{user}.md` format remains as the "design decision log"; ADRs are reserved for **major structural decisions** only
