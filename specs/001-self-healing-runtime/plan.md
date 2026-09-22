# Implementation Plan: Self-Healing Runtime

**Branch**: `001-self-healing` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-self-healing-runtime/spec.md`

## Summary

Kubernetes の標準 `Deployment` / `ReplicaSet` reconciliation を採用し、単一 Pod 喪失後に期待実行数へ戻す。独自の復旧 Controller は実装しない。reliable-dev-platform 固有の実装は、Developer が維持するアプリケーション契約を Platform QA が自動利用し、選択した Pod UID の喪失を起点に120秒を計測して、期待実行数と代表的な利用操作の同時成立を確認する検証 runner とする。runner は `PASS` / `FAIL` / `INVALID`、判定理由、FR-006 の観測結果を単一の `result.json` に保存し、raw Kubernetes object と audit event は参照証跡として保持する。

## Technical Context

**Language/Version**: Go 1.26.8、Kubernetes YAML `apps/v1` / `v1`

**Primary Dependencies**: `github.com/santhosh-tekuri/jsonschema/v6 v6.0.3`（Draft 2020-12 validation）、Kubernetes 1.35、`kubectl` 1.35、kind 0.31.0、Kubernetes `Deployment` / `ReplicaSet` / `Service` / Audit API

**Storage**: データベースなし。Developer 所有の JSON 契約、Platform QA 所有の JSON profile、試行ごとの `result.json`、raw snapshot、audit JSON Lines をファイルとして扱う

**Testing**: Go標準`testing` packageによる判定・時間境界のtable-driven unit testと、kind上で単一Pod喪失を注入するbuild-tagged E2E test

**Target Platform**: Linux 上のローカルまたは CI の単一ノード kind cluster

**Project Type**: Kubernetes manifests + Platform QA CLI / E2E harness

**Performance Goals**: 選択した Pod UID が稼働中集合から外れたことを最初に観測してから120秒以内に、期待実行数の一致と代表的な利用操作の成功を同じ観測サイクルで確認する

**Constraints**: Developer の復旧介入0件、検証ごとの Developer 入力0件、runner による復旧促進操作なし、総実行数の減少観測は不要、原因不明の追加障害は理由付き `INVALID`、120秒は MVP の Acceptance Threshold であり本番 SLO ではない

**Scale/Scope**: 単一アプリケーション、期待実行数3、単一 Pod 喪失、開発・試験環境のみ。Node、storage、network partition、継続的サービス可用性、rolling update は対象外

## Constitution Check

*GATE: Phase 0 開始前と Phase 1 完了後に確認する。*

| Principle | Pre-Research Gate | Post-Design Gate | Evidence |
|---|---|---|---|
| I. Requirement Before Mechanism | PASS | PASS | `spec.md` の Problem / Hypothesis / FR / SC を先に確定し、下記 Traceability で mechanism へ対応付けた |
| II. Minimal Complexity and Build vs. Adopt | PASS | PASS | 標準 `Deployment` / `ReplicaSet` と既存Go JSON Schema validatorを採用し、独自Controller、独自schema validator、client-goを排除。既存テスト・接続手段との差異を `research.md` に記録した |
| III. Reduce Developer Cognitive Load | PASS | PASS | Developerはアプリケーション契約だけを維持し、試行時の復旧入力、Pod操作、復旧判断を行わない。Platform QAは実Developer username一覧を管理しない |
| IV. Observable and Automated Quality | PASS | PASS | CLI に復旧入力を持たせず、許可 mutation、UID 喪失、120秒、三値判定、理由・FR-006観測値を自動記録する。状態閲覧の不在は品質条件にしない |
| V. Human-Understood AI Assistance | PASS | PASS | `research.md`、`data-model.md`、contracts、`quickstart.md` に機構、判断、検証方法を記録する |
| Application Scope | PASS | PASS | Feature 固有の技術選定と検証手順を constitution ではなく本計画配下に置く |

Gate violation はない。

## Design Decisions

### Recovery boundary

- `Deployment.spec.replicas` と managed `ReplicaSet` の標準 reconciliation が復旧を担う。
- Platform QA runner は専用 ServiceAccount を使い、行う mutation は選択した Pod 1個への graceful delete のみとする。
- runner は replacement の作成、scale、rollout restart、再削除など、復旧を促す操作を行わない。
- kind API server の audit log で検証期間中の mutating request と actor を記録する。actor は専用QA ServiceAccount、固定した標準control-plane/node identity、fixture専用`DEVELOPER_TEST`、それ以外の`OTHER`の4区分とする。`DEVELOPER_TEST`は固定usernameを持つaudit fixtureだけで使い、通常のcluster manifests、RBAC、profileには追加しない。QA actor に許可する mutation は対象 Pod への1回の graceful delete だけとする。audit判定は`ResponseComplete` stageをaudit IDで重複排除し、成功したrequestだけを使用する。
- 検証 window の開始前に admin context で専用 ServiceAccount の短期 credential と QA kubeconfig を生成し、runner は以後その kubeconfig だけを使う。kind は audit directory を host の `artifacts/self-healing/audit/` へ mount し、runner は host path の JSON Lines を read-only で収集する。

### Responsibility boundary

- Developer は `application-contract.json` に期待実行数と代表的な利用操作を定義・維持する。
- Platform QA は `verification-profile.json` に対象 cluster workload と検証上の観測設定を保持する。
- runner は両ファイルの digest を試行 evidence に保存し、初期確認と復旧判定で同一契約を利用する。
- `attempt` / `run` は Developer から復旧判断や復旧指示を受け取る option、prompt、callback を持たない。試行中の Developer 入力件数は構造上0件であり、runner の command log と audit log で runner 自身の復旧促進操作がないことを確認する。Developer による単なる状態閲覧は判定対象にしない。

### Observation and timing

- 対象 Deployment が所有する Pod API object の UID 全体を `ManagedPodSet` とする。喪失対象 UID がこの集合から存在しなくなった最初の観測を loss observation とし、`deletionTimestamp` の付与だけでは喪失成立としない。
- `ManagedPodSet` のうち `deletionTimestamp` がなく `Ready=True` の Pod UID 集合を `ActivePodSet` とし、現在実行数はこの件数へ写像する。Pod phase や Deployment の aggregate condition だけでは判定しない。
- 喪失対象は Pod name ではなく UID で固定する。
- delete request の受理時刻は evidence に残すが計測起点にしない。選択 UID が集合から外れた最初の観測を単調時計の起点とする。
- 各 recovery cycle では代表的な利用操作を実行し、成功終了の直後に `ActivePodSet` を取得する。その count snapshot の時刻を observation 時刻とし、直前の操作成功とその時点の期待実行数一致を1つの recovery observation に束ねる。observation 時刻が deadline 以前で両方を満たす最初の cycle を復旧完了とする。

### Verdict and evidence

- `INVALID` 判定を先に行い、初期条件不足、喪失未確認、外乱・設定変更・対象外事象、原因不明の追加障害を品質集計から除外する。
- 許可済みinjectionをaudit入力から除外した後、追加障害を`research.md`のAttribution Predicate Tableで評価する。全signalを収集し、1つのcause categoryへ完全一致する場合だけ分類する。複数categoryへの一致、必須field欠落、表にないsignalは`UNKNOWN`として`INVALID`にする。
- `RECOVERY_INTERVENTION`の有効な`FAIL`は、固定`DEVELOPER_TEST` identityを持つfixtureで判定ロジックを検証する。通常実行の`OTHER` mutationをDeveloperと推定せず、設定変更または外乱として`EXTERNAL`の`INVALID`にする。実際のDeveloper username一覧は保持しない。
- `PLATFORM` は、外部 signal がなく、system actor の対象外 Pod delete audit event が追加喪失 UID と完全一致する狭い predicateだけで確定する。それ以外は推測せず `UNKNOWN` とする。
- 追加障害がない有効な試行は、Developer 介入がなく120秒以内に復旧条件を満たす場合だけ `PASS` とする。
- `INVALID` は理由と evidence を保持してその attempt を終了する。runner はscale、restart、Pod作成などによる環境修復を行わない。初期条件が外部で回復した後、同じ run ID と新しい attempt ID で明示的に再実行する。外部 CI timeout / cancellation は試行 verdict に変換しない。

## Requirement Traceability

| Requirement | Technical Mechanism | Verification | Evidence |
|---|---|---|---|
| FR-001 | Application contract、Deployment selector、事前状態 observer | 期待数一致と代表操作成功を injection 前に確認 | initial observation、active Pod UIDs、operation result |
| FR-002 | Kubernetes Deployment / ReplicaSet reconciliation | 単一 Pod delete 後に正確な期待数へ戻ることを観測 | recovery observations、final active UIDs |
| FR-003 | 復旧入力を持たないCLI、専用QA ServiceAccount、許可mutation boundary、Kubernetes audit log | 通常E2EでDeveloper復旧入力0件とQA mutationが対象Pod delete 1回だけであることを確認し、介入FAIL分岐は`DEVELOPER_TEST` fixtureで検証 | result.jsonのinput count / intervention flag、audit evidence、classifier fixture |
| FR-004 | Pod UID の API object set からの first-absent observation + monotonic deadline | `elapsed <= 120s`、初回操作失敗後の retry、count dip 不要をテスト | requestAcceptedAt、firstAbsentObservedAt、deadlineAt、samples |
| FR-005 | 操作成功直後の count snapshot を同一 recovery observation に格納 | observation 時刻で両条件が成立した場合だけ完了 | completed observation、completedAt |
| FR-006 | FR-006観測値を含む単一 JSON result と raw/audit参照 | Go用既存JSON Schema validatorによる必須field検証と観測値の整合unit test | result.json、raw snapshots、audit.ndjson |
| FR-007 | 全signal評価、単一category一致、conflict時`UNKNOWN` fallbackを持つdeterministic classifier | `DEVELOPER_TEST`、`OTHER`、`SYSTEM`を含む全判定分岐をfixture-based unit testし、主要PASS経路をkind E2Eで検証 | verdict、qualityEvaluationIncluded、reasons、rerunRequired、attributionPredicate |
| FR-008 | version-pinned kind、固定 contract/profile、単一 CLI entrypoint | 同じ入力 digest でattemptを明示的に繰り返し実行 | run / attempt IDs、input digests、tool versions |
| FR-009 | Developer contract と QA profile の分離 | 各試行で同じ contract を自動読込 | applicationContractDigest、入力 log |

### Success Criteria Traceability

| Success Criterion | Requirement | Verification | Evidence |
|---|---|---|---|
| SC-001 | FR-002, FR-004, FR-005 | kind E2EでUID first-absentから120秒以内のcount/operation同時成立を確認 | firstAbsentObservedAt、completedAt、elapsedMilliseconds、completed recovery observation |
| SC-002 | FR-003, FR-006 | 復旧入力のないCLIと許可mutation境界を通常E2Eで検査し、介入検出は固定`DEVELOPER_TEST` fixtureで検査 | developerRecoveryInputCount=0、developerRecoveryInterventionObserved、audit evidence、classifier fixture |
| SC-003 | FR-007 | fixtureで全predicate/verdict分岐、kind E2Eで主要PASS/期限FAIL経路を検査 | verdict、reasons、qualityEvaluationIncluded、attributionPredicate |
| SC-004 | FR-008 | 同一digestで新しいattempt IDを使って再実行 | runId、attemptId、input digests、toolVersions |
| SC-005 | FR-009 | 各attemptが同じcontractを自動読込し、追加promptを持たないことを検査 | applicationContractDigest、developerRecoveryInputCount=0 |

## Project Structure

### Documentation (this feature)

```text
specs/001-self-healing-runtime/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── application-contract.schema.json
│   ├── verification-profile.schema.json
│   └── trial-result.schema.json
└── tasks.md                         # generated by $speckit-tasks
```

### Source Code (repository root)

```text
go.mod
go.sum
cmd/
└── self-healing/
    └── main.go
platform/
└── kubernetes/
    └── self-healing/
        ├── kind.yaml
        ├── audit-policy.yaml
        ├── namespace.yaml
        ├── rbac.yaml
        ├── deployment.yaml
        └── service.yaml
internal/
└── selfhealing/
    ├── bootstrap.go
    ├── contract.go
    ├── observer.go
    ├── classifier.go
    ├── evidence.go
    ├── runner.go
    ├── contract_test.go
    ├── classifier_test.go
    ├── timing_test.go
    └── testdata/
config/
└── self-healing/
    ├── application-contract.json
    └── verification-profile.json
tests/
└── e2e/
    └── self_healing_test.go
artifacts/
└── self-healing/                    # generated; gitignored
```

**Structure Decision**: 単一のGo command、単一のinternal package、Kubernetes manifestsを採用する。外部web service、database、custom controller、CRD、独自JSON Schema validatorは作らない。判定ロジックをcluster I/Oから分離し、三値分類と120秒境界をtable-driven fixtureで単体テストし、主要な復旧経路をkindでE2E検証できる構造にする。

## Complexity Tracking

Constitution violation はない。復旧は標準Deployment/ReplicaSet、schema検証は既存Go package、cluster I/Oはkubectl、操作到達は標準Service proxy、actor証跡はkindの標準audit file backendへ委ねる。Feature固有の実装は、FR-004〜FR-007に必要な時間計測、観測の束ね、conflict-safeな三値判定、単一`result.json`生成に限定する。`DEVELOPER_TEST`はJSON fixtureだけで表現し、ServiceAccount、RBAC、profile fieldを追加しない。client-go、独自controller、独自schema validator、外部service、database、CRD、fault-injection platformは追加しない。
