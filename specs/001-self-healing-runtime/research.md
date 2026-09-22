# Phase 0 Research: Self-Healing Runtime

## 1. Recovery mechanism: adopt Kubernetes Deployment reconciliation

**Decision**: `apps/v1` `Deployment` と、その配下の `ReplicaSet` に期待実行数の維持を委ねる。独自 Controller / Operator は実装しない。

**Rationale**: ReplicaSet は指定された Pod 数を維持し、Deployment は ReplicaSet を管理する標準の上位 workload API である。単一 Pod 喪失後の置換は Commodity Capability であり、FR-002 を満たすために同じ reconciliation loop を再実装する理由がない。Platform 固有の価値は、責務境界、120秒の品質条件、三値判定、verification evidence に置く。

**Alternatives considered**:

- 直接 `ReplicaSet` を管理: 実現可能だが、Kubernetes は通常 Deployment の利用を推奨しており、将来の workload 更新にも不利。
- bare Pod: 削除・終了時に自動置換されないため不採用。
- custom Controller / Operator: 標準機能を重複実装し、新しい failure mode と運用責務を増やすため不採用。

**Sources**:

- https://kubernetes.io/docs/concepts/architecture/self-healing/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/
- https://kubernetes.io/docs/concepts/extend-kubernetes/operator/

## 2. Instance identity and active-set observation

**Decision**: 喪失対象の identity には Pod UID を使う。対象 Deployment 配下の ReplicaSet が管理する全 Pod API object の UID 集合を ManagedPodSet とする。そのうち、deletionTimestamp がなく、実行中のインスタンスとして扱える Pod の UID 集合を CurrentExecutionSet とする。喪失成立は、対象 UID が ManagedPodSet から存在しなくなった最初の観測とする。期待実行数との比較には CurrentExecutionSet の要素数を用い、アプリケーション利用可能性は代表的な利用操作の成功によって独立して判定する。

**Rationale**: Kubernetes object の同一性は UID で区別でき、replacement は別 UID になる。Pod name、delete request の応答、総実行数の一時的な減少は identity loss の確実な根拠にならない。graceful deletion では request 受理後に `deletionTimestamp` が付いても Pod object と process が残り得るため、timestamp の付与だけでは計測を開始しない。一方、復旧完了の現在実行数は Ready かつ非終了Kubernetes object の同一性は UID で区別でき、replacement は別 UID になる。Pod name、delete request の応答、総実行数の一時的な減少は identity loss の確実な根拠にならない。graceful deletion では request 受理後に deletionTimestamp が付いても Pod object と process が残り得るため、timestamp の付与だけでは計測を開始しない。一方、復旧完了の現在実行数は Ready かつ非終了の ActivePodSet で数え、代表的なアプリケーション操作と別々に観測する。

**Alternatives considered**:

- Pod name: 再利用可能で identity として弱いため不採用。
- delete request の受理時刻: FR-004 の計測起点と矛盾するため不採用。
- `deletionTimestamp` の付与: graceful termination 中の実体が残り得るため、喪失成立の根拠として不採用。
- aggregate replica count の減少: replacement が速い場合に観測できず、Clarification と矛盾するため不採用。
- Deployment `Available` condition だけ: 正確な個体数と対象 UID の喪失を表さないため不採用。

**Sources**:

- https://kubernetes.io/docs/concepts/overview/working-with-objects/names/
- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- https://kubernetes.io/docs/reference/kubernetes-api/apps/deployment-v1/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

## 3. Loss injection

**Decision**: Platform QA runner が、対象Deployment配下のReplicaSetが管理するPodを1つ選び、通常の graceful delete を1回だけ実行する。

**Rationale**: 単一 Pod delete は標準 API で表現でき、Chaos platform を導入する必要がない。force deletion は API object を即座に消しても node 上の process が残る可能性があり、対象個体の実際の喪失を曖昧にする。API Eviction は PDB など別の disruption semantics を追加する。

**Alternatives considered**:

- `kubectl delete --force`: 残存 process と API identity の乖離を生むため不採用。
- Eviction API: 現在の Requirement にない PDB / disruption policy を持ち込むため不採用。
- Chaos Mesh / Litmus: 単一 Pod delete の MVP には導入・運用コストが過剰。Node、network、storage fault が scope に入る時点で再評価する。

**Sources**:

- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_delete/
- https://kubernetes.io/docs/concepts/scheduling-eviction/api-eviction/

## 4. Verification harness: thin Go CLI over kubectl

**Decision**: Go 1.26.8、既存のGo JSON Schema validator、`kubectl -o json` を使う単一CLIを実装する。cluster access、Pod delete、read-only observationはkubectlに委ね、Goはstate machine、単調時計、三値判定、evidence serializationを担う。

**Rationale**: このFeatureは`PASS` / `FAIL`に加えて理由付き`INVALID`を要求し、delete requestではなくUIDのfirst-absent observationから120秒を測る。さらに、同一observationでのcount / operation成立とRequirementまで遡れるevidenceが必要である。Go標準libraryの`os/exec`、`time`、`encoding/json`、`testing`でCLI、単調時間、証跡、table-driven testを構成し、標準化済みのJSON Schema検証だけを既存packageへ委ねる。単一binaryにすることでruntime package環境を別途管理しない。Go 1.26.8は対象環境に導入済みのsupported releaseであり、本Featureは1.27固有機能を必要としないためtoolchain更新を追加しない。

**Alternatives considered**:

- Chainsaw: declarative step、timeout、assertion、command output は採用候補だが、標準は test success / failure を中心としており、本仕様の `INVALID`、原因帰属、再実行、evidence schema には custom script が必要。Chainsaw と custom state machine の二重 orchestration を避ける。
- KUTTL: Kubernetes object の declarative assertion には適するが、同じく三値判定と固有の計測起点には追加 harness が必要。
- Bash + jq: 小さく開始できるが、時間境界、例外、structured evidence、classifier unit test の保守性が低い。
- Python CLI: 実現可能だが、今回はGoへ統一し、Python runtimeとpackage環境を追加しない。
- Go 1.27.1: 現行stableだが本Featureに必要な差分がなく、対象環境の1.26.8を変更する理由がないため不採用。
- `client-go`: Kubernetes API型を直接利用できるが、MVPにはdependency surfaceが大きい。kubectl JSONで不足が判明した場合に再評価する。

**Sources**:

- https://kyverno.github.io/chainsaw/main/test/
- https://kyverno.github.io/chainsaw/main/test/spec/
- https://github.com/kyverno/chainsaw
- https://github.com/kudobuilder/kuttl
- https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands
- https://go.dev/doc/devel/release

## 5. Application contract and verification profile

**Decision**: Developer 所有の application-contract.json と Platform QA 所有の verification-profile.json を分離し、両者を machine-readable schema で検証する。Developer contract は期待実行数と「アプリケーションが利用可能であることを確認する代表操作の意味」を定義する。namespace、Deployment、Service、credential、polling、代表操作を検証環境上で実行するための接続方式など、Platform 固有の情報は verification profile 側で管理する。

**Rationale**: Developer が維持すべき責務は、「いくつの実行インスタンスを期待するか」と「何が成功すればアプリケーションを利用可能と判断できるか」の定義である。その確認を Kubernetes 上でどの resource や接続方式を使って実行するかは Platform QA の責務であり、Developer contract へ漏らさない。QA profile が Developer contract の意味を具体的な cluster workload と検証方法へ bind することで、検証ごとの Developer 入力を不要にし、同じ application contract を初期状態確認と復旧判定の双方で利用できる。

**Alternatives considered**:

- Developer contract に kubectl argv を直接保持する: namespace、Service 名、接続方式など Platform 固有の知識を Developer に要求し、責務境界を曖昧にするため不採用。
- Contract と profile を1ファイルに統合: Developer と Platform QA の責務が混在するため不採用。
- CRDとしてcluster内に保持: lifecycle management と cluster API surface が増えるが、このFeatureではrepo-local contractで十分なため不採用。

## 6. JSON Schema validation: adopt `santhosh-tekuri/jsonschema`

**Decision**: Go module `github.com/santhosh-tekuri/jsonschema/v6` v6.0.3を採用する。compilerのDraft 2020-12 supportと`AssertFormat()`を使い、入力contract、profile、trial resultを検証する。独自validatorは実装しない。

**Rationale**: contractsは`if` / `then`、`oneOf`、`format`、`$defs`を利用する。これらの解釈はCommodity Capabilityであり、Feature固有の学習目的も改善仮説もない。v6はDraft 2020-12を明示的に提供し、format assertionも有効化できるため、入力と出力を同じ契約で検査できる。

**Alternatives considered**:

- Go標準libraryによる手書きvalidation: schema keywordとformat semanticsの再実装になり、contractsとの二重管理を生むため不採用。
- `github.com/xeipuuv/gojsonschema`: Draft 04/06/07までで、現在のDraft 2020-12 contractsと一致しないため不採用。
- `github.com/google/jsonschema-go`: Draft 2020-12対応の有効な選択肢だが、本MVPではcompiler、validation、明示的なformat assertionを一つのversioned moduleで提供する採用案以上の利点がないため不採用。
- schemaを文書用途だけにする: machine-readable contractsを実行時に検証できず、FR-006/FR-007のevidence contractを弱めるため不採用。

**Sources**:

- https://pkg.go.dev/github.com/santhosh-tekuri/jsonschema/v6
- https://github.com/xeipuuv/gojsonschema
- https://github.com/google/jsonschema-go
- https://json-schema.org/draft/2020-12/json-schema-validation

## 7. Representative application operation and reachability

**Decision**: Developer contract は代表操作の意味を Platform 非依存の形で定義し、Platform QA profile がその操作を検証環境上で実行する方法へ bind する。MVP sampleでは、Developer contract が HTTP GET / の成功を代表操作として定義し、QA profile が対象 namespace、Service、port、および Kubernetes API server の Service proxy を接続方式として定義する。runner はこの情報から kubectl get --raw /api/v1/namespaces/<namespace>/services/<service>:<port>/proxy/ 相当の操作を構築し、初期状態と復旧状態で同一の代表操作を実行する。
runner は検証用 kubeconfig を子processへ渡し、QA ServiceAccountには代表操作に必要な最小権限のみを付与する。操作結果として exit code、stdout、stderr、開始・終了時刻、および timeout を evidence に記録する。MVPでは exit code 0 を代表操作成功と判定する。

**Rationale**: Developer は「何をもってアプリケーション利用可能とするか」を所有し、Platform QA は「その確認を対象Platform上でどう実行するか」を所有する。これにより、Developer contractをnamespace、Service名、kubectl、kubeconfigなどのPlatform内部知識から分離できる。

Kubernetes API server の Service proxy は、hostからClusterIPへ直接到達するための追加network configurationを必要とせず、既存のKubernetes API、kubectl、QA credentialで代表操作を実行できる。NodePort、host port mapping、長時間動作するport-forward process、probe Podなどを追加しないため、MVPの検証経路を小さく保てる。

**Alternatives considered**:

- Developer contract に完全な kubectl argv を保持する: Platform固有のresource名とアクセス方式をDeveloper責務へ漏らすため不採用。
- NodePort + kind extraPortMappings: cluster manifestとhost側port設定が追加されるため不採用。
- kubectl port-forward: 長時間process、local port競合、再接続管理が追加されるため不採用。
- probe Pod / kubectl exec: cluster mutationまたは実行単位への直接操作を増やすため不採用。
- shell command string: shell expansionとquotingにより再現性と安全性が低下するため不採用。

**Sources**:

- https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster-services/
- https://kubernetes.io/docs/reference/kubernetes-api/service-resources/service-v1/#get-connect-proxy-path

## 8. Timing and verdict state machine

**Decision**: `PRECHECK → SELECT_INSTANCE → INJECT_LOSS → AWAIT_SELECTED_UID_ABSENT → OBSERVE_RECOVERY → CLASSIFY` の状態機械を採用する。wall-clock timestamp は evidence 用、120秒の比較には monotonic clock を使う。

**Rationale**: 状態ごとの許可操作と観測を限定でき、delete request acceptance と quality timer を分離できる。各 recovery observation に count snapshot と代表操作結果を束ね、`elapsed <= 120 seconds` の境界を一箇所で評価する。

**Alternatives considered**:

- `Deployment.progressDeadlineSeconds`: rollout progress の condition であり、Pod delete 後の代表操作成功や本仕様の起点を表さない。
- `kubectl wait` だけ: object condition の待機には使えるが、UID 喪失起点、代表操作 retry、三値分類を一体で表せない。

**Sources**:

- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands

## 9. Additional-failure attribution

**Decision**: additional failure の attribution は `NONE` / `PLATFORM` / `EXTERNAL` / `UNKNOWN` の閉じた列挙とし、下表の機械判定可能なpredicateで決定する。

actorは、専用QA ServiceAccount、Kubernetes system actor、Developer recovery interventionの判定分岐をfixtureで再現する`DEVELOPER_TEST` actor、それ以外の`OTHER`の4区分とする。`OTHER`をDeveloperと推定してはならない。`RECOVERY_INTERVENTION`の有効な`FAIL`は、明示的に識別できる`DEVELOPER_TEST` fixtureだけで検証する。通常の検証実行で発生した`OTHER` mutationは独立外乱として`EXTERNAL`の`INVALID`にする。

`RECOVERY_INTERVENTION`はAdditionalFailure.attributionの値ではなく、Developer介入を表すverdict predicateである。AdditionalFailure.attributionの閉じた列挙は`NONE` / `PLATFORM` / `EXTERNAL` / `UNKNOWN`のまま維持する。

**Rationale**: Kubernetes audit eventはwho / when / verb / resourceを記録できるが、そのactorがDeveloperであることや、操作目的が復旧であることまでは一般に証明しない。未知actorのmutationをDeveloper interventionと推定すると、Platformから独立した外乱を有効な品質失敗へ誤分類する可能性がある。

本FeatureではDeveloper interventionの判定ロジック自体を、固定identityを持つaudit fixtureで再現可能に検証する。実際のDeveloper username一覧は管理しない。通常実行の未知actor mutationは`EXTERNAL`として品質評価から除外する。

Platform起因の判定でもactor名やEvent文言から一般的な因果関係を推測せず、UID、verb、resource、generation、Node condition、API到達性が完全一致する狭いpredicateだけを採用する。完全一致しない場合は`UNKNOWN`とする。

**Actor predicates**:

- `QA`: `user.username == qaActorUsername` の完全一致。
- `DEVELOPER_TEST`: fixture eventの`user.username == system:serviceaccount:self-healing:developer-intervention-test`の完全一致。通常のcluster manifests、RBAC、verification profileにはこのidentityを追加しない。
- `SYSTEM`: `system:kube-controller-manager`、`system:kube-scheduler`、または `user.username == system:node:<observed-node-name>` かつ `user.groups` に `system:nodes` を含むもの。node nameはprecheck snapshotから取得し、profileへ重複設定しない。
- `OTHER`: 上記以外。`system:` prefixだけではSYSTEMとして扱わない。

audit eventは`stage=ResponseComplete`を使い、`auditID`で重複排除する。成功したmutationとして扱うのは`responseStatus.code`が200〜299の場合だけとする。Pod mutationとDeployment patchはUIDとrequest bodyを照合できる`RequestResponse` levelで記録する。

**Attribution Predicate Table**:

| Rule | Exact predicate | Classification | Verdict effect |
|---:|---|---|---|
| 0 | `QA`、verb=`delete`、resource=`pods`、object UID=選択UID、成功response、attempt中の該当requestが1件だけ | allowed injection（分類入力から除外） | 継続 |
| 1 | `DEVELOPER_TEST`が対象Podのcreate/delete/patch、対象Deploymentの`scale` update/patch、または`.spec.template.metadata.annotations["kubectl.kubernetes.io/restartedAt"]`を変更するpatchを成功させる | `RECOVERY_INTERVENTION` | 有効な`FAIL`、`developerRecoveryInterventionObserved=true` |
| 2 | `OTHER`による対象workload mutation、Rule 1の同一requestで説明されないbaseline後のDeployment generation変更、Node `Ready!=True`、Kubernetes API観測不能のいずれか | `EXTERNAL` | `INVALID` |
| 3 | baselineの非選択active UIDが`ManagedPodSet`から消失し、同じUIDに対する`SYSTEM`の成功したPod deleteが1件あり、Rule 1/2 signalがない | `PLATFORM` | 有効な`FAIL` |
| 4 | 追加障害signalがなく、Rule 0以外の非system mutationがなく、baseline generationとNode状態が維持され、API観測が継続している | `NONE` | 通常の復旧条件で判定 |
| 5 | 必須field欠落、Rule 1〜4の複数category一致、UIDまたは時間窓の不一致、その他いずれにも完全一致しない追加障害signal | `UNKNOWN` | `INVALID` |

classifierは最初にRule 0を除外し、残るsignalをすべて収集する。Rule 1〜4のcause categoryが1つだけ完全一致する場合に限って分類し、複数categoryへの一致はRule 5の`UNKNOWN`とする。最初に一致したruleを採用してはならない。

predicateはpure classifierとして実装し、fixture-based table testで各分岐を固定する。`RECOVERY_INTERVENTION`の`FAIL` fixtureは固定`DEVELOPER_TEST` usernameを使うが、専用ServiceAccountやRBACをkind clusterへ作成しない。Platform capabilityの主要E2E経路では、正常初期状態、単一Pod delete、選択UID喪失、標準reconciliation、120秒以内のcount/operation成立、PASS記録をkind上で検証する。

QA credentialは検証window開始前にadmin contextで発行し、専用kubeconfigとしてartifact directoryに保存する。runnerの全Kubernetes requestと代表操作の子processはそのkubeconfigを使う。kindのaudit file backendはcontrol-plane directoryをhostの`artifacts/self-healing/audit/`へmountし、runnerはhost側のJSON Linesをread-onlyでattempt windowに切り出す。Developerの状態閲覧は収集・判定せず、品質判定に使うactor evidenceはmutationに限定する。

**Alternatives considered**:

- `OTHER`をすべてDeveloper interventionとみなす: actorの役割や操作目的をaudit evidenceだけから証明できず、独立外乱を`FAIL`と誤分類するため不採用。
- すべての追加障害を`FAIL`: Platformから独立した外乱を品質評価へ混入させるため不採用。
- すべてを`INVALID`: Platformまたはその復旧動作に起因する失敗を隠すため不採用。
- 実際のDeveloper username allowlistを管理する: Platform QAへ組織固有identity管理の責務を追加するためMVPでは不採用。
- 外部audit service: kindのaudit file backendで必要なevidenceを取得できるため不採用。

**Sources**:

- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/
- https://kind.sigs.k8s.io/docs/user/auditing/

## 10. Reproducible cluster

**Decision**: kind v0.31.0 と `kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f` を pin する。

**Rationale**: kind は Kubernetes testing と CI を目的に利用でき、single-node MVP をローカルと CI で再現できる。tag と digest の固定により cluster version drift を防ぐ。

**Alternatives considered**:

- minikube: 有効な local cluster だが、今回の最小 CI workflow では kind が直接的。
- shared / managed cluster: 外乱と権限差が入りやすく、MVP の再現性と分離性を下げる。
- unpinned latest image: evidence の比較可能性を失うため不採用。

**Sources**:

- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://github.com/kubernetes-sigs/kind/releases/tag/v0.31.0
- https://kubernetes.io/docs/tasks/tools/

## Resolved Unknowns

Phase 0 で language、schema validator、cluster、recovery mechanism、instance identity、active-set mapping、contract format、representative-operation reachability、runner boundary、evidence format、verdict attribution を決定した。未解決事項は残っていない。
