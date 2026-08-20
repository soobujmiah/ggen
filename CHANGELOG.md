# Changelog

## 2026-08-20 — On-device persistence verified; clean-install diagnostics

- Device export (2026-08-20 09:01:17Z) confirmed the storage-init fix on the Redmi Turbo 4 Pro: `storage_init` logged info "File-backed storage initialized" at `/data/user/0/com.example.ggen/app_flutter` (the path also confirms the `com.example.ggen` applicationId on-device). Saves persist through the file store with idempotent digests; the canvas-first switch alternated across six toggles; profiles, reset, immersive and project_new/save ran with no errors.
- `_restoreLastProject` now logs an info `project_restore` event when no prior project is stored, so future exports distinguish a clean install from a restore failure (the 09:01 export had no restore event precisely because prefs were empty after a clean install).

## 2026-08-20 — Fix file-storage init crash on device

- Device diagnostics (Redmi Turbo 4 Pro, 2026-08-20 08:06:57Z) exposed `LateInitializationError: Field '_studio' has already been initialized` in `storage_init`: the shell's `_studio` was `late final` but the storage-init path reassigns it when swapping onto the file-backed store. On-device the plugin resolves and the swap runs (throwing); in CI it never ran because `path_provider` throws `MissingPluginException` before the assignment.
- Fixed by making `_studio` reassignable; added a regression widget test with a fake `PathProviderPlatform` that exercises the swap and asserts a real `.ggen` file is written on Save, plus an unavailable-storage fallback test.
- The affected device build ran entirely in-memory; a fresh APK is required to re-validate persistence on-device.

## 2026-08-20 — Canvas-first switch fix from device diagnostics

- Device diagnostics (Redmi Turbo 4 Pro, 2026-08-20) showed six consecutive `canvas_first` "disabled" events: the settings-sheet switch used the sheet-open snapshot as its value, so taps never reflected visually. The switch now owns its state (`_CanvasFirstSwitch`) and a widget regression test toggles it off and on.
- Recorded the device evidence and the defect in `docs/phases/phase-2-status.md`; persistence flows remain to be exercised on-device with a fresh APK from current `main`.

## 2026-08-20 — Threat model and plugin trust model

- Added `docs/security/threat-model.md`: assets, trust boundaries, prioritized STRIDE-lite threats (malicious `.ggen` files, journal replay divergence, credential leakage, protected-asset boundary, traversal via storage keys, plugin abuse, diagnostics leakage) with current mitigations and residual risks.
- Added ADR-0005 (plugin trust model, draft): capability-scoped, versioned, validated, tiered (trusted/verified/sandboxed) plugins with no silent execution and protected-asset immutability; no plugin runtime exists yet — this is the contract for the future loader.
- Closed the Phase-0 open item "create threat model and plugin trust model ADR".
- Added adaptive layout widget tests: compact phone (<700), small tablet (700–899), wide (≥900) with dockable inspector, and tiny/zero-size viewport robustness.

## 2026-08-20 — File-backed storage (ADR-0004)

- Accepted ADR-0004: app-private project store with deferred SAF export.
- Added `FileProjectStore`: atomic (temp+rename) per-project `.ggen` writes of the canonical `ggen.project` JSON in the app documents directory; stale-revision and non-advancing-revision rejection; SHA-256 receipts; durable across instances.
- Added `FileRecoveryJournal`: line-oriented JSON log per project under a journal subdirectory, bounded by the journal policy, with durable payload association (`PayloadJournal`) so replay can reconstruct the latest project state; replay markers remain session-scoped.
- The shell resolves the documents directory via `path_provider` and swaps onto the file-backed adapters; the in-memory adapters remain the default and a fully functional fallback (tests, missing plugin).
- `path_provider 2.1.6` added with provenance receipts for the full plugin family (11 records, BSD-3-Clause, review still pending per repo policy).
- SAF/MediaStore import/export is the next storage milestone and is explicitly out of scope here.
- Added file store, file journal, cross-restart controller durability tests.

## 2026-08-20 — Android app identity is ggen

- Added `scripts/prepare_android_identity.py`: normalizes the CI-generated Android wrapper so the device-facing app identity is exactly "ggen" — launcher label `ggen` and process name (`applicationId`) `com.example.ggen` — instead of the `flutter create` default `ggen_app`/`com.example.ggen_app`.
- The manual APK workflow applies the script after generating the wrapper; the artifact is now `ggen-debug-apk`.
- Idempotent and fail-loud: CI refuses to ship an APK whose identity patterns are missing.
- The tagline "AI Creative & Document Studio" is unchanged; the Dart package identifier (`ggen_app`) and namespace stay internal and are not user-visible. `com.example` remains provisional until a real application domain is selected.
- The committed wrapper policy (`generated_android_wrapper_must_be_committed`) remains an open toolchain decision; the wrapper is still generated per manual build.

## 2026-08-20 — Persistence completion: restore and journaling

- Undo and redo now append recovery-journal records: forward deltas for redo, state markers (base == target) for undo, so replay can reconstruct every reachable revision.
- The shell restores the most recently saved project on startup via a persisted last-project storage key; stale or malformed keys fail closed with a diagnostics event.
- Save persists the last-project key alongside the existing workspace preferences.
- Added preferences round-trip tests, controller undo/redo journaling tests and fail-closed startup widget tests.

## 2026-08-20 — Persistence backbone (in-memory)

- Implemented the core storage contracts in the app layer: `MemoryProjectStore` (atomic stage/commit/cancel transactions, stale-revision rejection, SHA-256 content receipts) and `MemoryRecoveryJournal` (bounded entry/byte budgets, ordered replay stream, replay markers, in-memory payload reconstruction).
- `StudioController.save()` now persists through a transactional store write and returns a receipt; checkpoint records are appended to the recovery journal at a provisional cadence; `restore()` reloads a committed project from the store.
- Shell Save action is now async and surfaces the receipt (revision, bytes, digest) or a store rejection.
- Added store, journal and controller persistence tests (transaction semantics, eviction bounds, replay, save/restore round trip, checkpoint cadence).
- `crypto 3.0.7` pinned in the app at the exact version already locked and receipted for this repository.
- Deferred: file-backed adapter (platform storage decision), undo/redo journaling, shell restore wiring.

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
