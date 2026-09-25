## Reliable Development Analysis Rules

In addition to the core consistency analysis, perform the following checks when the relevant artifacts contain sufficient information.

### End-to-End Traceability

For each material requirement, evaluate the chain:

Requirement
→ significant Plan Decision / Mechanism
→ implementation Task
→ Verification
→ Evidence

Do not require an artificial Plan Decision when a requirement needs no significant technical decision.

Flag:

- mechanisms with no requirement or constraint justification;
- requirements with implementation tasks but no meaningful verification;
- verification claims with no identifiable observable evidence;
- evidence that cannot be attributed to the acceptance condition it is claimed to prove.

### Standard-vs-Custom Mechanism Review

Flag custom mechanisms when an existing repository, platform, framework, or established dependency capability appears to provide the same commodity capability and no documented requirement explains the custom implementation.

Report this as a review finding, not as an automatic assertion that the custom mechanism is wrong.

### Failure Verification Coverage

When requirements include recovery, retry, fallback, degraded mode, reconciliation, or self-healing, verify that downstream work includes validation of the failure path rather than only the normal path.

### Artifact Contract Consistency

Check consistency where applicable across:

- specification;
- plan;
- data model;
- contracts;
- quickstart validation;
- tasks.

Flag incompatible optional/required semantics, incompatible field constraints, contradictory examples, or incompatible responsibility boundaries.

### Assumption Integrity

Flag cases where an explicitly unverified assumption has silently become a downstream fact or mechanism dependency without validation or acknowledgement.

### Upstream Problems

When a downstream inconsistency originates in an upstream artifact, recommend correcting the canonical upstream owner rather than patching only downstream artifacts.

### Staleness

When there is evidence that an upstream semantic decision changed after downstream artifacts were generated, treat downstream correctness as requiring revalidation.

Do not assume a downstream artifact remains correct merely because it is syntactically valid.
