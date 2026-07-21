# Spec Fidelity — Conformance to the Spec

## Stop triggers (only these)
- A goal fork exists → confirm in advance
- Conflict with existing `decisions/` → re-confirm the prior decision
- Anything else → proceed with an adopted interpretation

## Examples of goal forks (stop)
- Choosing A/B changes the acceptance criteria
- Choosing A/B changes the order of magnitude of the impact surface
- The security / compliance meaning changes
- Depends on user-specific business knowledge (internal rules, contracts, regulations)

## Examples that are NOT goal forks (proceed)
- Naming, file placement, library choice
- Log/error wording, presence of comments
- Formatting, test details

## Disclosing adopted interpretations
- Medium scale or larger → disclose "adopted interpretation / alternatives / verification performed" in the final report
- Single-file fix → not needed (the PR description suffices)
- Provisional decisions that may be rolled back → record as a provisional-status decision in `{base}/decisions/` (front-matter status: provisional)

## Scope of permitted adopted interpretations (tied to autonomy_level)


The `autonomy_level` declared in each skill's `odd.yaml` determines the permitted range:

| autonomy_level | Treatment of adopted interpretations |
|---|---|
| **L0** (information display) / **L1** (light utility) / **L2** (medium workflow) | May proceed with adopted interpretations (disclose in the final report) |
| **L3** (heavy workflow) | May proceed, but for medium scale or larger, the final report MUST disclose "adopted interpretation / alternatives / verification" |
| **L4+** (autonomous / supervised-auto) | **Advance confirmation required, adopted interpretations not allowed** |
| **Skills without ODD** | Treated as provisional L0 (apply a formal ODD when tidying up) |

## Forbidden
- Asserting while hiding uncertainty behind "probably" / "maybe" (the "Unverified:" prefix is mandatory — either "Unverified:" or 「未確認:」 is acceptable)
- Proceeding through a goal fork with an adopted interpretation
- Adding features that are not in the spec
