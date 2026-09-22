# Quickstart: Validate Self-Healing Runtime

This guide describes the end-to-end validation expected after implementation. It uses the contracts in [`contracts/`](./contracts/) and does not replace the canonical conditions in [`spec.md`](./spec.md).

## Prerequisites

- Linux with a working Docker-compatible container runtime
- Go 1.26.8
- `kubectl` 1.35
- kind 0.31.0
- Repository root as the current directory

The cluster configuration pins:

```text
kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f
```

Check tools without changing cluster state:

```bash
go version
kubectl version --client
kind version
go mod download
go test ./internal/selfhealing/...
go build -o bin/self-healing ./cmd/self-healing
```

Expected: `go.mod` / `go.sum` resolve `github.com/santhosh-tekuri/jsonschema/v6` v6.0.3. Go table-driven unit tests use recorded JSON fixtures to cover all verdict branches, the inclusive 120-second boundary, operation retry, UID absence from the managed object set without a count dip, conflict-safe attribution predicates, and `UNKNOWN → INVALID`. Contract tests use the adopted Draft 2020-12 compiler with format assertions enabled; no local JSON Schema implementation exists. The build produces `bin/self-healing`.

## 1. Create the reproducible cluster

```bash
mkdir -p artifacts/self-healing/audit
kind create cluster --name reliable-dev-platform --config platform/kubernetes/self-healing/kind.yaml
kubectl cluster-info --context kind-reliable-dev-platform
```

Expected: a single-node Kubernetes 1.35 cluster is reachable through `kind-reliable-dev-platform`.
The kind configuration enables the Kubernetes audit file backend using `platform/kubernetes/self-healing/audit-policy.yaml` and mounts its log to the host under `artifacts/self-healing/audit/`.

## 2. Deploy the sample workload

```bash
kubectl --context kind-reliable-dev-platform apply -f platform/kubernetes/self-healing/namespace.yaml
kubectl --context kind-reliable-dev-platform apply -f platform/kubernetes/self-healing/rbac.yaml
kubectl --context kind-reliable-dev-platform apply -f platform/kubernetes/self-healing/deployment.yaml
kubectl --context kind-reliable-dev-platform apply -f platform/kubernetes/self-healing/service.yaml
kubectl --context kind-reliable-dev-platform -n self-healing wait \
  --for=condition=Available deployment/self-healing-sample --timeout=120s
```

Expected: the Deployment declares three replicas and reaches the normal initial state. This setup wait is not the recovery timer.

Create the dedicated QA kubeconfig before the verification window:

```bash
./bin/self-healing bootstrap \
  --admin-context kind-reliable-dev-platform \
  --verification-profile config/self-healing/verification-profile.json
```

Expected: the short-lived ServiceAccount credential is written to the profile's `qaKubeconfigPath`. All later runner requests use this identity, while audit evidence remains readable from the host-side `auditLogPath`.
The RBAC permits read-only workload observation and `get` on the sample Service proxy. The only allowed mutating request is one graceful delete of the selected Pod.

## 3. Validate inputs

```bash
./bin/self-healing validate \
  --application-contract config/self-healing/application-contract.json \
  --verification-profile config/self-healing/verification-profile.json
```

Expected:

- both JSON documents satisfy their schemas;
- expected instances equals `Deployment.spec.replicas`;
- the active Pod set contains three UIDs;
- the representative operation uses the QA kubeconfig and the Kubernetes API Service proxy, and succeeds;
- no loss is injected.

## 4. Run the Self-Healing verification

```bash
./bin/self-healing run \
  --application-contract config/self-healing/application-contract.json \
  --verification-profile config/self-healing/verification-profile.json
```

The runner must:

1. confirm the initial count and representative operation;
2. select one active Pod UID;
3. issue one graceful Pod delete;
4. start the 120-second timer only when that UID is first absent from the Deployment-owned Pod API object set; `deletionTimestamp` alone is not sufficient;
5. retry the representative operation and immediately sample the active count after each operation within the deadline;
6. finish only when the operation succeeded and the immediately following count sample exactly matches the expected count in one observation;
7. record `PASS`, `FAIL`, or `INVALID` with evidence;
8. retain an `INVALID` attempt and exit; after the initial conditions recover externally, rerun with the reported run ID to create a new attempt.

Expected happy-path output:

```text
verdict=PASS
qualityEvaluationIncluded=true
developerRecoveryInterventionObserved=false
result=<absolute path to result.json>
```

The aggregate Pod count is allowed to avoid a visible dip. The selected UID still must leave the Deployment-owned `ManagedPodSet`.

## 5. Inspect traceable evidence

```bash
result_file=$(find artifacts/self-healing -name result.json -type f | sort | tail -n 1)
sed -n '1,240p' "$result_file"
```

Verify that the result contains:

- contract and profile SHA-256 digests;
- initial expected/current count and representative operation result;
- selected Pod name and UID;
- delete request acceptance time and distinct first-absent time;
- recovery deadline, observations, final count, and operation result;
- `developerRecoveryInputCount=0` and the recovery-intervention flag;
- additional-failure attribution;
- the exact attribution predicate and audit evidence showing the dedicated QA actor's single Pod delete;
- one verdict and Requirement-linked reasons when not PASS;
- references to command, observation, Kubernetes object, and event evidence.

## 6. Exercise verdict classification with fixtures

Run the pure classifier against recorded snapshots, audit events, and command results. These tests exercise decision branches without adding artificial cluster services or a fault-injection platform:

```bash
go test ./internal/selfhealing/... -run 'Test(Classify|Timing)' -v
```

Expected scenarios:

- initial condition missing → `INVALID`, reason recorded, excluded, rerun required;
- selected UID loss unconfirmed → `INVALID`;
- external or out-of-scope additional failure → `INVALID`;
- unknown-cause additional failure → `INVALID`;
- Platform/recovery-caused additional failure → valid `FAIL`;
- fixed `DEVELOPER_TEST` fixture actorによる定義済みrecovery mutation → valid intervention `FAIL`;
- `OTHER` actorによる対象workload mutation → externally-caused `INVALID`; `OTHER` is never inferred to be a Developer;
- incomplete, conflicting, or multiply-matching attribution evidence → `UNKNOWN` and `INVALID`;
- recovery condition not met within 120 seconds → valid `FAIL`;
- representative operation initially fails and later succeeds within the deadline → `PASS`.

Each fixture asserts the verdict, reason code, attribution predicate, quality inclusion, and required FR-006 fields in `result.json`. The `DEVELOPER_TEST` username exists only in recorded audit fixtures; the normal kind manifests, RBAC, and verification profile do not create or configure that identity.

## 7. Run the automated capability E2E

```bash
go test -tags=e2e ./tests/e2e -v
```

The E2E test creates the pinned kind cluster fixture and proves the primary Platform capability path: normal initial state, one graceful Pod delete, selected UID absence from `ManagedPodSet`, Deployment/ReplicaSet replacement without runner assistance, simultaneous expected count and Service-proxy operation success within 120 seconds, and a schema-valid `PASS` result. Classifier-only branches remain fixture tests from step 6.

## 8. Retry an INVALID attempt

After an `INVALID`, inspect its reason and restore the prescribed initial conditions outside the runner. Then reuse the printed run ID:

```bash
./bin/self-healing run \
  --application-contract config/self-healing/application-contract.json \
  --verification-profile config/self-healing/verification-profile.json \
  --run-id <reported-run-id>
```

Expected: the previous evidence remains, a new attempt ID is created, and the runner performs no scale, restart, Pod creation, or other repair action.

## 9. Cleanup

```bash
kind delete cluster --name reliable-dev-platform
```

Evidence under `artifacts/self-healing/` remains available after cluster cleanup.
