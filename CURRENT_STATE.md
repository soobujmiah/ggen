# GGEN Current State

Snapshot date: 2026-08-24
Repository: `soobujmiah/ggen`
Default branch: `main`
Source of truth: GitHub repository state, tests/CI evidence, and documented physical-device evidence.

## Current phase

**Phase 2 — Responsive workspace and creative-surface foundation: active.** Phase 1 core foundation is complete and green. Phase 2 has a substantial original Flutter workspace/canvas foundation and ongoing Redmi Turbo 4 Pro validation.

## Verified baseline

- Pure-Dart core contracts are implemented and have pinned local verification documented as 27 unit tests passing on 2026-08-20.
- GitHub Actions governance, reusable core tests and Flutter shell tests are documented green on `main` for the Phase 1 verification set.
- Phase 2 has responsive layouts, workspace settings/profiles, diagnostics, persistence adapters, canvas interaction, Select/Draw/Text, multi-select, grid, groups, layer-list, numeric-inspector, **multi-column text frame layout with gutter geometry** (N equal columns, exact-character text flow, overflow indication, inspector + mobile sheet, one-step undoable transactions, JSON round-trip; CI/widget verified) and the **page-linked text-flow milestone** — Stages 1–3 (page geometry, linked text-frame chains, deterministic wrapping) in `ggen_core` merged via PR #52 (merge commit `7eacadedc30ebda41315bc65813edc44a4d681bd`), and Stage 4 (app integration: controller link/unlink with fail-closed one-step undoable transactions, per-frame slice rendering of linked chains, blue continuation / red terminal-overflow indicators, page-aware frame creation, `nextFrame` persistence, minimal link UI) implemented on `feat/linked-text-flow-app` from that merge. Core 143/143 (Dart 3.13.0, exact CI SDK) and app 237/237 (Flutter 3.47.0, exact CI pin) verified locally with the exact toolchains; GitHub Actions re-runs the same gates on the PR. Not yet exercised on-device; a debug APK built from the repository's `android-build.yml` pipeline is the device-validation candidate.
- Redmi Turbo 4 Pro evidence exists for current controls and several editing/persistence flows. Device evidence remains scoped to the exact exported diagnostics and does not imply release, GPU/NPU or benchmark validation.

## Evidence boundary

**Verified:** source implementation and the specific CI/device checks recorded in `docs/phases/phase-1-status.md` and `docs/phases/phase-2-status.md`.

**Not automatically verified:** production release readiness, GPU/NPU execution, performance benchmarks, persistence across reinstall, or any device behavior not represented by current device diagnostics.

## Known / pending validation

- Continue the Phase 2 creative-surface milestone using the documented device evidence boundary.
- Exercise any remaining device-only flows explicitly called out by `docs/phases/phase-2-status.md`, rather than treating implementation or widget tests as device proof.
- Keep measured product limits and migration fixtures explicit before accepting another schema version.
- Keep SAF/MediaStore import/export as a separate storage milestone rather than implying it is complete from file-backed persistence.

## Required reading for the next AI

1. `AI_ASSISTANT.md`
2. `MASTER_SPEC.md`
3. `README.md`
4. `docs/phases/phase-1-status.md`
5. `docs/phases/phase-2-status.md`
6. Relevant architecture/ADR documents
7. Relevant source and tests

## Latest working change (2026-08-25 — Physical-device UX fixes: open/load project, true immersive, free-form fullscreen controls, hidden reorder)

Implements the physical-device UX fixes discovered during the 2026-08-24 Redmi Turbo 4 Pro validation round (diagnostics export `2026-08-24T23:14:38Z`): user-facing project open/load, genuinely full-display immersive mode, free-form fullscreen control placement (region-snap model removed), overlap-safe clusters with idle de-emphasis, and long-press-only reorder in the More menu. One focused milestone on a feature branch from `main` `b061099d0c7f87d760cb123a701cf9fab6828863`.

**Changes:**
- **Open/Load project (`Issue A`)**: new `SavedProjectSummary` + `ProjectStoreListing` capability (`apps/ggen_app/lib/src/storage/saved_project_summary.dart`), implemented by `FileProjectStore` (scans `<documents>/projects/*.ggen`, skips corrupt/invalid entries, most-recent-first) and `MemoryProjectStore` (same semantics); `StudioController.listSavedProjects()` delegates and fails closed. New `EditorTopAction.openProject` / `CanvasControl.openProject` opens an "Open project" sheet (name, revision, key, save time) whose rows restore through the EXISTING `restore(ProjectStorageKey)` path — no second persistence system. Missing/corrupt/malformed projects fail safe with a SnackBar and leave the workspace untouched. **Bug fixed:** `_persistWorkspace()` previously dropped `lastProjectKey` (any unrelated workspace change silently broke startup restore); the key is now shell state included in every workspace save, set by save/open/startup-restore.
- **True immersive (Issue B)**: the body `SafeArea` no longer consumes the top inset in immersive mode — the canvas/background extends edge-to-edge behind the (hidden) status-bar/cutout region, while the floating control clusters clamp themselves into `MediaQuery.viewPadding` so interactive controls stay reachable. Normal mode is unchanged (top inset always consumed). `immersive_mode` diagnostics now record padding/view-padding insets.
- **Free-form fullscreen controls (Issue C)**: `control_layout.dart` was reworked — `ControlRegion` and `nearestRegion` snap math are REMOVED. `FullscreenControlCluster {id, controls, position}` carries a normalized top-left anchor (x/y ∈ 0..1) so placements survive device size/orientation changes; pure helpers (`estimatedClusterSize`, `clusterPixelsForNormalized`/`normalizedForClusterPixels`) clamp clusters fully inside the safe viewport. Clusters drag freely (no snapping, no collision relocation), ALL clusters render even when they overlap (last-touched is brought to front and receives gestures first), and positions persist under the new `workspace.fullscreen_clusters` key (the retired `workspace.fullscreen_regions` format migrates on load and is removed on next save). The immersive exit control remains guaranteed present but participates in free placement. After `kFullscreenIdleTimeout` (6s, public const) of inactivity the clusters fade to 45% opacity IN PLACE; any interaction restores full prominence.
- **More-menu reorder (Issue D)**: the permanently-visible up/down reorder arrows are gone. Rows are a `ReorderableListView` with no default handles: tap executes the action; press-and-hold enters reorder mode for that row (drag handle + up/down arrows appear); drag/arrows commit the order and persist; release or any outside tap returns the menu to normal without executing anything.
- **Customizer**: the "Customize fullscreen controls" sheet now assigns each control to a floating group (existing groups + Hidden + "New group…"); positions are edited by dragging in fullscreen, not by modal configuration.

**Test gate:** run in CI/verification (Flutter 3.47.0 / Dart 3.13.0, exact CI pins): `control_layout_test.dart` rewritten for the free-form model (resolve/merge/cap/dedupe/exit-guarantee, prefs round-trip + legacy migration, pixel↔normalized math and clamping), `fullscreen_landscape_shell_test.dart` extended (default clusters, customization persists, free drag persists with no region names, overlapping clusters both render and move independently, idle fade + restore without relocation), `workspace_preferences_test.dart` updated (clusters key + legacy read/removal), new `more_menu_reorder_test.dart` (no affordances normally, tap executes, long-press enters reorder mode, arrows and drag reorder + persist, release/outside interaction exits), new `project_open_test.dart` (list + open, empty store, missing project fails safe, last-project key survives unrelated changes), store listing tests for both adapters, controller listing test. Physical-device validation on the Redmi Turbo 4 Pro and the `android-build.yml` debug APK are the remaining evidence steps — **no device claim is made until the APK is tested on-device**.

**Previous entry (2026-08-25 — Fullscreen control regions & landscape device class):** superseded for the fullscreen-control interaction model by this milestone (the region/snap model is removed; the `WorkspaceClass` landscape device-class layout, `LandscapeBar` and the region-free cluster rendering survive in the free-form form). See `docs/architecture/fullscreen-control-and-landscape-plan.md` for the supersession record.

**Previous entry (2026-08-24 — Vector Studio Milestone 1):**

Implements the Vector Studio Milestone 1 slice (rectangle + ellipse primitives) extending the existing `DocumentNodeKind.shape` model rather than introducing a parallel vector system.

**Changes:**
- New `ShapePrimitive` enum (`rectangle`/`ellipse`) and `NodeShapeGeometry` value type with fill, optional stroke, stroke_width and shape_type (`apps/ggen_app/lib/src/geometry/shape_geometry.dart`).
- Core fail-closed validation in `ggen_core` `Artboard._validateShapeGeometry` for x/y/w/h/fill/stroke/stroke_width/shape_type; bare shape placeholders (no geometry keys) remain accepted for backwards compatibility.
- `StudioController._addPrimitive`, `addShapeNode`, `addEllipseNode`, `updateShapeStyle` (one-step undoable transactions); writes canonical `fill` + legacy `color` for compat.
- Canvas `_ShapePainter`/`_SelectionPainter` CustomPainters that draw fill + stroke for rect/ellipse and render selection outlines; ellipse creation path routed through `ellipseEnabled`.
- Tool rail: `StudioTool.ellipse` added (enum name `draw` retained for Rectangle wire stability); tooltips updated; NavigationRail/MobileToolRail auto-derive destinations from `StudioTool.values`.
- Inspector shape panel: fill swatch row, stroke toggle, stroke-color swatch row, stroke-width ± stepper; changes apply through `updateShapeStyle` as one undoable step.
- 22 new tests in `apps/ggen_app/test/vector_studio_m1_test.dart` covering creation, style independence, persistence round-trip, fail-closed malformed geometry, undo/redo, rendering primitive mapping, and legacy color-only compat.

**Test gate:** core 143/143 (Dart 3.13.0, exact CI pin), app 276/276 (Flutter 3.47.0, exact CI pin, 254 baseline + 22 M1). CI green on `main` at `1d9b5c2` (formatting follow-up to `b548052`): governance ✅, core/test ✅ (format + analyze --fatal-infos + dart test), flutter-shell test ✅. `flutter analyze` has zero errors; remaining info/warnings are pre-existing (8 items). **No physical-device validation performed. No APK built in this milestone.**

**Previous entry (mobile workspace shell):** The first Redmi Turbo 4 Pro diagnostics round on the Stage-4 APK reported a RenderFlex overflow (1.2px right), a Text-tool RangeError (`Not in inclusive range 0..2: 3`) and an incoherent accumulated toolbar layout. Branch `feat/mobile-workspace-shell` (from `b926b28`) fixes both bugs at their root (typed `StudioTool` enum eliminates the out-of-range tool index; the top action bar's pinned region is now a bounded scroller) and replaces the compact shell's three competing toolbar surfaces with one canonical layout: stable left tool rail + single bottom contextual action bar; legacy toolbar dock/mode preferences retired fail-closed. That baseline remains green (app 254/254 before M1 extension). See `docs/architecture/mobile-workspace-shell.md`.

## AI Gateway Runtime documentation

An architecture/engineering specification for a separate provider-agnostic AI Gateway Runtime has been added at `docs/architecture/ai-gateway-runtime.md`. It is documentation/architecture only at this stage and does **not** claim that the Gateway Runtime has been implemented in GGEN. The specification covers provider adapters, normalized AI contracts, capability-aware routing, bounded retry/failover, health/circuit-breaker behavior, structured tool runtime, Android permission boundaries, secret handling, audit, threat model, testing, milestone sequencing, and an agent execution contract. Public release of that runtime is not authorized until its implementation and release gates are independently verified.

The GitHub commit adding the specification is `251a022475c7a6cc61f32996ecae455037b2210e`.

## Next recommended milestone

**Physical-device validation of the current milestone:** with the physical-device UX fixes merged and CI-green on `main`, build a fresh debug APK through the manual `android-build.yml` workflow and validate on the Redmi Turbo 4 Pro (`25053RT47C`): Open/Load project (save, list, open, reload/restore), normal-mode system area unchanged, immersive mode actually uses the full display area (no status-bar strip) with reachable exit, free-form floating controls (drag anywhere, no snapping, overlap keeps both, positions persist, idle de-emphasis, interaction restores), More-menu reorder (hidden normally, long-press reveals, reorder persists), then export fresh diagnostics. Do not claim device validation until actual on-device results are recorded.

Then continue Phase 2 from the exact current `main` HEAD: inspect the latest phase-2 status and recent commits, identify the smallest remaining evidence-backed creative-surface milestone, implement only that scope, run relevant CI checks, update phase/status documentation, and close the session with a commit SHA and handoff update.

**AI Gateway Runtime is not the next GGEN implementation milestone.** It remains a separately documented architecture track until an explicit implementation scope/repository boundary is established.

## Session handoff rule

A new AI must reconstruct state from this file plus repository evidence. Do not rely on a previous chat session's claims. Before risky/model-switch work, create a named snapshot branch from the known-good HEAD. At session close: review diff/status, run relevant checks, update docs/evidence, commit/push when authorized, record SHA, and leave no unexplained changes.
