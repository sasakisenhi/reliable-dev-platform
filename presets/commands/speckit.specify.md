## Reliable Development Rules

Apply the following additional rules when producing or updating the specification.

### Requirement Atomicity

- Each requirement MUST express one independently identifiable obligation.
- Split requirements that combine multiple independently implementable or verifiable behaviors.
- Each requirement SHOULD have a stable identifier when the template supports identifiers.

### Requirement Before Mechanism

- Specify observable behavior, constraints, and outcomes rather than implementation mechanisms.
- Do not introduce a technology, platform feature, library, controller, database, framework, or other mechanism unless it is itself part of an externally imposed constraint.
- Mechanism selection belongs to planning.

### Assumptions

- Do not silently promote an unverified assumption into a requirement or fact.
- Record assumptions explicitly when correctness depends on them.
- For each material assumption, identify:
  - its verification status;
  - the consequence if false;
  - how or where it should be validated.
- If a material assumption has no reasonable default, leave it unresolved for clarification rather than inventing certainty.

### Scope and Failure Scope

For behavior involving failure, recovery, retry, fallback, reconciliation, degradation, or availability:

- define what can fail;
- define what behavior is in scope;
- define materially relevant failure modes that are out of scope;
- distinguish expected behavior from best-effort behavior.

### Timing Semantics

When timing affects correctness, avoid terms such as "quickly", "immediately", or "within a reasonable time".

Specify the observable timing requirement or identify it as an unresolved constraint.

Do not invent implementation-level timeout values when the requirement only defines an externally observable outcome.

### Observable Acceptance

Acceptance criteria MUST be based on externally observable or otherwise attributable evidence.

Do not define acceptance solely as an internal implementation state.

When evaluation can legitimately be inconclusive, preserve an explicit non-success/non-failure state such as UNKNOWN, INVALID, or UNAVAILABLE instead of coercing the result into PASS or FAIL.

### Quality Attributes

Consider quality attributes materially affected by this feature, including where relevant:

- reliability;
- performance;
- security;
- privacy;
- availability;
- maintainability;
- accessibility.

Do not add irrelevant quality requirements merely to complete a checklist.

### Upstream Authority

Do not weaken a requirement merely because an implementation or test is difficult to satisfy.

A requirement change MUST be justified by a change in the problem, hypothesis, externally imposed constraint, or intentionally revised product decision.
