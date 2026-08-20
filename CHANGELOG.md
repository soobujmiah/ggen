# Changelog

## 2026-08-20 — App-core backbone

- Added `ggen_app` dependency on `ggen_core` and a widget-free app-layer `StudioController` (project lifecycle, tool sessions, bounded undo/redo, canonical envelope serialization) built on the core contracts.
- Wired the shell to the controller: functional New project and Save (canonical JSON) actions, an undo/redo history bar over the canvas, and live object count and revision in the status bar.
- Added controller unit tests (lifecycle, session commit/cancel, stale-session rejection, history bounds, canonical round trip) and shell widget tests for the wiring.
- File persistence remains deferred until a platform storage decision is accepted; the core storage contracts already exist and the controller keeps the canonical bytes for diagnostics and tests.

## 2026-08-19 — Deterministic project serialization contract

- Added canonical bounded JSON serialization for the current project envelope.
- Added strict JSON-safe extension validation, stable node-kind wire names, round-trip/canonical-order tests and fail-closed schema migration policy.
- Added malformed-schema, unknown-kind and resource-limit tests.

## 2026-08-19 — Public governance workflow verified

- Public governance run `32258583134` for commit `d03cf01c6f60e7fcc43543ac6e9adc0e18b89026` completed successfully; licensing/public-safety governance and the reusable core test were green.
- Earlier billing/spending-limit rejection is retained as historical account evidence and is not classified as a source-code failure.

## 2026-08-19 — Phase 1 persistence, jobs and recovery contracts

- Added project schema/version envelopes, path-free transactional storage interfaces and content-addressed store receipts.
- Added finite resource budgets, explicit job state transitions, monotonic progress and bounded failure codes.
- Added autosave policies and append/replay recovery journal interfaces without coupling the domain to a filesystem or worker.
- Local Dart 3.13.0 verification passed: formatting, fatal-info analysis and 17 unit tests.


## 2026-08-19 — Tool sessions and adaptive input contracts

- Added preview/commit/cancel tool sessions that create one reversible transaction and restore exact input on cancellation.
- Added adaptive touch, stylus, mouse and keyboard capability contracts, reported-axis validation and normalized input events without synthetic pressure or tilt.

## 2026-08-19 — Hybrid brain, Font Studio and 3D DCC scope

- Inspected the current Arena orchestration machine and recorded its capabilities/limits.
- Added machine-readable GitHub-centric hybrid development environment YAML and validator.
- Accepted ADR-0002: GitHub canonical memory/control, Arena orchestration brain, Codespaces/Actions builds, Redmi physical evidence, optional heavy workers.
- Added full premium font-creation and typography architecture.
- Added long-term full professional 3D DCC architecture and phased roadmap with native-engine boundary.
- Expanded master specification, module map and development phases without adding application implementation.

## 2026-08-19 — Phase 1 core contracts started

- Added platform-neutral `ggen_core` package with immutable minimal document model, validated IDs, bounded revision history and professional tool-quality contracts.
- Tool descriptors fail closed unless manual operation, mobile-friendly UI and every mandatory computer-quality gate are declared.
- Added six unit tests; exact Dart 3.13.0 formatting, analysis and tests passed in a disposable Arena toolchain.
- Added locked dependencies and GitHub core workflow; no Flutter UI or reference UI code was added.

## 2026-08-19 — Phase 0 foundation

- Recorded master specification and Android-first Flutter decision.
- Audited BG/RGEN capabilities and prohibited lessons.
- Added architecture, interfaces, import/privacy policy, testing strategy, integration boundaries, UI originality boundary, and roadmap.
- Added private immutable snapshot of all 30 current RGEN production assets from commit `250da99f...` with exact size/SHA-256 manifests.
- Added license/provenance risk register; unresolved assets remain blocked from public distribution.
- Added CI verification for protected bytes and Phase 0 documentation boundary.
- Added no application implementation.
