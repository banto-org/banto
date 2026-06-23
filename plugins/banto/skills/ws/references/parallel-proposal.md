# Proactive parallelism proposal — fan-out Agents vs worktree

Even when the user does not say "in parallel," if the work **decomposes into independent subtasks with no sequential dependency**, proactively propose parallelizing it instead of running serially (an extension of intent-first — don't make the owner memorize commands).

## Criteria

| Condition | Means | Why |
|---|---|---|
| Read / investigation / analysis, or independent edits that **touch no shared file**, just aggregated at the end and short-lived | **fan-out Agents** (multiple Agent calls in one message) | No worktree needed. Leanest (CONCEPT's "built-in agent fan-out") |
| Parallel **branches with independent commits**, long-running, conflicting file/build writes, physical isolation required | **task worktree** (`ws task` / `claude -w`) | git-level isolation needed |

## Divisibility test (propose only when all three hold)

1. No sequential dependency between subtasks (B does not wait on A's output)
2. Splitting actually shrinks wall-clock time
3. Integration cost (merge / aggregation) does not exceed the split's gain

When in doubt, don't propose (over-proposing on trivial or tightly-coupled work is bureaucratizing — the same anti-goal as misfiring epics). The proposal is L2 (proceed with an adopted interpretation); fan-out can run immediately, while a worktree creates structure so insert a light confirmation.
