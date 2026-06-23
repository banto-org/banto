# PII / Internal Names Protection Rule

Code of conduct for cross-project confidentiality (NDA / contracts). Sibling of secret protection (`safety.md`).
Deterministic enforcement is handled by `egress-guard.sh` (PreToolUse Write/Edit).

## Principles

- **Never write internal member names, other project names, other companies' identifying information, or PII into client deliverables (client repos / handover artifacts).** Mask with generic nouns when needed (e.g. "Person A" / "Company X"; in Japanese: 「担当者A」「〇〇社」「関係者」).
- **Never carry context across projects.** Don't mix Client A's decisions, documents, or stakeholder names into Client B's sessions or deliverables.
- It is fine for internal names to exist in ai-context (`.ai-context/` / the central store). The problem is **egress to the client**. Treat the two separately.

## Examples of what to mask

| Kind | Example | Treatment in client deliverables |
|---|---|---|
| Internal member names | A colleague's full name | Mask ("Person A", etc.) |
| Other project / company names | Another client's company name or codename | Don't write it |
| PII | Email / phone / address / personal IDs | Mask or remove |
| Own sensitive info | Internal contract terms, rates | Don't write it for clients |

## Mechanism (enforcement)

- **Name registry**: `~/.claude/banto-name-registry` (user-scope, 1 name per line / `re:` regex). **Never commit it to a repo / store** (would leak the name list itself).
- **egress-guard** (`egress-guard.sh`, PreToolUse Write/Edit) **blocks** a write to a client path that hits a registry name; escape only when legitimate with `BANTO_ALLOW_NAMES=1`. Absent registry / no python3 → no-op; exempt paths + tuning (`BANTO_EGRESS_SAFE_PATHS`) live in the script.

## Forbidden

- Writing internal names / other project names / PII into client deliverables **without masking**
- Permanently disabling the guard with `BANTO_ALLOW_NAMES=1` without a reason
- Committing the name registry to a repo / the central store
