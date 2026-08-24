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

## Latest working change (2026-08-25 — Fullscreen control regions & landscape device class)

Implements the "fullscreen controls & landscape" plan (`docs/architecture/fullscreen-control-and-landscape-plan.md`): a unified control-placement model for immersive mode and a device-class layout model that stops treating landscape phones as "wide desktop".

**Changes:**
- New `CanvasControl` / `ControlRegion` / `CanvasControlLayout` model (`apps/ggen_app/lib/src/workspace/control_layout.dart`): 15 placeable controls (undo/redo/zoom/grid/layers/multi-select/columns/new/save/diagnostics/settings/immersive/dock), 6 regions (corners + top/bottom center), deterministic `resolve()` (per-region cap 6, dedupe first-region-wins, **enforced immersive exit control**), pure `nearestRegion` snap math, `toPrefs`/`fromPrefs` round-trip.
- Fullscreen (immersive) now renders ONLY the user's chosen control clusters per region — the default top bar and the legacy fixed bottom-right zoom overlay are gone. Clusters are width-bounded + horizontally scrollable (can never overflow/clip) and **draggable** (long-press → snap to nearest region → persist; 300 ms delay beats the Tooltip long-press in the gesture arena).
- New "Customize fullscreen controls" sheet in the More menu: per-control region picker (6 regions + Hidden), region-full rejection with notice, immersive-exit cannot be hidden, Reset to defaults, immediate persistence via `workspace.fullscreen_regions`.
- `WorkspaceClass` device model replaces the single `width < 700` breakpoint (classified from the **full** view size, not body constraints): `compactLandscape` (e.g. 800×360, 640×360) gets ONE compact `LandscapeBar` (tools | history | zoom | view | context, 48px, scrollable) and the maximum usable canvas; `compactPortrait` (rail + contextual action bar) and `wide` (rail + inspector + status bar + zoom overlay) are unchanged.
- `WorkspacePreferences` gains `fullscreenRegions` (single JSON key, fail-closed decode, removed on clear/reset); orientation changes preserve tool/grid/selection/zoom state and customization.

**Test gate:** app suite **305/305** with the exact CI pin (Flutter 3.47.0 / Dart 3.13.0) verified locally; new unit suite `control_layout_test.dart` (classify, resolve, cap, dedupe, enforced exit, prefs round-trip, snap math) and new widget suite `fullscreen_landscape_shell_test.dart` (landscape 800×360/640×360 single-bar no-overflow, wide unchanged, immersive default regions, customization persists, orientation-change state, drag-snap persists), plus extended `workspace_preferences_test.dart`; `widget_test.dart` immersive enter/leave and zoom-overlay tests updated to the new fullscreen behavior. CI green on `main` at `fde06ec`: governance ✅, flutter-shell test ✅. `flutter analyze` has no new findings (8 pre-existing baseline items). **No physical-device validation performed; no APK built in this milestone** — device validation (immersive cutout behavior, landscape ergonomics, drag feel) is the next milestone (Slice 3 of the plan).

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

**Physical-device validation of the linked text flow (separate milestone):** with the Stage-4 branch merged and CI-green on `main`, install the repository-built debug APK on the Redmi Turbo 4 Pro (`25053RT47C`) and exercise the checklist in `docs/architecture/page-linked-text-flow.md` / the device checklist of the current milestone: create two text frames, configure 2/3 columns + gutter, overflow the first frame, link A → B, confirm the story continues into B with the blue continuation indicator, verify the red terminal-overflow tab appears exactly once, test unlink/invalid-link/undo/redo, save/reload, and confirm no duplicated or lost characters. Do not claim device validation until actual on-device results are recorded.

Then continue Phase 2 from the exact current `main` HEAD: inspect the latest phase-2 status and recent commits, identify the smallest remaining evidence-backed creative-surface milestone, implement only that scope, run relevant CI checks, update phase/status documentation, and close the session with a commit SHA and handoff update.

**AI Gateway Runtime is not the next GGEN implementation milestone.** It remains a separately documented architecture track until an explicit implementation scope/repository boundary is established.

## Session handoff rule

A new AI must reconstruct state from this file plus repository evidence. Do not rely on a previous chat session's claims. Before risky/model-switch work, create a named snapshot branch from the known-good HEAD. At session close: review diff/status, run relevant checks, update docs/evidence, commit/push when authorized, record SHA, and leave no unexplained changes.
