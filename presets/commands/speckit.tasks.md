## Reliable Development Task Rules

Apply these rules in addition to the core task-generation rules.

### Task Atomicity

Each task MUST represent one coherent implementation outcome.

Split a task when it contains changes that are independently:

- implementable;
- verifiable;
- failure-prone;
- reviewable;
- reversible.

Do not combine unrelated reasons-to-change into one task.

Avoid task descriptions whose implementation would require the agent to invent substantial unstated internal subtasks.

### No Repeated Design Rationale

Tasks contain executable work.

Reference requirements, plan decisions, contracts, or models where useful, but do not duplicate lengthy design rationale already owned by another artifact.

### Verification-Oriented Completion

For non-trivial implementation work, make the completion condition observable.

A task SHOULD identify or reference the check, test, state transition, artifact, or other evidence that distinguishes:

- complete;
- partially implemented;
- not working.

Do not require a dedicated test command for trivial tasks when correctness is already self-evident.

### Failure Injection

When a user story or requirement explicitly covers:

- recovery;
- retry;
- fallback;
- degraded mode;
- reconciliation;
- self-healing;

include task coverage that causes or simulates the relevant failure condition and verifies the expected recovery behavior.

Normal-path verification alone is insufficient for such requirements.

### Asynchronous Readiness

For asynchronous behavior, include explicit readiness, wait, or convergence conditions where required for deterministic verification.

Do not rely on arbitrary sleep durations when a state-based completion condition is available.

### Traceability

Where stable identifiers exist, preserve enough references in task descriptions to recover:

Requirement → significant Plan Decision → Task → Verification.

Do not alter the core checklist syntax to add custom tags.
