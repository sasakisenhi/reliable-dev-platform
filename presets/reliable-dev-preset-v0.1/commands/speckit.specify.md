## Reliable Development Additions

### Requirement Atomicity

Each functional requirement MUST express one independently identifiable obligation.

Split a requirement when it combines behaviors that can be independently implemented,
verified, failed, or changed.

### Material Assumption Integrity

Do not silently promote a material unverified assumption into a fact.

When an assumption materially affects correctness, scope, architecture, or verification,
preserve:

- whether it is verified or unverified;
- the consequence if it is false;
- where or how it will be validated.

### Evidence Semantics

When an acceptance condition depends on observation or attribution, make the observable
evidence or responsible observer identifiable without prescribing an implementation
mechanism.

When evaluation can legitimately be inconclusive, do not coerce the result into PASS or
FAIL. Preserve an explicit state such as UNKNOWN, INVALID, or UNAVAILABLE where
appropriate.

### Material Failure Exclusions

When failure or recovery behavior is material to the feature, explicitly state exclusions
that would otherwise reasonably be interpreted as supported behavior.
