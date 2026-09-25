## Reliable Development Implementation Rules

### Upstream Authority

Implementation MUST conform to the approved requirements and plan.

Do not modify, reinterpret, or weaken an upstream requirement merely to make implementation or tests pass.

If implementation reveals that an upstream requirement, assumption, architecture decision, or feature boundary is invalid:

1. stop treating the downstream artifact as authoritative for that issue;
2. identify the canonical upstream owner;
3. report the contradiction;
4. recommend revising the upstream artifact and revalidating affected downstream artifacts.

### Evidence-Based Completion

Do not mark a non-trivial task complete merely because code was written.

Before completion, obtain the verification or observable evidence required by the task, user story, quickstart scenario, contract, or acceptance criterion when such evidence exists.

Do not claim PASS when the required observation is unavailable or inconclusive.

### Failure Behavior

For requirements involving recovery or degraded behavior, execute the defined failure-path verification when practical and safe.

A successful normal-path test does not establish recovery behavior.

### No Scope Expansion

Do not introduce unrelated reusable frameworks, generalized infrastructure, classification systems, audit systems, databases, abstractions, or other platform work unless required by the active task or an approved upstream decision.

When such work is genuinely reusable but outside the current feature boundary, report it separately instead of silently expanding the feature.
