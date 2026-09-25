## Technical Decision Traceability

Document only significant technical decisions.

| Decision | Mechanism | Implements | Why Needed | Alternative Rejected |
|----------|-----------|------------|------------|----------------------|
| PD-001 | [mechanism] | FR-xxx / SC-xxx / constraint | [reason] | [simpler alternative and why insufficient] |

Do not add entries for routine local implementation choices.

## Environment Assumptions

Record only assumptions that materially affect reproducibility or correctness.

| Assumption | Required Value / Capability | Consequence if Violated |
|------------|-----------------------------|-------------------------|
| [runtime/platform assumption] | [value] | [impact] |

## Failure Responsibility Boundaries

<!-- Include only where recovery/failure handling is material. -->

| Failure Mode | Detector | Responsible Mechanism | Expected Outcome | Out of Scope |
|--------------|----------|-----------------------|------------------|--------------|
| [failure] | [observer] | [mechanism] | [observable result] | [boundary] |
