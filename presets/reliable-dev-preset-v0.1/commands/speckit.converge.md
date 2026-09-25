## Reliable Development Convergence Additions

### Upstream Integrity

Do not convert a finding into an implementation task when its cause is invalid or stale
upstream intent.

Identify the canonical upstream owner that requires revision and require affected downstream
artifacts to be revalidated before convergence continues.

### Evidence Closure

Do not treat a requirement as converged merely because the corresponding code exists.

When acceptance depends on defined verification evidence, convergence requires that evidence
to exist or an explicit unresolved verification task to remain.

Do not report convergence when required evidence is unavailable or inconclusive.
