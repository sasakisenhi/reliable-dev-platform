# Data Model: Self-Healing Runtime

本書は feature-specific E2E process が1試行中に保持する concept、field、type、invariant、predicate、relationship、state transition の canonical owner である。技術 semantics は [research.md](./research.md)、component responsibility と制約は [plan.md](./plan.md) を参照する。

## VerificationFixture

| Field | Type | Invariant |
|---|---|---|
| `namespace` | string | checked-in fixture の namespace |
| `deploymentName` | string | 対象 Deployment を一意に指定 |
| `podSelector` | string | 対象 Deployment の `.spec.selector` から導出 |
| `expectedInstances` | integer | 対象 Deployment の `.spec.replicas` から取得。MVP fixture では `3` |
| `representativeOperationPath` | string | `/` |
| `recoveryThresholdMilliseconds` | integer | `120000` |
| `lossObservationTimeoutSeconds` | integer | `60`。acceptance threshold には含めない |
| `pollIntervalSeconds` | integer | 正数 |
| `requestTimeoutSeconds` | integer | 正数。単一 request が observation boundary を阻害しない値 |

`podSelector` と `expectedInstances` を E2E 側の別定義で上書きしてはならない。

## ExecutionInstance

| Field | Type | Invariant |
|---|---|---|
| `name` | string | loss request の resource name |
| `uid` | string | 個体 identity |
| `phase` | string | Kubernetes Pod phase |
| `terminating` | boolean | `deletionTimestamp` の有無から算出 |

### RunningInstanceSet representation

[research.md §2](./research.md#2-instance-identity-and-runninginstanceset) で定義した `RunningInstanceSet` を、process 内では `set<string>` の Pod UID 集合として保持する。

## BaselineObservation

| Field | Type | Invariant |
|---|---|---|
| `runningInstanceUids` | set&lt;string&gt; | 要素数が `expectedInstances` と一致 |
| `operationSucceeded` | boolean | representative operation result |

baseline predicate:

```text
size(runningInstanceUids) == expectedInstances
AND operationSucceeded
```

## LossTarget

| Field | Type | Invariant |
|---|---|---|
| `name` | string | baseline の `runningInstanceUids` に対応する Pod name |
| `uid` | string | baseline の `runningInstanceUids` に含まれ、選択後は不変 |

## LossObservation

| Field | Type | Invariant |
|---|---|---|
| `targetUid` | string | `LossTarget.uid` と一致 |
| `lossObservedUptimeMilliseconds` | integer | canonical loss observation が成立した uptime |

## RecoveryObservation

| Field | Type | Invariant |
|---|---|---|
| `sequence` | integer | 0から単調増加 |
| `elapsedMilliseconds` | integer | cycle completion uptime - `lossObservedUptimeMilliseconds` |
| `operationSucceeded` | boolean | cycle 内の representative operation result |
| `runningInstanceUids` | set&lt;string&gt; | cycle 内の Pod snapshot から算出 |
| `targetUidAbsent` | boolean | `targetUid` が `runningInstanceUids` に含まれない |
| `recoveryComplete` | boolean | 下記 predicate の結果 |

```text
recoveryComplete =
  elapsedMilliseconds <= recoveryThresholdMilliseconds
  AND operationSucceeded
  AND size(runningInstanceUids) == expectedInstances
  AND targetUidAbsent
```

## VerificationOutcome

| Field | Type | Invariant |
|---|---|---|
| `succeeded` | boolean | `recoveryComplete` が成立した場合だけ true |
| `failureStage` | enum / null | `SETUP`、`PRECHECK`、`LOSS_INJECTION`、`LOSS_OBSERVATION`、`RECOVERY_DEADLINE`、成功時 null |
| `message` | string | 未成立条件と最後の観測値を含む |

- `succeeded=true` は process exit code 0へ写像する。
- `succeeded=false` は process exit code 1へ写像する。

## Entity Relationships

```text
VerificationFixture
  ├── defines expectedInstances and observation limits
  ├── selects ExecutionInstance values
  └── supplies representative operation input

BaselineObservation
  └── selects one LossTarget

LossTarget
  └── is referenced by LossObservation and every RecoveryObservation

RecoveryObservation[*]
  └── determines one VerificationOutcome
```

## State Transitions

```text
SETUP
  -> PRECHECK
  -> SELECT_TARGET
  -> INJECT_LOSS
  -> WAIT_TARGET_ABSENT
  -> OBSERVE_RECOVERY
  -> SUCCEEDED

SETUP -------------> FAILED(SETUP)
PRECHECK ----------> FAILED(PRECHECK)
INJECT_LOSS -------> FAILED(LOSS_INJECTION)
WAIT_TARGET_ABSENT -> FAILED(LOSS_OBSERVATION)
OBSERVE_RECOVERY --> FAILED(RECOVERY_DEADLINE)
```

State transition 中の許可 operation と cleanup boundary は [plan.md §E2E Control Flow](./plan.md#e2e-control-flow) に従う。
