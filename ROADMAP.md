# Reliable Development Platform Roadmap

## R1 — Self-Healing Runtime
Status: In Progress

Intent:
単一実行インスタンス喪失後、Developerによる復旧操作を必要とせず、
期待実行数とアプリケーション利用可能性を回復する。

Scope:
- single execution-instance loss
- automatic recovery
- 120-second acceptance threshold
- representative application operation
- minimal feature-specific E2E

Deferred to R4:
- reusable Platform E2E framework
- generic PASS / FAIL / INVALID model
- generic evidence contracts
- audit-based actor attribution
- additional-failure attribution

## R2 — Healthy Routing
Status: Planned

Intent:
利用可能な実行インスタンスだけをアプリケーション利用経路の対象にする。

Scope:
- health-aware availability
- unhealthy instance exclusion

Depends on:
- R1

## R3 — Safe Rolling Update

Status: Planned

Intent:
アプリケーションの更新中も利用可能性を維持しながら、
現在のバージョンから新しいバージョンへ安全に移行できるようにする。

Scope:

* availability-aware application update
* controlled instance replacement
* update-time availability verification

Depends on:

* R1 — Self-Healing Runtime
* R2 — Healthy Routing

## R4 — Platform E2E
Status: Planned

Intent:
Platform capability の受け入れ条件を、再利用可能な形で自動実行し、
結果と必要な証拠を機械的に評価できるようにする。

Scope:
- reusable Platform E2E framework
- generic PASS / FAIL / INVALID model
- generic evidence contracts
- audit-based actor attribution
- additional-failure attribution

Depends on:
- R1 — Self-Healing Runtime
