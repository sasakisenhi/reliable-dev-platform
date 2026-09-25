# Quickstart: Validate Self-Healing Runtime

この guide は、実装後の R1 acceptance scenario をローカルまたは CI で実行し、結果を確認する手順である。受け入れ条件は [spec.md](./spec.md)、技術 semantics は [research.md](./research.md)、control flow は [plan.md](./plan.md) を参照する。

## Prerequisites

- Linux
- Docker 互換 container runtime
- Bash 5.x
- kind v0.33.0
- kubectl v1.37.0
- Make

完全な version set は [research.md §7](./research.md#7-reproducible-environment-and-version-pinning) に固定する。Kubernetes node image は`platform/kubernetes/self-healing/kind.yaml` に反映する。

## Validate the E2E script

syntax check:

```bash
bash -n tests/e2e/self-healing.sh
```

Expected: output なし、exit code 0。

predicate、120秒 inclusive boundary、failure-stage mapping の self-test:

```bash
tests/e2e/self-healing.sh --self-test
```

Expected: すべての case が成功し、exit code 0。

## Run the acceptance scenario

```bash
make test-self-healing
```

この command は pinned kind cluster の setup、MVP fixture の apply、acceptance scenario の実行、outcome と診断の出力、fixture cleanup を行う。内部 stage と制約は [plan.md §E2E Control Flow](./plan.md#e2e-control-flow) を参照する。

成功時の出力には少なくとも次が含まれる。

```text
selected pod: <name> uid=<uid>
loss observed: uid=<uid>
recovery complete: instances=<expected-count> operation=success elapsed=<0..120000>ms
```

すべての acceptance criteria を満たした場合だけ exit code 0で終了する。

## Read Failure Diagnostics

失敗時は exit code 1で終了し、次のいずれかの stage と未成立条件を表示する。

| Stage | Meaning |
|---|---|
| `SETUP` | 必須 tool、cluster、fixture、または対象 resource を準備できない |
| `PRECHECK` | 正常な初期状態を確認できない |
| `LOSS_INJECTION` | 選択した loss target への単一 loss request を完了できない |
| `LOSS_OBSERVATION` | scenario guard 内に選択 instance の喪失を確認できない |
| `RECOVERY_DEADLINE` | acceptance deadline 内に recovery completion を確認できない |

補助診断として、対象 namespace の Deployment、ReplicaSet、Pod、Event が read-only で表示される。内部 field と predicate の意味は [data-model.md](./data-model.md) を参照する。

## Inspect a Retained Cluster

失敗後の cluster を保持する場合:

```bash
KEEP_CLUSTER=1 make test-self-healing
```

read-only inspection:

```bash
kubectl --context kind-self-healing get deployment,replicaset,pods -n self-healing -o wide
kubectl --context kind-self-healing get events -n self-healing --sort-by=.lastTimestamp
```

`KEEP_CLUSTER=1` は outcome 確定後の cleanup だけを抑止し、acceptance 判定を変更しない。

## Cleanup

```bash
kind delete cluster --name self-healing
```

cleanup は outcome 確定後に実行する。
