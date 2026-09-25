## Reliable Development Implementation Additions

### Upstream Correction

Do not reinterpret or weaken an approved requirement, assumption, feature boundary, or
significant plan decision merely to make implementation or tests pass.

If implementation reveals that upstream intent is invalid, contradictory, or stale:

1. identify the canonical upstream owner;
2. report the contradiction;
3. require correction of that upstream artifact;
4. revalidate affected downstream artifacts before treating the issue as resolved.

### Evidence-Based Completion

Do not mark non-trivial work complete merely because code was written.

When the task, acceptance criterion, quickstart scenario, contract, or plan defines
verification evidence, obtain that evidence before claiming completion.

If the required observation is unavailable or legitimately inconclusive, report that state
instead of claiming PASS.
