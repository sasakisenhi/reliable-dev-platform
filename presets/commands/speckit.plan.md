## Reliable Development Planning Rules

Apply the following additional rules during technical planning.

### Repository Grounding

Before proposing implementation structure or significant mechanisms:

- inspect the existing repository structure relevant to the feature;
- identify existing modules, abstractions, interfaces, conventions, dependencies, tests, and architectural patterns;
- verify that proposed file paths and integration points correspond to the actual repository where possible.

Prefer extending an established repository pattern over introducing a parallel abstraction.

### Requirement → Mechanism Traceability

Every significant technical mechanism or architectural decision MUST be justified by at least one:

- functional requirement;
- quality attribute;
- explicit constraint;
- verified environmental requirement.

For significant decisions, record the relevant requirement or constraint identifiers using an `Implements:` relationship where identifiers exist.

Do not select a mechanism merely because it is conventional for the technology being used.

### Minimum Necessary Mechanism

Prefer, in order:

1. an existing capability already present in the repository;
2. a standard capability of the platform or framework;
3. a mature existing dependency already justified by the project;
4. a new dependency;
5. custom infrastructure or abstraction.

Moving downward in this list requires an actual requirement or constraint that the simpler option cannot satisfy.

Do not introduce custom infrastructure for hypothetical future needs.

### State Semantics

Do not conflate:

- normative or desired state;
- raw or observed current state;
- interpretation or derived state;
- the action taken to reconcile or respond to the difference.

Use terminology appropriate to the domain, but preserve these semantic boundaries where they exist.

### Significant Decisions Only

Record decision rationale only when the choice materially affects one or more of:

- architecture;
- quality attributes;
- external interfaces;
- dependencies;
- operational behavior;
- future constraints;
- reversibility or migration cost.

Do not turn local implementation details into architecture decisions.

### Environment and Runtime Assumptions

Make explicit external assumptions that materially affect reproducibility or correctness, including where relevant:

- runtime versions;
- platform versions;
- schema or protocol versions;
- dependency versions;
- infrastructure capabilities;
- external service guarantees.

### Failure Responsibility Boundaries

For recovery-, retry-, reconciliation-, fallback-, or degraded-mode behavior:

- identify which component detects the failure;
- identify which component is responsible for responding;
- identify which failure modes are intentionally not handled;
- avoid overlapping recovery mechanisms unless their interaction is explicitly designed.

### Human Review Candidates

Flag a decision for human review when it is materially:

- difficult to reverse;
- high blast-radius;
- security/privacy sensitive;
- operationally expensive;
- strongly constraining to downstream design;
- introducing a major new platform, persistence mechanism, controller, or infrastructure dependency.

Do not block routine reversible decisions unnecessarily.
