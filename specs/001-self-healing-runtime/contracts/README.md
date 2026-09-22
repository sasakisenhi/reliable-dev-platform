# Interface Contracts

## Files

- `application-contract.schema.json`: Developer-owned input. Defines expected instances and the representative application operation.
- `verification-profile.schema.json`: Platform-QA-owned input. Maps the application to a Kubernetes workload and observation settings.
- `trial-result.schema.json`: Immutable verdict, FR-006 observations, and evidence index for one attempt.

Runtime configuration examples live under `config/self-healing/`; generated evidence lives under `artifacts/self-healing/` and is not committed.

## CLI

```text
self-healing bootstrap \
  --admin-context <context> \
  --verification-profile <path>

self-healing validate \
  --application-contract <path> \
  --verification-profile <path>

self-healing run \
  --application-contract <path> \
  --verification-profile <path> \
  [--run-id <uuid>]
```

### `bootstrap`

Runs before the verification window with the admin context. It confirms the pre-applied ServiceAccount/RBAC, requests a short-lived token, and writes the dedicated kubeconfig at `qaKubeconfigPath`. It does not inject loss or alter the workload. Subsequent commands use only that kubeconfig for Kubernetes requests.

### `validate`

Validates both JSON inputs, confirms their responsibility boundary, and verifies that the configured Kubernetes context and Deployment can be read. It does not inject loss.

### `run`

Executes exactly one attempt and always writes `result.json` when a trial verdict can be formed. If `--run-id` is omitted it creates one; after an `INVALID`, the caller can reuse that run ID after the prescribed initial conditions have recovered. Each invocation creates a new attempt ID. The runner records the reason and ends the attempt; it never repairs the environment or retries by itself.

| Verdict | Process exit code | Quality evaluation | Caller action |
|---|---:|---|---|
| `PASS` | 0 | included | stop |
| `FAIL` | 1 | included | stop |
| `INVALID` | 3 | excluded | restore/check initial conditions and invoke a new attempt |

Malformed input, unavailable tooling, evidence write failure, or external cancellation is an operational error rather than a trial verdict and exits 2.

## Mutation boundary

The CLI may issue one graceful delete for the selected Pod in each attempt. All other Kubernetes interactions are read-only. In particular, it must not scale the Deployment, create a replacement Pod, restart a rollout, or otherwise prompt recovery.

The CLI authenticates as the dedicated Platform QA ServiceAccount through `qaKubeconfigPath`. Runtime actor classification uses that exact QA username, the fixed standard control-plane/node identities defined in research.md, and `OTHER`; the `system:` prefix alone is not trusted. A fixed `DEVELOPER_TEST` username exists only in classifier audit fixtures and is not a profile field or cluster identity. Kubernetes audit records mounted at the host-side `auditLogPath` must show exactly the allowed target-Pod delete for the QA actor. An `OTHER` mutation can never be part of a `PASS` and is classified as `EXTERNAL` / `INVALID`; it is never inferred to be Developer intervention. Developer read/list/get/watch requests are outside the quality condition.

The CLI has no option, prompt, or callback for per-attempt recovery input. The result therefore records `developerRecoveryInputCount=0`; the audit and command evidence establish that the runner did not perform a recovery mutation.

## Output

The CLI prints a concise human-readable verdict, run ID, attempt ID, and the absolute `result.json` path. Machine consumers use `result.json`; stdout formatting is not the evidence contract. `result.json` contains the ordered recovery observations, including the final count and representative-operation result; raw Kubernetes snapshots and audit JSON Lines remain referenced evidence.
