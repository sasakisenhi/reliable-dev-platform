# Phase 0 Research: Self-Healing Runtime

本書は R1 の技術的 decision、semantics、rationale、alternatives、および external sources の canonical owner である。実装構成は [plan.md](./plan.md)、process 内の型と predicate は [data-model.md](./data-model.md) で扱う。

## 1. Recovery mechanism: Kubernetes Deployment reconciliation

**Decision**: `apps/v1` `Deployment` で MVP fixture の期待実行数3を `.spec.replicas` に宣言し、その配下の `ReplicaSet` による標準 reconciliation に Pod 数の維持を委ねる。E2E の `expected_count` は対象 Deployment の `.spec.replicas` から取得し、別の literal として定義しない。

**Rationale**: Deployment は desired state として replica 数を宣言し、その配下の ReplicaSet は指定数を満たすよう Pod を作成・削除する。Pod が失われた場合も、この標準機能が replacement Pod を作成する。

**Alternatives considered**:

- bare Pod: 個体消失後の置換を提供しない。
- 直接管理する ReplicaSet: 可能だが、標準の application workload abstraction である Deployment を避ける利点がない。
- custom Controller / Operator: failure mode と保守責務を増やし、constitution の最小複雑性に反する。

**Sources**:

- https://kubernetes.io/docs/concepts/architecture/self-healing/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/

## 2. Instance identity and RunningInstanceSet

**Decision**: Pod UID を execution instance identity とする。対象 Deployment の `.spec.selector` から導出した selector に一致し、`deletionTimestamp` がなく、`status.phase=Running` の Pod UID 集合を `RunningInstanceSet` と定義する。baseline、loss、recovery の全観測で同じ定義を使う。Ready condition は実行個体数に含めず、application availability は代表操作で独立して確認する。

**Rationale**: UID は object の生存期間を一意に識別し、同名の replacement と元個体を区別できる。選択 UID の集合離脱を観測すれば、総数の一時低下を観測できない場合も個体喪失を識別できる。

**Alternatives considered**:

- Pod name: replacement と元個体の同一性判定として UID より弱い。
- Pod API object の完全消失: 実行対象から外れた後の grace period だけ loss observation を遅らせる可能性がある。
- Deployment の aggregate condition: 選択個体の喪失と exact count を証明できない。
- Ready condition を count に含める: application availability の独立判定と責務が重なる。

**Sources**:

- https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#uids
- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/

## 3. Loss injection: one graceful Pod deletion

**Decision**: baseline の `RunningInstanceSet` から1個を選び、`kubectl delete pod/<name> --wait=false` による通常の graceful delete を1回だけ要求する。

**Rationale**: 単一 Pod deletion は対象 scenario を標準 API だけで再現できる。`--wait=false` により request 後の状態を E2E 自身が観測できる。force delete は API object 消失後にも process が残る可能性があり、Eviction と Chaos framework は R1 に不要な semantics または依存を加える。

**Alternatives considered**:

- `--force --grace-period=0`: API state と実体の乖離を許すため不採用。
- Eviction API: disruption policy の検証が scope 外である。
- Chaos Mesh / Litmus: 単一 Pod deletion には導入コストが過剰である。

**Source**:

- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_delete/

## 4. Feature-specific harness: Bash and kubectl

**Decision**: Linux host 上で動作する Bash 5.x の単一 E2E script を採用し、cluster 操作と Pod state の取得は kubectl に委ねる。経過時間は Linux `/proc/uptime` を millisecond に変換した uptime clock で測る。

**Rationale**: 現在の scenario は1 fixture、1 deletion、1 bounded polling loop で表現できる。追加 runtime、client library、汎用 orchestration framework を導入するより小さい。uptime clock は wall-clock adjustment の影響を受けない。

**Alternatives considered**:

- Go CLI: generic state machine や schema を持たない R1 には source / dependency surface が大きい。
- Chainsaw / KUTTL: 再利用可能 test framework は R4 の検討対象であり、単一 scenario には過剰である。
- `kubectl wait` だけ: 選択 UID の離脱、exact count、代表操作の同一 cycle 成立を一体で判定できない。

**Sources**:

- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_wait/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#deployment-status

## 5. Representative application operation

**Decision**: `registry.k8s.io/e2e-test-images/agnhost:2.66.1` を `serve-hostname` subcommand で起動し、ClusterIP Service を Kubernetes API server の Service proxy 経由で `GET /` する。command が成功し、空でない hostname 応答を得た場合に代表操作成功とする。

**Rationale**: Service proxy は NodePort、Ingress、host port mapping、常駐 port-forward process を追加せず、initial state と recovery で同じ操作を実行できる。

**Alternatives considered**:

- NodePort + kind port mapping: fixture と cluster config に外部公開設定を追加する。
- `kubectl port-forward service`: 選択された Pod の終了時に session が終わり、background process と再接続管理が必要になる。
- probe Pod / `kubectl exec`: scenario 中に追加 Pod creation または個体への直接操作を持ち込む。

**Sources**:

- https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster-services/
- https://kubernetes.io/docs/concepts/cluster-administration/proxies/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_port-forward/
- https://github.com/kubernetes/kubernetes/tree/master/test/images/agnhost

## 6. Loss observation and recovery deadline

**Decision**: delete request 後60秒の scenario guard 内で、選択 UID が `RunningInstanceSet` から最初に外れた観測を待つ。その観測時の uptime を `loss_observed_at` とし、120秒 timer を開始する。delete request 時刻、Pod object の完全削除、総実行数の減少は timer origin にしない。

loss observation 後は bounded observation cycle を繰り返す。同一 cycle 内で次のすべてが成立し、cycle 完了時の elapsed time が120,000ms以下なら recovery completion とする。

- `count == expected_count`
- representative operation success
- selected UID absent

各 kubectl request には有限の request timeout を設定する。代表操作の一時的失敗は deadline まで再試行できる。60秒 guard は scenario 成立確認用であり、120秒 acceptance threshold には含めない。

**Rationale**: timer origin を identity loss の観測へ固定し、count と operation を同一 cycle で評価することで、別々の時点で一度ずつ成立しただけの false positive を防ぐ。

**Alternatives considered**:

- delete request を timer origin にする: clarification と FR-005 に反する。
- `Deployment.progressDeadlineSeconds`: rollout 用であり、この feature の timer origin や代表操作を表さない。
- count と operation の独立 wait: 同時成立を証明できない。

## 7. Reproducible environment and version pinning

**Decision**: kind v0.33.0、同 release の `kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5`、kubectl v1.37.0、agnhost 2.66.1を固定する。cluster は単一 node とする。

**Rationale**: kind は CI で stable tagged release を推奨し、node image は同じ kind release が公開した digest の利用を案内している。単一 node は Pod loss と node failure を混同しない。

**Alternatives considered**:

- floating latest / default image: CI behavior が時間とともに変わる。
- multi-node kind: node failure という scope 外の変数を追加する。

**Sources**:

- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0
- https://kubernetes.io/releases/version-skew-policy/

## 8. Contracts and evidence scope

**Decision**: R1 では generic PASS / FAIL / INVALID model、generic evidence contract、audit actor attribution、additional-failure attribution、および reusable Platform E2E framework を作らない。これらは `ROADMAP.md` R4 へ延期する。R1 の結果は command exit status と通常の診断情報で表す。

**Rationale**: 現在の feature は単一 acceptance scenario の実証を求め、再利用可能な framework や永続 evidence contract を要求しない。先行導入は constitution の最小複雑性に反する。

**Alternatives considered**:

- application / profile / result JSON Schema: ownershipと再利用性を扱う R4 で設計する。
- database または artifact bundle: FR-007 は未成立条件の通常診断を求めるだけで、永続化を要求しない。
