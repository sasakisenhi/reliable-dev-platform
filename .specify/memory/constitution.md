# reliable-dev-platform Constitution

## Core Principles

### I. Requirement Before Mechanism

Platform の振る舞いを追加または変更する Feature は、技術を選ぶ前に Problem、反証可能な Hypothesis、実装手段から独立した Requirement を定義しなければならない（MUST）。
採用する仕組みは、それが満たす Requirement または明示的な Learning Objective へ対応付けなければならない（MUST）。
Learning Objective には、説明または実証できる完了条件を定めなければいけない（MUST）。
特定の機能やツールを使うことだけを採用理由にしてはならない（MUST NOT）。

Rationale: 問題と要求から技術を選ぶことで、Platform の価値と学習成果を検証可能にする。

### II. Minimal Complexity

MVP は、現在の Hypothesis と Requirement を検証するために必要な最小構成としなければならない（MUST）。
ツール、抽象化、サービス、アーキテクチャ層を追加する場合は、対応する Requirement または Learning Objective と、より単純な選択肢では不十分な理由の両方を示さなければならない（MUST）。
将来必要になる可能性だけを理由に、複雑性を追加してはならない（MUST NOT）。

Rationale: 最小構成は因果関係を明確にし、変更・運用・学習の負担を抑える。

### III. Reduce Developer Cognitive Load

設計では、Developer に残る操作、判断、管理設定、Platform 内部知識への影響を評価する。
Platform の責務とした環境管理の操作や判断を、Developer の通常手順へ戻してはならない（MUST NOT）。
通常利用および対象とする復旧で、Developer に Platform 内部の直接操作を要求してはならない（MUST NOT）。
責務境界と Developer に残す負担の具体的な条件は、対象 Feature で定義しなければならない（MUST）。

Rationale: Platform は基盤の複雑性を内部で引き受け、Developer がアプリケーション開発へ集中できる状態を作る。

### IV. Observable and Automated Quality

Platform が主張する品質は、観測可能な合否条件を持ち、再現可能に検証されなければならない（MUST）。
「安定している」「安全である」などの表現だけを合否条件にしてはならない（MUST NOT）。
技術的に自動化可能な主要品質の検証を、手作業だけに依存させてはならない（MUST NOT）。
障害、不健全状態、または更新時の品質を主張する場合は、そのシナリオを検証対象に含めなければならない（MUST）。
具体的な指標、境界、手順は対象 Feature の成果物で定義する。

Rationale: 観測可能で繰り返せる検証によって、品質を客観的に比較し、回帰を検出できる。

### V. Human-Understood AI Assistance

AI Agent は分析、設計、実装、検証に利用してよい（MAY）。
人間の Maintainer は、主要な設計判断、Platform の責務、品質条件、利用する Kubernetes の仕組みと Requirement の関係を説明できなければならない（MUST）。
根拠または検証方法を人間が追跡できない AI 生成物を採用してはならない
（MUST NOT）。

Rationale: AI の実行速度を活かしながら、Platform を理解し変更できる状態を人間側に保持する。

## Application Scope

本憲章は、すべての Feature に共通する長期的な価値判断だけを定める。
Feature 固有の Requirement、Acceptance Criteria、技術選定、検証手順、および Product Context の背景説明はここへ複製してはならない。（MUST NOT）
承認済みの Requirement と Acceptance Criteria を変更しないリファクタリング、文書修正、および既存仕様への適合を回復する不具合修正は、新しい Problem または Hypothesis を必要としない。

## Sources of Detail

- `doc/product-context.md`: 問題領域、全体仮説、Personas、Scope
- 各 `spec.md`: Feature の目的、Requirement、Acceptance Criteria
- 各 `plan.md`: 技術選定、設計判断、品質の検証方針
- 各 `tasks.md`: 実装・検証作業と依存関係

## Governance

本憲章は、Core Principles に関して他のプロジェクト文書より優先する。
Feature のレビューでは、対象に関係する原則だけを確認し、該当する MUST または MUST NOT に違反する変更を受け入れてはならない（MUST NOT）。
Maintainer は default branch の品質に最終的な責任を持つ人間を指し、単独所有の場合は Project Owner が担う。

憲章の改定には、変更理由、影響、必要な移行方針、Maintainer の承認を必要とする。
Version は Semantic Versioning に従い、原則の削除・再定義または義務の弱化を MAJOR、原則の追加、または義務・ガイダンスの実質的な拡張を MINOR、意味を変えない明確化を PATCH とする。改定時は Version と Last Amended を更新する。

**Version**: 2.0.0 | **Ratified**: 2026-09-17 | **Last Amended**: 2026-09-17
