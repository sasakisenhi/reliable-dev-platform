## Reliable Development Analysis Additions

### End-to-End Traceability

For each material requirement, evaluate the available chain:

Requirement
→ significant Plan Decision, when one exists
→ implementation Task
→ Verification
→ Evidence

Flag:

- significant mechanisms with no identifiable requirement or constraint justification;
- requirements with implementation work but no meaningful verification;
- verification claims with no identifiable evidence;
- evidence that cannot be attributed to the acceptance condition it is claimed to support.

Do not require an artificial plan decision where none is necessary.

### Artifact Contract Consistency

Check consistency where applicable across specification, plan, data model, contracts,
quickstart validation, and tasks.

Flag incompatible optional/required semantics, incompatible field constraints,
contradictory examples, or conflicting responsibility boundaries.

### Assumption Integrity

Flag cases where an explicitly unverified assumption has silently become a downstream fact
or mechanism dependency without validation or acknowledgement.

### Upstream Correction

When a downstream inconsistency originates in an upstream artifact, identify the canonical
upstream owner that requires correction rather than recommending a downstream-only patch.

### Semantic Staleness

When there is evidence that an upstream semantic decision changed after downstream
artifacts were produced, treat affected downstream artifacts as requiring revalidation.

Syntactic validity alone does not establish that a downstream artifact is still correct.
