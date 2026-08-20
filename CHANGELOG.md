# Changelog

## 2026-08-20 — Keyboard zoom shortcuts and node resize handles

- **Keyboard zoom**: Ctrl+=/Ctrl++ zooms in, Ctrl+- zooms out, Ctrl+0 fits to screen. Uses a new `CanvasZoomController` command channel between the shell and the canvas (viewport state stays out of the project controller). Canvas zoom methods (`zoomIn()`, `zoomOut()`, `fitToScreen()`) are now public.
- **Node resize handles**: when a shape node is selected in the Select tool, 8 resize handles (4 corners + 4 edges) render as screen-space white/blue squares. Dragging a handle shows a live preview and commits through one undoable tool session via `controller.resizeNode()`. Minimum size enforced at 8 artboard units. Text nodes are excluded (no w/h geometry).
- `resizeHandleRects()` and `ResizeHandle` enum are public utilities for tests.
- Tests: controller (resize with undo, non-finite/non-positive rejection, nonexistent node, text node exclusion).
- Deferred: proportional resize (Shift), snap-to-grid resize, numeric resize input, zoom presets (50%, 100%, 200%).

## 2026-08-20 — Zoom controls, delete shortcut and canvas-geometry log suppression

- **Zoom controls overlay** (`studio_canvas.dart`): bottom-right material card with zoom-in (+25%), zoom-out (−20%), fit-to-screen buttons and a tappable zoom percentage label. Buttons disable at the viewport min/max scale limits.
- **Delete keyboard shortcut**: Delete and Backspace keys remove the selected node through an undoable tool session (`controller.deleteNode()`), logged as `key_delete`.
- **Canvas-geometry log suppression**: `recordCanvasGeometry` now accepts a `suppress` flag; the shell passes `_workspaceSettingsOpen` so the settings-sheet animation no longer generates diagnostic noise. `CanvasArea` gains a `suppressGeometryLog` parameter.
- Tests: zoom controls render with scale percentage, zoom-in increases scale, zoom-out decreases scale.
- Deferred: keyboard zoom shortcuts (Ctrl+/Ctrl-), numeric zoom input, zoom presets (50%, 100%, 200%).

## 2026-08-20 — Layer list panel with visibility, lock, delete and reorder

- Added `LayerList` and `LayerPanel` widgets (`lib/src/layers/layer_list.dart`): displays all nodes in reverse z-order with kind icon, visibility toggle (eye), lock toggle (lock), delete button, drag-to-reorder handle, selection highlight and z-index badge.
- Controller gains `toggleNodeVisibility()`, `toggleNodeLock()`, `reorderNodes()` and `deleteNode()` — all go through undoable tool sessions. Delete clears the selection when the deleted node was selected.
- Shell integration: layers toggle button (top-right, always visible outside immersive) opens a bottom sheet on compact phones and toggles a docked 260px panel on wide layouts. Selection taps sync with the controller so the canvas highlights the chosen node.
- Tests: controller (toggle visibility, toggle lock, reorder with undo, delete with selection clear, out-of-range rejection, nonexistent node rejection).
- Deferred: multi-select layers, layer groups, opacity slider, blend mode, rename inline, drag-and-drop from external sources.

## 2026-08-20 — Select tool: node selection, hit-testing and drag-to-move

- Implemented the Select tool on the canvas: selecting the Select tool (index 0) enables hit-testing on tap, with visual selection border (blue `#4E6BFF`) on the selected node.
- `StudioController` gains `selectedNodeId`, `selectNode()`, `deselectNode()` and `moveNode()`: select is transient workspace state (no history transaction); move is one undoable tool session that clamps the resulting position into the artboard bounds.
- `StudioCanvas` gains `selectMode`, `selectedNodeId` and `onNodeSelected` parameters. Hit-testing iterates nodes in reverse z-order (last drawn = topmost); shapes use their exact `x/y/w/h` rect, text frames use an approximate `x/y/width×height` rect from text length and font size.
- Node drag: when a selected node is dragged, the canvas tracks the cumulative artboard-space delta and renders a live preview offset; on release, `controller.moveNode()` commits one undoable transaction (only if the delta exceeds 1 artboard unit, so a tap doesn't create a spurious move).
- `hitTestNode()` is exposed as a public utility for tests and future consumers.
- `newProject` clears the selection.
- Tests: controller (select/deselect, move with clamping, move text nodes, undo/redo restores position, no-op rejection, finite-delta validation); canvas widget (selection border renders/absent, hitTestNode utility); integration with shell via diagnostics logging (`node_select`, `node_deselect`).
- Deferred: multi-select, resize handles, rotation, z-order change, snap-to-grid, arrow-key nudge, keyboard shortcuts for delete/duplicate, layer list integration.

## 2026-08-20 — Device evidence: Text tool and content persistence verified

- Redmi export (12:07:38Z, text-tool build): `node_add_text` ×2 (`fyug`, `dttd7`) confirmed the Text tool on-device; `project_save` at revision 1 / 432 bytes confirmed a project **containing content** persisted through the file store.
- Draw remains unexercised on-device (the run selected Draw then switched to Text without tapping the canvas); undo/redo shortcuts and restart-restore remain unexercised. Documented in `docs/phases/phase-2-status.md` with the remaining device checklist.
- Noted that `canvas_geometry` still logs during active settings-sheet drags (fast drags move >8px per frame, defeating the quantum); suppression while the sheet is open is a candidate tightening.

## 2026-08-20 — Text tool, volume-key and multi-touch undo/redo, canvas UX fixes

- Text tool implemented: selecting Text and tapping the canvas prompts for text and commits a text frame node through a core tool session (undoable, journaled); text renders on the artboard.
- Volume buttons now drive undo/redo while editing: volume-down undoes, volume-up redoes, and the event is consumed so the system volume does not change. The dialog now owns its text controller (disposing it in the caller crashed with "used after being disposed" during the exit animation — caught by a widget test).
- Two-finger tap = undo and three-finger tap = redo on the canvas, detected from raw pointer bursts (all fingers up within 300ms with movement under 20px); pan/zoom gestures are unaffected.
- History bar moved to the bottom-left of the canvas so it no longer covers the project-name chip; the chip now scrolls horizontally for long project names.
- Integration tests pin the exact device-reported flow (select Draw in the bottom bar, tap the canvas, expect a node): it passes locally, so the on-device miss was environment-specific and needs a fresh APK to re-validate.

## 2026-08-20 — Bound canvas-geometry diagnostics (device flood)

- Device export (2026-08-20 09:52Z) showed ~50 `canvas_geometry` entries in a few seconds while the settings sheet animated: the sheet resizes the canvas ~1px per frame and the per-pixel dedupe still logged each distinct size, flooding the bounded log and evicting meaningful events.
- `recordCanvasGeometry` now quantizes the dedupe key to 8px and applies a 500ms cooldown; the exact rounded size is logged when a log happens, so settled geometry evidence stays precise. A widget test feeds 60 one-pixel steps and asserts ≤8 entries.
- The same export confirmed the canvas shell on-device: canvas height now 471×828 (was 471×353), tool names logged, new project + save + immersive clean, no errors. `project_restore` and undo/redo remain to be exercised on-device (undo/redo buttons activate only after a Draw-tap creates history).

## 2026-08-20 — Compact-phone canvas shell prototype

- Original `StudioCanvas`: renders the first artboard with pinch-zoom, one-finger pan and draw-tap input, built on an immutable, widget-free `CanvasViewport` (fit, focal-anchored zoom, clamped scale 0.05–8, screen/artboard mapping). Double-tap zoom was removed before merge: a double-tap recognizer holds the gesture arena open ~300ms, delaying single-tap resolution and deadlocking widget tests; it is deferred until explicit zoom controls exist.
- The Draw tool is now functional: selecting Draw and tapping the canvas commits a shape node through a core tool session (`StudioController.addShapeNode`) — one undoable transaction, journaled, clamped into the artboard, with geometry in the node extensions (`x/y/w/h/color`).
- Undo/redo become exercisable on-device for the first time (history bar was previously always disabled); the status bar object count updates live.
- Tool rail and compact bottom navigation now track the selected tool (Select/Draw/Text; Settings stays on index 3).
- Adaptive input contract deliberately not yet declared: the core contract fails closed without a command palette and numeric inspector, which do not exist yet; declared in the deferred list.
- Tests: viewport math (fit, clamping, focal-anchored zoom, mapping round trip), controller draw tool (clamp, undo/redo, invalid args, sequence reset), canvas widget (render, draw-tap add, select-tap no-op, pinch zoom, pan without zoom).
- Deferred: real vector drawing, node selection/move/resize, layer list, stylus pressure, adaptive-input declaration.

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
