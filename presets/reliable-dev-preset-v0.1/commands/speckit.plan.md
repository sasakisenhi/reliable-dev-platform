## Reliable Development Planning Additions

### Repository Grounding

Before selecting significant mechanisms or implementation structure:

- inspect the repository areas relevant to the feature;
- identify existing modules, abstractions, interfaces, conventions, dependencies, tests,
  and architectural patterns;
- verify proposed integration points and file paths against the actual repository where
  possible.

Prefer extending an established repository pattern over introducing a parallel abstraction.

### Significant Decision Traceability

For each significant technical decision, preserve the relationship to the functional
requirement, success criterion, quality condition, or explicit constraint that justifies it.

Use stable identifiers such as `FR-###` or `SC-###` where they exist.

Do not create decision records for routine local implementation choices. Reuse the existing
plan or research structure instead of duplicating rationale in a new section when an
appropriate owner already exists.

### State Semantics

Where the domain distinguishes them, do not conflate:

- normative or desired state;
- raw or observed current state;
- interpreted or derived state;
- the action taken in response to the difference.

Use domain-appropriate terminology while preserving those semantic boundaries.

### Material Environment Assumptions

Make external assumptions explicit when they materially affect reproducibility or
correctness, including relevant runtime, platform, protocol, schema, dependency, or
infrastructure capabilities.

### Failure Responsibility Boundaries

For recovery, retry, reconciliation, fallback, or degraded-mode behavior, identify:

- which component detects the condition;
- which component is responsible for responding;
- materially relevant failure modes that are intentionally not handled.

Avoid overlapping recovery mechanisms unless their interaction is intentionally designed.

### Review-Sensitive Decisions

Explicitly flag significant decisions for the existing plan review gate when they are
materially difficult to reverse, high blast-radius, security/privacy sensitive,
operationally expensive, or strongly constraining to downstream design.
