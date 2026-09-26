---

description: "Implementation tasks for the Self-Healing Runtime feature"
---

# Tasks: Self-Healing Runtime

**Input**: Design documents from `/specs/001-self-healing-runtime/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `quickstart.md`

**Tests**: `spec.md` requires a reproducible automated E2E verification. The plan also requires fixed-input `--self-test` coverage for predicates, the inclusive 120-second boundary, and every failure stage.

**Organization**: Tasks are grouped by user story so the recovery capability and its automated quality proof can be implemented and checked as separate increments.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes a different file and does not depend on an incomplete task
- **[Story]**: Maps a task to User Story 1 (`US1`) or User Story 2 (`US2`)
- Every task names the file it changes or validates

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the feature-specific source layout and pinned local cluster definition.

- [ ] T001 Create an executable Bash 5.x harness skeleton with strict mode, `--self-test` dispatch, staged `main`, and an outcome-aware cleanup trap in `tests/e2e/self-healing.sh`
- [ ] T002 [P] Define the single-control-plane `self-healing` kind cluster using `kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5` in `platform/kubernetes/self-healing/kind.yaml`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement the shared fixture, cluster, observation, and outcome primitives required by both user stories.

**Critical**: Complete this phase before either user story.

- [ ] T003 Encode `VerificationFixture` inputs in `tests/e2e/self-healing.sh` with the exact invariants `namespace`: "checked-in fixture の namespace", `deploymentName`: "対象 Deployment を一意に指定", `representativeOperationPath`: "`/`", `recoveryThresholdMilliseconds`: "`120000`", `resourceSetupTimeoutSeconds`: "`60`。fixture apply 成功後に対象 Deployment と Service の取得を待つ上限。acceptance threshold には含めない", `precheckTimeoutSeconds`: "`120`。対象 resource の取得後に baseline predicate の成立を待つ上限。acceptance threshold には含めない", `lossObservationTimeoutSeconds`: "`60`。acceptance threshold には含めない", `pollIntervalSeconds`: "正数", `requestTimeoutSeconds`: "正数。単一 request が observation boundary を阻害しない値", and `serviceName`: "representative operation の対象 Service を一意に指定"
- [ ] T004 Implement prerequisite checks for Linux, Docker, Bash 5.x, kind v0.33.0, and kubectl v1.37.0 plus cluster creation, fixture apply, bounded Deployment/Service acquisition, and outcome-aware cleanup helpers honoring `KEEP_CLUSTER=1` in `tests/e2e/self-healing.sh`, mapping apply or resource setup guard failure to `SETUP`
- [ ] T005 Implement bounded kubectl helpers and one-snapshot Pod parsing in `tests/e2e/self-healing.sh`, deriving `podSelector` with "対象 Deployment の `.spec.selector` から導出" and `expectedInstances` with "対象 Deployment の `.spec.replicas` から取得。MVP fixture では `3`" without E2E overrides, and representing `ExecutionInstance` fields with the exact invariants `name`: "loss request の resource name", `uid`: "個体 identity", `phase`: "Kubernetes Pod phase", and `terminating`: "`deletionTimestamp` の有無から算出"
- [ ] T006 Add success/failure outcome emitters and read-only diagnostic command helpers in `tests/e2e/self-healing.sh` with the exact `VerificationOutcome` invariants `succeeded`: "`recoveryComplete` が成立した場合だけ true", `failureStage`: "`SETUP`、`PRECHECK`、`LOSS_INJECTION`、`LOSS_OBSERVATION`、`RECOVERY_DEADLINE`、成功時 null", and `message`: "未成立条件と最後の観測値を含む", mapping success to exit 0 and failure to exit 1

**Checkpoint**: Shared inputs, lifecycle operations, snapshots, and outcome primitives are available.

---

## Phase 3: User Story 1 - 手動復旧なしで利用を再開する (Priority: P1) MVP

**Goal**: Demonstrate that a three-replica application returns to the expected instance count and usable state within 120 seconds of observing one selected Pod UID leave the running set, without recovery input or mutation.

**Independent Test**: Run `tests/e2e/self-healing.sh` against the checked-in kind fixture; after one graceful Pod deletion, verify that the selected UID becomes absent and, within an inclusive 120,000 ms from that observation, the running UID count is exactly three while `GET /` through the Service proxy succeeds.

### Tests for User Story 1

- [ ] T007 [US1] Add initially failing fixed-input self-test cases for bounded baseline polling success before `precheckTimeoutSeconds`, expiry with resources present, selected-UID loss observation despite an unchanged total count, transient representative-operation failure followed by success, simultaneous recovery conditions, success at exactly `120000` ms, and failure at `120001` ms in `tests/e2e/self-healing.sh`
- [ ] T008 [P] [US1] Create the `self-healing` Namespace, `apps/v1` Deployment with `.spec.replicas: 3`, stable selector labels, pinned `registry.k8s.io/e2e-test-images/agnhost:2.66.1 serve-hostname`, and ClusterIP Service exposing the representative operation in `platform/kubernetes/self-healing/workload.yaml`

### Implementation for User Story 1

- [ ] T009 [US1] After required resources exist, implement bounded baseline polling and Service-proxy `GET /` in `tests/e2e/self-healing.sh` with the exact `BaselineObservation` invariants `runningInstanceUids`: "同一 precheck cycle の Pod snapshot から算出" and `operationSucceeded`: "同一 precheck cycle の representative operation result", accepting only `size(runningInstanceUids) == expectedInstances AND operationSucceeded` in one cycle and mapping deadline expiry to `PRECHECK`
- [ ] T010 [US1] Select and freeze one baseline Pod identity, issue exactly one `kubectl delete pod/<name> --wait=false`, and observe its absence within 60 seconds in `tests/e2e/self-healing.sh` with the exact `LossTarget` invariants `name`: "baseline の `runningInstanceUids` に対応する Pod name" and `uid`: "baseline の `runningInstanceUids` に含まれ、選択後は不変", plus `LossObservation` invariants `targetUid`: "`LossTarget.uid` と一致" and `lossObservedUptimeMilliseconds`: "canonical loss observation が成立した uptime"
- [ ] T011 [US1] Implement the mutation-free bounded recovery loop using `/proc/uptime` in `tests/e2e/self-healing.sh` with the exact `RecoveryObservation` invariants `sequence`: "0から単調増加", `elapsedMilliseconds`: "cycle completion uptime - `lossObservedUptimeMilliseconds`", `operationSucceeded`: "cycle 内の representative operation result", `runningInstanceUids`: "cycle 内の Pod snapshot から算出", `targetUidAbsent`: "`targetUid` が `runningInstanceUids` に含まれない", and `recoveryComplete`: "下記 predicate の結果", requiring `elapsedMilliseconds <= recoveryThresholdMilliseconds`, operation success, exact expected count, and target UID absence in the same cycle
- [ ] T012 [US1] Wire the directly executable `SETUP -> PRECHECK -> SELECT_TARGET -> INJECT_LOSS -> WAIT_TARGET_ABSENT -> OBSERVE_RECOVERY -> SUCCEEDED/FAILED -> cleanup` flow in `tests/e2e/self-healing.sh`, restrict the post-injection pre-outcome path to read-only observation plus the representative HTTP operation, honor `KEEP_CLUSTER=1` only after outcome finalization, and emit `selected pod`, `loss observed`, and `recovery complete` values

**Checkpoint**: User Story 1 passes its fixed-input cases and the direct kind acceptance scenario without manual recovery.

---

## Phase 4: User Story 2 - Self-Healing を自動検証する (Priority: P2)

**Goal**: Provide one repeatable command that succeeds only when all acceptance conditions hold and otherwise identifies the unmet condition with staged diagnostics.

**Independent Test**: Run `tests/e2e/self-healing.sh --self-test` to exercise every success/failure branch, then run `make test-self-healing`; verify exit 0 only for full recovery and exit 1 with the correct stage and read-only Deployment, ReplicaSet, Pod, and Event diagnostics for each unmet condition.

### Tests for User Story 2

- [ ] T013 [US2] Add initially failing fixed-input cases for exit status and unmet-condition messages at `SETUP` including resource setup guard expiry, `PRECHECK` including baseline guard expiry with resources present, `LOSS_INJECTION`, `LOSS_OBSERVATION`, and `RECOVERY_DEADLINE`, plus cleanup behavior for default and `KEEP_CLUSTER=1`, in `tests/e2e/self-healing.sh`
- [ ] T014 [P] [US2] Add the phony `test-self-healing` target in `Makefile` as the primary user-facing acceptance entrypoint, invoking `tests/e2e/self-healing.sh`
### Implementation for User Story 2

- [ ] T015 [US2] Route prerequisite/cluster/apply/resource acquisition failures to `SETUP`, bounded baseline expiry after resources exist to `PRECHECK`, delete-request failures to `LOSS_INJECTION`, absent-UID guard expiry to `LOSS_OBSERVATION`, and incomplete same-cycle recovery by the inclusive deadline to `RECOVERY_DEADLINE` in `tests/e2e/self-healing.sh`
- [ ] T016 [US2] On failure, print the stage, unmet predicate, last observed count/operation/UID/elapsed values, and read-only Deployment, ReplicaSet, Pod, and Event diagnostics without masking the original exit status in `tests/e2e/self-healing.sh`
- [ ] T017 [US2] Complete the fixed-input `--self-test` runner, assert exit code 0 for its positive case and exit code 1 plus the expected stage / unmet-condition message for at least one case per non-null `VerificationOutcome.failureStage` value, and prevent all external cluster mutations in self-test mode in `tests/e2e/self-healing.sh`

**Checkpoint**: User Story 2 provides a deterministic self-test surface and a single automated acceptance command with actionable failures.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Validate the complete feature against its documented quality gates and mutation boundary.

- [ ] T018 Audit the post-injection pre-outcome command path for forbidden scale, rollout restart, replacement creation, additional delete, or other recovery-promoting mutations and record any explanatory comments beside that path in `tests/e2e/self-healing.sh`
- [ ] T019 Run `bash -n tests/e2e/self-healing.sh` and resolve every syntax failure in `tests/e2e/self-healing.sh`
- [ ] T020 Run `tests/e2e/self-healing.sh --self-test` and resolve every predicate, inclusive-boundary, stage-mapping, exit-status, and cleanup regression in `tests/e2e/self-healing.sh`
- [ ] T021 Execute both `tests/e2e/self-healing.sh` and `make test-self-healing` on the pinned Linux + Docker environment and verify equivalent success output, the `0..120000ms` elapsed bound, exit status, and cleanup/retention instructions against `specs/001-self-healing-runtime/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Depends on Setup and blocks both stories.
- **User Story 1 (Phase 3)**: Depends on Foundational and produces the MVP recovery capability.
- **User Story 2 (Phase 4)**: Depends on User Story 1 because its acceptance harness verifies that capability end to end.
- **Polish (Phase 5)**: Depends on the selected user stories; the full acceptance run requires both.

### User Story Dependency Graph

```text
Setup -> Foundational -> US1 (MVP recovery) -> US2 (automated proof) -> Polish
```

### Within User Story 1

- T007 defines the expected predicate behavior before T009-T012 implement it.
- T008 changes only the workload manifest and can run in parallel with T007.
- T009 establishes a valid baseline before T010 injects loss.
- T010 establishes the timer origin before T011 evaluates recovery.
- T012 integrates setup through cleanup so US1 can execute and validate the complete scenario directly without US2.

### Within User Story 2

- T013 defines the failure and cleanup expectations before T015-T017 implement them.
- T014 changes only `Makefile` and can run in parallel with T013.
- T015 completes stage routing before T016 enriches failures and T017 completes the fixed-input self-test runner.

### Parallel Opportunities

- T002 can run in parallel with T001 because it changes a separate manifest.
- T008 can run in parallel with T007 after Foundational completes.
- T014 can run in parallel with T013 after User Story 1 completes.

---

## Parallel Example: User Story 1

```text
Task T007: Add fixed-input recovery predicate and boundary cases in tests/e2e/self-healing.sh
Task T008: Create the Deployment and Service fixture in platform/kubernetes/self-healing/workload.yaml
```

## Parallel Example: User Story 2

```text
Task T013: Add fixed-input failure-stage and cleanup cases in tests/e2e/self-healing.sh
Task T014: Add the acceptance target in Makefile
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Complete Setup and Foundational tasks.
2. Complete T007-T012 for User Story 1.
3. Run the fixed-input US1 cases and the direct kind scenario.
4. Stop and validate the hypothesis: no recovery decision or operation is required after the single loss injection.

### Incremental Delivery

1. Deliver US1 to prove standard Deployment reconciliation restores count and availability.
2. Add US2 to make the proof reproducible through one command and expose every failed condition.
3. Complete the cross-cutting mutation audit, syntax check, self-tests, and pinned-environment acceptance run.

### Parallel Team Strategy

1. Complete Setup and Foundational sequentially where tasks share `tests/e2e/self-healing.sh`.
2. In US1, implement the fixed-input cases and Kubernetes workload manifest in parallel, then finish the script flow sequentially.
3. In US2, implement failure self-tests and the Make target in parallel, then finish stage diagnostics and orchestration sequentially.

---

## Notes

- `[P]` appears only where tasks touch different files and have no incomplete dependency.
- The E2E script derives selector and expected count from the Deployment; it must not duplicate those values as acceptance inputs.
- Resource setup waits at most 60 seconds and maps expiry to `SETUP`; after resources exist, baseline polling waits at most 120 seconds and maps expiry to `PRECHECK`.
- The 60-second loss-observation guard precedes and is excluded from the inclusive 120,000 ms recovery threshold.
- Outcome cleanup may mutate resources only after success or failure is final.
- Generic evidence schemas, reusable E2E frameworks, and failure attribution remain outside R1 scope.
