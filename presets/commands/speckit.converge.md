## Reliable Development Convergence Rules

### Do Not Patch Around Upstream Errors

When remaining work exists because the specification or plan is wrong, incomplete, or internally inconsistent, do not manufacture downstream tasks solely to make the current artifacts appear complete.

Identify the canonical upstream artifact that owns the decision and report that it requires revision.

### Preserve Requirement Authority

Do not weaken or silently reinterpret requirements during convergence merely because the current implementation does not satisfy them.

Distinguish:

- genuinely missing implementation work;
- invalid or stale downstream artifacts;
- an upstream requirement or design decision requiring revision;
- inconclusive verification caused by insufficient evidence.

### Evidence Closure

A requirement is not converged merely because code exists.

Where acceptance requires observable evidence, convergence requires either:

- the required evidence;
- an explicit unresolved verification task;
- or an explicit inconclusive state explaining why evidence cannot currently be obtained.

### Scope Discipline

Do not turn convergence into an opportunity to introduce unrelated architecture or generic infrastructure.

New work discovered outside the current feature boundary should be identified separately.
