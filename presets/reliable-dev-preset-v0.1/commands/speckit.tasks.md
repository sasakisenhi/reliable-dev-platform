## Reliable Development Task Additions

### Task Atomicity

Each task MUST represent one coherent implementation outcome.

Split a task when it contains changes that are independently implementable, verifiable,
failure-prone, reviewable, or reversible.

Do not combine unrelated reasons to change into one task, and do not leave substantial
unstated internal subtasks for the implementation agent to invent.

### Verification-Oriented Completion

For non-trivial work, make the completion condition observable.

A task SHOULD identify or reference the test, check, state transition, artifact, or other
evidence that distinguishes complete work from partial or non-working work.

### Failure-Path Verification

When a requirement covers recovery, retry, fallback, degraded mode, reconciliation, or
self-healing, include work that causes or simulates the relevant failure condition and
verifies the required response.

Normal-path verification alone is insufficient for such a requirement.

### Asynchronous Readiness

For asynchronous behavior, use explicit readiness, wait, or convergence conditions when
needed for deterministic verification.

Prefer state-based completion conditions over arbitrary sleep durations.

### Traceability

Where stable identifiers exist, preserve enough references in task descriptions to recover:

Requirement → significant Plan Decision, when one exists → Task → Verification.

Do not change the core task checklist syntax merely to add custom tags.
