# Implementation Plan: Self-Healing Runtime

**Branch**: `001-self-healing-runtime` | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-self-healing-runtime/spec.md`

## Summary

Kubernetes 標準 reconciliation による単一 Pod 喪失からの復旧を、固定した kind fixture と feature-specific E2E script で検証する。技術 semantics と選定根拠は [research.md](./research.md)、process 内の型と predicate は [data-model.md](./data-model.md) を canonical source とする。

## Technical Context

**Language/Version**: Bash 5.x、Kubernetes manifest `apps/v1` / `v1`

**Primary Dependencies**: kind、Kubernetes / kubectl、agnhost。固定 version と選定根拠は [research.md §7](./research.md#7-reproducible-environment-and-version-pinning) を参照

**Storage**: database なし。試行中の観測値だけを process 内で保持し、結果は exit status と通常の診断情報で表す

**Testing**: `bash -n`、E2E script の `--self-test`、単一ノード kind 上の acceptance scenario

**Target Platform**: Linux 上の Docker 互換 runtime を利用するローカル環境または CI

**Project Type**: Kubernetes manifests + feature-specific E2E script

**Performance Goals**: SC-001 と FR-006 の120秒 acceptance threshold を [research.md §6](./research.md#6-loss-observation-and-recovery-deadline) の観測 semantics で検証する

**Constraints**: loss injection 後から `VerificationOutcome` 確定まで、復旧を促進する mutation を行わない。outcome 確定後の fixture cleanup は許可する

**Scale/Scope**: `spec.md` の Scope Boundaries に従う。実装対象は単一アプリケーション、単一 Pod 喪失、単一ノード kind の開発・試験環境に限定する

## Constitution Check

*GATE: Phase 0 開始前と Phase 1 完了後に確認する。*

| Principle | Pre-Research Gate | Post-Design Gate | Evidence |
|---|---|---|---|
| I. Requirement Before Mechanism | PASS | PASS | `spec.md` で Problem、Hypothesis、FR-001〜FR-007、SC-001〜SC-003を確定し、下記 Traceability で実装へ対応付けた |
| II. Minimal Complexity and Build vs. Adopt | PASS | PASS | [research.md](./research.md) で標準機能と既存 tool を評価し、独自 Controller と汎用 E2E framework を採用しない判断を記録した |
| III. Reduce Developer Cognitive Load | PASS | PASS | Developer に recovery input、判断、Platform 内部操作を要求しない control flow とした |
| IV. Observable and Automated Quality | PASS | PASS | 単一 command が loss、deadline、recovery completionを自動判定し、未成立条件を failure stage と診断へ写像する |
| V. Human-Understood AI Assistance | PASS | PASS | 技術判断、構成、data model、実行手順を各 canonical artifact から追跡できる |
| Application Scope | PASS | PASS | Feature 固有情報を本 feature directory に保持し、constitution へ複製しない |

Gate violation はない。

## Implementation Architecture

| Component | Responsibility |
|---|---|
| Kubernetes fixture | MVP の Deployment と Service を宣言する。Deployment の `.spec.replicas` と `.spec.selector` を E2E input の source of truth とする |
| Kubernetes controllers | [research.md §1](./research.md#1-recovery-mechanism-kubernetes-deployment-reconciliation) で選定した標準 reconciliation を実行する |
| E2E script | cluster lifecycle、fixture setup、precheck、loss injection、bounded observation、outcome、diagnostics、cleanup を順に制御する |
| Make target | `make test-self-healing` を acceptance scenario の primary entrypoint として E2E script を起動する。 |

Pod identity、`RunningInstanceSet`、loss injection、representative operation、timer と completion の正式な技術 semantics は [research.md §§2–6](./research.md) を参照する。plan ではそれらを再定義しない。

## E2E Control Flow

1. pinned environment を確認し、kind cluster と fixture を setup する。
2. 対象 Deployment から selector と expected count を取得し、canonical observation semantics で baseline を確認する。
3. loss target の name / UID を固定し、canonical loss injection を1回だけ実行する。
4. loss observation guard と recovery deadline の範囲で bounded observation を行う。
5. [data-model.md](./data-model.md) の predicate により outcome を確定する。
6. outcome と診断を出力し、`KEEP_CLUSTER=1` でなければ fixture を cleanup する。

`INJECT_LOSS` 後から outcome 確定までの code path は read-only observation と representative HTTP operation に限定する。scale、restart、replacement creation、追加 delete は実行しない。

## Diagnostics and Interface

- `make test-self-healing`: cluster setup から cleanup までの acceptance scenario を実行する。
- `tests/e2e/self-healing.sh --self-test`: completion predicate、120秒 inclusive boundary、各 failure stage の固定入力 test を実行する。
- success: exit code 0。選択 UID、loss observation、recovery elapsed time を表示する。
- failure: exit code 1。`SETUP`、`PRECHECK`、`LOSS_INJECTION`、`LOSS_OBSERVATION`、`RECOVERY_DEADLINE` の stage と未成立条件を表示する。
- failure diagnostics: Deployment、ReplicaSet、Pod、Event を read-only で取得する。

## Requirement Traceability

| Requirement | Implementation | Verification |
|---|---|---|
| FR-001 | Deployment-derived fixture input + precheck | baseline predicate |
| FR-002 | UID-based target selection and loss observation | selected UID transition |
| FR-003 | standard Deployment / ReplicaSet reconciliation | recovered count predicate |
| FR-004 | post-injection mutation-free control path | code path review + acceptance run |
| FR-005 | canonical loss observation timer | timer-origin self-test + E2E observation |
| FR-006 | bounded observation cycle | completion predicate + inclusive boundary self-test |
| FR-007 | single automated entrypoint and staged diagnostics | exit status + failure-stage self-tests |

### Success Criteria Traceability

| Success Criterion | Verification |
|---|---|
| SC-001 | kind E2E で canonical recovery completion を deadline 内に確認 |
| SC-002 | injection 後の mutation-free path だけで outcome へ到達することを確認 |
| SC-003 | positive E2E と全 failure-stage self-tests で exit status と診断を確認 |

## Project Structure

### Documentation (this feature)

```text
specs/001-self-healing-runtime/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md                         # generated by $speckit-tasks
```

### Source Code (repository root)

```text
Makefile
platform/
└── kubernetes/
    └── self-healing/
        ├── kind.yaml
        └── workload.yaml
tests/
└── e2e/
    └── self-healing.sh
```

**Structure Decision**: 2つの manifest と1つの Bash E2E script を追加する。script 内では control-flow stage を関数へ分ける。汎用 CLI package、database、CRD、custom Controller、JSON Schema、audit backend は作らない。

## Complexity Tracking

Constitution violation はない。R1 に含めない reusable E2E / evidence / attribution capability は [research.md §8](./research.md#8-contracts-and-evidence-scope) と `ROADMAP.md` R4 を参照する。
