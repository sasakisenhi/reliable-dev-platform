<!--
Sync Impact Report
- Version change: Unratified template -> 1.0.0
- Modified principles:
  - Template principle slot 1 -> I. Requirement Before Mechanism
  - Template principle slot 2 -> II. Minimal Complexity
  - Template principle slot 3 -> III. Developer Cognitive Load
  - Template principle slot 4 -> IV. Observable Quality
  - Template principle slot 5 -> V. Automated Platform QA
- Added principles:
  - VI. Learning Through Requirements
  - VII. AI-Assisted, Human-Understood
- Added sections:
  - Requirement and Design Standards
  - Development Workflow and Quality Gates
- Review adjustment:
  - Separated specification responsibilities from implementation plan responsibilities
- Removed sections: None
- Follow-up TODOs: None
-->

# reliable-dev-platform Constitution

## Core Principles

### I. Requirement Before Mechanism

各 Feature は、Kubernetes の機能、ツール、またはアーキテクチャを選択する前に、
解決する Problem、検証可能な Hypothesis、技術非依存の Requirement、観測可能な
Quality Condition を定義しなければならない（MUST）。採用する Technical Mechanism は、
それが満たす Requirement へ明示的に対応付けなければならない（MUST）。特定技術を
使うことだけを理由に Requirement を作る提案は採用してはならない（MUST NOT）。

Rationale: 問題と要求を技術選定より先に置くことで、Platform の価値を技術の導入数ではなく、
解消した利用者課題と検証済みの仮説で評価できる。

### II. Minimal Complexity

MVP は、現在の Hypothesis と Acceptance Criteria を検証できる最小の構成でなければならない
（MUST）。新しいツール、抽象化、サービス、またはアーキテクチャ層を追加する場合は、
それを必要とする Requirement または明示的な Learning Objective と、より単純な選択肢では
不十分な理由を記録しなければならない（MUST）。現在の検証に不要な将来対応は後続 Feature へ
延期しなければならない（MUST）。

Rationale: 小さな構成は、仮説から結果までの因果関係を明確にし、変更・運用・学習に伴う
コストを抑える。

### III. Developer Cognitive Load

各設計判断は、変更前後について Developer に必要な操作、判断、管理対象の設定、Platform の
内部知識を列挙し、Platform へ移す項目と Developer に残す項目の理由を記録しなければならない
（MUST）。環境の状態確認、復旧、健全性判定、更新確認のうち、Requirement が Platform の責務と
定めたものは、Developer の手順へ戻してはならない（MUST NOT）。各 Developer workflow の
Acceptance Criteria は、必要な入力、許容する操作・判断・管理設定、期待結果、復旧経路を
明示しなければならない（MUST）。通常利用および Requirement の対象とする復旧は、文書化された
インターフェースだけで完結し、Platform 内部コンポーネントの直接操作を Developer に要求しては
ならない（MUST NOT）。

Rationale: Platform の目的は、基盤内部の複雑性を利用者へ移すことではなく、環境管理の
認知負荷を引き受け、アプリケーション開発へ集中できる状態を作ることにある。

### IV. Observable Quality

Platform が提供すると主張する各品質特性は、前提条件、観測対象、期待結果、判定境界を持つ
Acceptance Criteria として定義しなければならない（MUST）。「安定している」「安全である」
「自動復旧する」などの表現だけで品質を定義したり、完了を判定したりしてはならない
（MUST NOT）。品質の達成は、再実行可能な手順と観測結果によって確認できなければならない
（MUST）。

Rationale: 観測可能な条件へ変換された品質だけが、変更前後で比較され、客観的な PASS/FAIL と
して評価できる。

### V. Automated Platform QA

各 Feature specification は、リリース可否に影響する品質特性を主要品質特性として列挙しなければ
ならない（MUST）。主要品質特性は、技術的に実行可能な限り、再現可能な自動テストで検証しなければ
ならない（MUST）。品質主張が障害、不健全状態、または更新時の振る舞いを含む場合、対応する
異常・変更シナリオをテスト対象に含めなければならない（MUST）。各テストは前提条件、刺激、
観測結果、PASS/FAIL 条件を明示し、失敗時にどの品質条件が満たされなかったかを特定できなければ
ならない（MUST）。自動化できない検証は、理由、再現可能な手動手順、保存する証拠、責任者、
再評価条件を記録しなければならない（MUST）。

Rationale: 正常系だけでなく障害と変更を繰り返し検証することで、Platform の品質を属人的な
確認から継続的な回帰検出へ移せる。

### VI. Learning Through Requirements

Kubernetes の概念・機能は、それを必要とする Requirement または明示的な Learning Objective が
定義された後に導入しなければならない（MUST）。導入時は、対象 Requirement、選択した仕組みの
期待動作、観測方法、制約を記録しなければならない（MUST）。学習自体を目的とする場合も、
何を説明または実証できれば学習完了とするかを検証可能な条件として定義しなければならない
（MUST）。

Rationale: 要求との関係から Kubernetes を学ぶことで、機能名の知識ではなく、設計判断に
使える理解を蓄積できる。

### VII. AI-Assisted, Human-Understood

AI Agent を分析、設計、実装、検証に利用してよい（MAY）。ただし、主要な設計判断、Developer と
Platform の責務、品質条件、利用する Kubernetes の仕組みは、人間がレビューできる文書に
記録しなければならない（MUST）。変更を完了とする前に、人間の Maintainer は、それらの判断と
Requirement との対応、仕組みの期待動作、既知の制約を説明できることをレビューで確認しなければ
ならない（MUST）。根拠や検証方法を追跡できない AI 生成物を採用してはならない（MUST NOT）。

Rationale: AI による実行速度を活かしながら、Platform の所有権、説明責任、変更能力を人間側に
保持する。

## Requirement and Design Standards

すべての Feature specification は、少なくとも次の情報を含まなければならない（MUST）。

- 対象利用者と、観測または仮定された Problem
- 期待する変化と反証条件を含む Hypothesis
- 実装手段から独立した Requirement
- 前提条件、観測対象、期待結果、判定境界を含む Acceptance Criteria
- Developer と Platform の責務境界
- リリース可否に影響する主要品質特性

すべての implementation plan は、少なくとも次の情報を含まなければならない（MUST）。

- Requirement および Quality Condition から Technical Mechanism への対応
- 変更前後で Developer に必要な操作・判断・管理設定・内部知識
- 追加する複雑性の必要性と、検討したより単純な選択肢
- 新たに利用する Kubernetes の概念・機能と、それが必要な理由
- 主要品質特性の検証方法および自動化方針

Requirement から Mechanism までの標準的な順序は、次のとおりとする（MUST）。

`Problem -> Hypothesis -> Requirement -> Quality Condition -> Technical Mechanism`

後続段階で前提の誤りが判明した場合は、先行成果物へ戻って修正しなければならない（MUST）。
Product Context は問題領域と仮説の背景を提供するが、個別 Feature の Requirement と Acceptance
Criteria を代替してはならない（MUST NOT）。

## Development Workflow and Quality Gates

各 Feature は、次の品質ゲートを順に満たさなければならない（MUST）。

1. Specification review で Problem、Hypothesis、Requirement、Acceptance Criteria を承認する。
2. Design review で Requirement-to-Mechanism の対応、責務境界、複雑性、学習対象を確認する。
3. 現在の Acceptance Criteria を満たす最小の Increment を実装する。
4. 該当する正常、障害、不健全状態、更新シナリオを実行し、判定結果を保存する。
5. Human review で設計判断と Kubernetes の仕組みを説明可能であることを確認する。
6. 検証結果に基づいて Hypothesis の支持・反証・未確定を記録し、次の Feature を決定する。

Acceptance Criteria を満たす証拠がない変更は完了としてはならない（MUST NOT）。品質ゲートで
発見した失敗を、要件の緩和だけで解消してはならない（MUST NOT）。要件を変更する場合は、
Problem または Hypothesis に照らした理由と影響を記録し、Specification review を再実施しなければ
ならない（MUST）。

## Governance

本憲章における Maintainer は、リポジトリの default branch に入る変更を最終承認する人間を指す。
単独所有のリポジトリでは Project Owner がこの役割を担う。本憲章は、プロジェクト内の設計・実装・
検証に関する他の慣行や文書と矛盾する場合に優先する（MUST）。すべての Feature specification、
implementation plan、task list、および変更レビューは、該当する原則への適合を確認しなければ
ならない（MUST）。原則からの一時的な逸脱には、対象原則、理由、影響範囲、緩和策、責任者、
見直し期限、終了条件を記録し、Maintainer の承認を得なければならない（MUST）。

憲章の改定提案は、変更理由、影響を受ける原則・成果物、既存成果物の移行方針を記載しなければ
ならない（MUST）。改定は Maintainer の承認、Sync Impact Report の作成、Version と Last Amended
の日付更新を経て発効する（MUST）。

Version は Semantic Versioning に従う（MUST）。原則の削除、または既存の統治要件を弱める
互換性のない再定義は MAJOR、新しい原則・節の追加または統治要件の実質的な拡張は MINOR、
意味を変えない明確化や誤記修正は PATCH とする。各レビューでは最新の憲章を使用し、例外が
反復する場合は設計または憲章自体の見直しを行わなければならない（MUST）。

**Version**: 1.0.0 | **Ratified**: 2026-09-17 | **Last Amended**: 2026-09-17
