# Phase 2 — Responsive workspace foundation status

**Status:** Active; GitHub-validated foundation with Redmi Turbo 4 Pro evidence in progress.

## Implemented

- pinned GitHub Codespaces Flutter workspace;
- original Flutter studio shell;
- compact-phone, tablet and wide responsive layout contracts;
- compact bottom navigation and wide navigation rail;
- immersive canvas mode with explicit restore control;
- draggable compact workspace Settings sheet;
- hideable wide inspector;
- left/right inspector docking on wide layouts;
- persisted inspector visibility, Canvas-first preference and dock side;
- functional Reset workspace action;
- bounded named workspace profile model and storage;
- profile manager UI for save, apply and delete;
- bounded redacted diagnostics export;
- Flutter framework and uncaught-error capture;
- viewport, canvas geometry, safe-area and keyboard-inset diagnostics;
- app-layer `StudioController` wired to `ggen_core` (project lifecycle, tool sessions, bounded undo/redo, canonical project serialization), with the shell observing it;
- functional New project and Save (canonical JSON) actions, canvas undo/redo history bar, and live object count and revision status;
- in-memory persistence through the core storage contracts: transactional `MemoryProjectStore` with SHA-256 content receipts and a bounded `MemoryRecoveryJournal` with checkpoint cadence and ordered replay; Save now commits through a store transaction and `restore()` reloads a committed project;
- undo/redo journal records (forward deltas and state markers) and shell restore of the last saved project on startup via a persisted storage key; stale or malformed keys fail closed;
- file-backed storage (ADR-0004): `FileProjectStore` (atomic `.ggen` writes with SHA-256 receipts) and `FileRecoveryJournal` (bounded line-log with durable payloads) in the app documents directory, wired through `path_provider`; in-memory adapters remain the default/fallback;
- security and governance docs: `docs/security/threat-model.md` and ADR-0005 (plugin trust model) drafted; adaptive layout widget tests (compact/tablet/wide/zero-size);
- original compact-phone canvas prototype: `StudioCanvas` with pinch-zoom, pan and draw-tap input on an immutable `CanvasViewport`; the Draw tool commits shape nodes through core tool sessions (undoable, journaled), so undo/redo and live object count are exercisable on-device for the first time. Double-tap zoom is deliberately absent (the recognizer's 300ms arena hold delays single-tap resolution); real vector drawing, selection, layer list, zoom controls and stylus input are deferred;
- Text tool (tap prompts for text, commits an undoable text frame), volume-down/up undo/redo (consumed so the system volume is unchanged), two-finger tap undo and three-finger tap redo (raw pointer bursts, <300ms, <20px movement), history bar moved to the bottom-left so it no longer covers the project-name chip, and the chip scrolls horizontally for long names. A shell integration test pins the device-reported Draw flow (nav → canvas tap → node).

## App identity

- The device-facing Android app identity is exactly **ggen**: launcher label `ggen` and process name (`applicationId`) `com.example.ggen`, applied by `scripts/prepare_android_identity.py` in the manual APK workflow after the wrapper is generated. The tagline and the internal Dart package identifier (`ggen_app`) are unchanged. `com.example` is provisional until a real application domain is selected.

## Verification

GitHub Actions validates core contracts, governance and Flutter shell tests on code changes. Android debug APK generation is manual-only through `Android debug build (manual mobile test)`.

A manual Android debug build from commit `11ada607` completed successfully in GitHub Actions run `32287854429`. Physical-device behavior is recorded only from user-provided Redmi Turbo 4 Pro diagnostics; CI does not constitute device verification.

The supplied device diagnostics confirmed:

- compact viewport measurements of `471 x 1020` and `471 x 706`;
- canvas geometry of `471 x 353`;
- successful workspace restore;
- immersive enter/restore;
- tool navigation;
- profile application;
- reset requests;
- no Flutter or uncaught errors in the latest clean profile test.

Earlier diagnostics exposed profile-manager lifecycle defects. They were fixed in PR #24 and the subsequent manual retest showed no recurrence. Profile save and delete events were added in PR #25 for future evidence.

The persistence-milestone APK (2026-08-20 08:08:47Z export) confirmed the canvas-first switch fix on-device (`canvas_first` alternates enabled/disabled) and exercised `project_new`, `project_save` (idempotent re-save at the same key/revision/digest), profiles and immersive without crashes. It also exposed a **storage-init defect**: `LateInitializationError: Field '_studio' has already been initialized` — the shell's `_studio` was `late final` but `storage_init` reassigns it when swapping onto the file-backed store. The device run therefore fell back to in-memory storage (saves were not durable). Fixed by making the field reassignable, with a regression widget test using a fake `PathProviderPlatform` that exercises the swap and asserts a real `.ggen` file write on Save. A fresh APK is required to re-validate persistence on-device; the first launch after the fix may log a benign "no stored project" warning for the stale in-memory key from the affected build.

A canvas-shell run on 2026-08-20 (export `09:52Z`) confirmed on the Redmi Turbo 4 Pro: canvas bounds now `471 x 828` (the interactive canvas replaced the old static 4:3 box), tool names logged with selection, New project and Save clean, immersive `471 x 1020` with `safe_top 56`, no errors. It also exposed a diagnostics flood: the settings-sheet animation resized the canvas ~1px per frame and `canvas_geometry` logged ~50 entries in seconds, crowding the bounded log. Fixed by an 8px quantized dedupe key plus a 500ms cooldown, with a widget test asserting ≤8 entries for 60 one-pixel steps. `project_restore` and `history_undo`/`history_redo` remain to be exercised on-device (undo/redo enable only after a Draw-tap creates history).

A file-backed persistence run on 2026-08-20 (export `09:01:17Z`) confirmed on the Redmi Turbo 4 Pro:

- `storage_init` logged info "File-backed storage initialized" at `/data/user/0/com.example.ggen/app_flutter` — the storage-init crash from the previous build is fixed on-device, and the path confirms the `com.example.ggen` applicationId (app-identity milestone) in the live data directory;
- `project_new` and `project_save` exercised across three projects; idempotent re-saves produced identical keys, revisions and digests;
- `canvas_first` alternated correctly across six toggles (switch fix stable);
- profiles save/apply (`y7`, `8djgc`), workspace reset and immersive enter/restore all clean;
- no Flutter or uncaught errors.

No `project_restore` event appeared because the session started with empty preferences (clean install), so the last-project restore path still awaits an on-device restart test: save a project, fully close the app, reopen, and export diagnostics. `_restoreLastProject` now logs an info event for the clean-install case to make that distinction visible in exports. Undo/redo events are likewise still unexercised on-device because no editing tool creates history yet (the buttons are disabled until `commitSession` is wired to real edits).

A further clean device run on 2026-08-20 (export `07:49:00Z`) re-confirmed on the Redmi Turbo 4 Pro:

- compact viewport `471 x 1020`, canvas geometry `471 x 353`, zero safe-area/keyboard insets at measurement time;
- workspace restore, tool navigation (Select/Draw/Text/Settings), settings sheet, immersive enter/restore, profile apply (`bb`, `cc`) and workspace reset all exercised;
- no Flutter or uncaught errors.

The same run exposed a **canvas-first switch defect**: six consecutive `canvas_first` "disabled" events showed the settings-sheet switch reporting the sheet-open snapshot instead of reacting to taps (a captured-value switch). Fixed by making the switch own its state (`_CanvasFirstSwitch`), with a widget regression test toggling it off and on. The run's build predates the persistence milestones, so `storage_init`, `project_new`, `project_save`, `history_undo`/`redo` and `project_restore` were not yet exercised on-device; a fresh APK from current `main` is required for that validation.

## Evidence boundaries

- Responsive widget tests are not physical-device tests.
- Android debug APK success is build evidence, not release evidence.
- User-provided device diagnostics are evidence of the exercised flows only; unexercised flows remain unverified.
- No GPU/NPU, performance, persistence-across-reinstall, or production-release claim is made.

## Next

1. ~~Generate a manual APK only when another device validation cycle is needed~~ (canonical manual workflow; used for every device round).
2. ~~Exercise profile save, apply, delete and reset flows on the Redmi Turbo 4 Pro~~ (verified in the 08:08Z and 09:01Z exports).
3. Exercise the Draw-tool and undo/redo flows on the Redmi Turbo 4 Pro and export diagnostics containing `node_add`, `history_undo` and `history_redo` (undo/redo enable only after a Draw-tap creates history; still unexercised on-device).
4. Exercise the restart-restore flow: save, fully close the app, reopen, export diagnostics containing `project_restore` (still unexercised on-device; last export logged the clean-install event).
5. SAF/MediaStore user-facing Import/Export (ADR-0004 defers this): share-sheet/SAF picker flow for exporting `.ggen` project files to user-chosen locations and importing them back; progress, cancellation and tests.
6. Creative surface next: Select-tool node selection and move through undoable sessions, then layer list and zoom controls.
