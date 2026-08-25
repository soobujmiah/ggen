# Fullscreen controls & landscape layout — plan

**Date:** 2026-08-25
**Branch:** `main`
**Status:** plan (approved for implementation by Sobuj, 2026-08-25)

## Purpose

Move GGEN's mobile workspace from a single width breakpoint (`<700px`)
toward a genuinely premium, adaptive, mobile-first creative workspace:

1. **Fullscreen (immersive) mode** that is real edge-to-edge, draws under the
   camera cutout, and shows ONLY the controls the user chose.
2. **Fullscreen control customization** — More-menu actions can be brought to
   the fullscreen canvas as persistent buttons; placement is user-defined and
   deterministic (no hidden, clipped or overlapping controls).
3. **Movable floating zoom control** — no more hard-coded bottom-right
   position; the user can move it (drag + snap, or region picker).
4. **Flexible control placement** — multiple screen regions with snap,
   bounded per-region capacity and collision rules, so the UI stays clean and
   intentional after customization.
5. **Landscape mode redesigned** — landscape phones must no longer be treated
   as "wide desktop". Compact landscape gets its own minimal single-bar
   layout that maximizes the usable canvas.
6. **Portrait and landscape both first-class**, with state (selection, zoom,
   controls, customization) preserved across orientation changes.

## Current state audit (2026-08-25, main `b514884`)

Read: `apps/ggen_app/lib/main.dart`, `lib/src/workspace/workspace_bars.dart`,
`lib/src/canvas/studio_canvas.dart`, `lib/src/canvas/canvas_viewport.dart`,
`lib/src/canvas/canvas_zoom_controller.dart`, `lib/workspace_preferences.dart`,
`lib/workspace_profile*.dart`, `test/mobile_workspace_shell_test.dart`,
`test/widget_test.dart`, `docs/architecture/mobile-workspace-shell.md`.

### What already exists (keep)

- Canonical compact portrait shell: `MobileToolRail` (left, 52px) + one bottom
  `ContextualActionBar` (undo/redo | zoom | grid/layers | contextual
  multi-select/columns). 17 regression tests pin it at 471px class.
- `ToolButton` (40×40, 20px icon, obvious selected state) — single reusable
  control contract across every toolbar surface.
- Top action bar (`_TopActionBar`): transparent, inside canvas bounds, pinned
  actions + fixed More button; overflow handled by a `Flexible` horizontal
  scroller (cannot overflow).
- More-menu pin/reorder customization for the 6 `EditorTopAction`s, persisted
  in `WorkspacePreferences` (`topActionOrder` / `topActionPinned`).
- Immersive mode: `SystemChrome.setEnabledSystemUIMode(immersiveSticky)`,
  hides all shell surfaces, canvas reaches the true screen edges (device
  validated).
- Zoom overlay (`_ZoomControls`) in `studio_canvas.dart`: zoom −/%/+ / fit /
  grid, fixed `Positioned(right:12, bottom:12)`, shown wide + immersive only.

### Gaps vs. requirements

| # | Requirement | Gap |
|---|---|---|
| 1 | Fullscreen, under cutout | Immersive hides system bars, but the default top bar (pinned + More) still renders; no user control selection. |
| 2 | Fullscreen control customization | Pin system exists but only for the 6 top actions and only on the top bar. Undo/redo/zoom/grid/layers cannot be placed on the fullscreen canvas. |
| 3 | Movable floating zoom | `_ZoomControls` is hard-coded bottom-right; not movable, not customizable. |
| 4 | Flexible control placement | Only two surfaces exist (top bar, fixed zoom overlay). No region model, no snap/collision rules. |
| 5 | Landscape redesign | Single breakpoint `width < 700`. A landscape phone (e.g. 800×360) is classified "wide": left `ToolRail` + bottom `StatusBar` + fixed zoom overlay waste vertical space. This is the main device complaint. |
| 6 | Portrait + landscape first-class | No orientation/device-class handling; state persistence across rotation is untested. |

## Design

### A. Device classes (replaces the single width breakpoint)

New pure function in `lib/src/workspace/control_layout.dart`:

```
WorkspaceClass.classifyWorkspace(width, height):
  wide              : width >= 700 && height >= 600
  compactLandscape  : not wide && width > height
  compactPortrait   : otherwise
```

- 471×1020, 400×800, 360×800 → `compactPortrait` (unchanged behavior).
- 800×1024, 1200×800, 720×1600 → `wide` (unchanged behavior).
- 800×360, 640×360, 900×412 → `compactLandscape` (new).

`compactLandscape` layout: no left rail, no bottom status bar. ONE bottom
`LandscapeBar` (48px, horizontally scrollable, cannot overflow): tools |
undo/redo | zoom −/+/fit | grid/layers | contextual multi-select/columns.
Canvas gets the maximum usable area. Zoom overlay stays hidden (bar owns it).

### B. Unified control model

`CanvasControl` enum — single identity for every placeable action (15):
undo, redo, zoomIn, zoomOut, zoomFit, grid, layers, multiSelect, columns,
newProject, save, diagnostics, settings, immersive, dockInspector.

`ControlRegion` enum (6): topLeft, topCenter, topRight, bottomLeft,
bottomCenter, bottomRight.

`CanvasControlLayout`:
- `defaults()`: topRight = [save, newProject, settings]; bottomRight =
  [undo, redo, zoomOut, zoomFit, zoomIn, grid]; bottomLeft = [layers,
  multiSelect, columns].
- `resolve()` — deterministic normalization: unknown controls/regions dropped
  on load; per-region cap 6; a control placed in multiple regions keeps the
  first region only; the `immersive` exit control is always enforced (first
  slot of topRight, capped region if needed) so the user can never get stuck
  in fullscreen.
- `toPrefs()` / `fromPrefs()` — persisted as JSON in `WorkspacePreferences`
  under `workspace.fullscreen_regions` (new key, cleaned on `clear()`).
- `nearestRegion(dropOffset, viewportSize)` — deterministic snap math
  (3×2 grid: horizontal thirds × vertical halves).

### C. Fullscreen rendering

In immersive mode:
- Top bar (`_TopActionBar`) hidden, project-name overlay hidden, no bottom
  bar, the legacy in-canvas zoom overlay (`_ZoomControls`) hidden.
- The shell renders one `CanvasControlCluster` per region that has controls:
  `Material` pill (surfaceContainerHigh, elevation 2, rounded), row of
  `ToolButton`s, horizontally scrollable and width-bounded so it can never
  overflow or be clipped at any screen width.
- Each cluster is wrapped in a `LongPressDraggable`; on release the shell
  snaps to `nearestRegion` and persists the new placement (movable zoom =
  movable cluster).
- Control enablement mirrors the compact bar: undo/redo disabled without
  history; multi-select only with Select tool; Columns only with a selected
  text frame.

### D. Fullscreen customization sheet

New entry tile "Customize fullscreen controls" at the top of the More sheet:
- One row per `CanvasControl` with a region picker (`PopupMenu`: 6 regions +
  Hidden). Moving a control removes it from its old region and appends it to
  the new one; a full region is rejected with a "region full (6 max)" notice;
  the `immersive` control cannot be hidden.
- "Reset to defaults" restores `CanvasControlLayout.defaults()`.
- Every change persists to `WorkspacePreferences` immediately (survives
  orientation change and app restart).

### E. Preserved behavior (no regression)

- `compactPortrait`: `MobileToolRail` + `ContextualActionBar` untouched.
- `wide`: `ToolRail` + dockable inspector + layers panel + status bar +
  in-canvas zoom overlay untouched.
- More-menu pin/reorder for top actions untouched.
- Existing tests updated ONLY where the intended behavior changed:
  immersive exit is now the enforced cluster control (not the More button),
  and immersive no longer shows the legacy fixed zoom overlay.

## Implementation slices

- **Slice 1 (this milestone):** control model + preferences + fullscreen
  region rendering + customization sheet + drag-snap + `compactLandscape`
  layout + unit/widget tests. CI (Flutter 3.47.0 / Dart 3.13.0) is the
  validator.
- **Slice 2 (later):** premium polish — entrance/exit animation, cluster
  material refinements, per-region alignment polish.
- **Slice 3 (later):** debug APK via `android-build.yml` + physical-device
  validation on the Redmi Turbo 4 Pro (immersive cutout behavior, landscape
  ergonomics, drag feel), results recorded back per the knowledge-return
  protocol.

## Verification

- Unit: `control_layout_test.dart` (resolve/cap/dedupe/enforce, prefs
  round-trip, snap math, device classes).
- Widget: `fullscreen_landscape_shell_test.dart` (landscape 800×360/640×360
  no overflow and single compact bar; wide unchanged; immersive region
  rendering; customization persists; orientation-change state preserved).
- Updated: `widget_test.dart` immersive enter/leave via the enforced cluster
  control; immersive zoom overlay assertions now target the fullscreen
  cluster.
- CI: `flutter test` (apps/ggen_app) + Public governance on push to `main`.

## Supersession (2026-08-25): free-form placement replaces region snap

The physical-device round confirmed the core plan (clusters over the canvas, enforced exit control, movable zoom) but rejected the region-snap interaction: controls overlapped, moving one cluster over another could make controls disappear, and snapping fought the user. The interaction model is therefore superseded by **free-form floating clusters**:

- `ControlRegion` / `nearestRegion` removed. A cluster is `FullscreenControlCluster {id, controls, position}` with a NORMALIZED top-left anchor (x/y ∈ 0..1) persisted under `workspace.fullscreen_clusters` (legacy `workspace.fullscreen_regions` migrates on load, removed on next save).
- Drag = long-press (300 ms) then 1:1 pointer delta — no snapping, no collision relocation. Overlapping clusters ALL render; the last-touched cluster is brought to front and receives gestures first. Positions persist; empty clusters drop out; `resolve()` still guarantees the immersive exit control (which is now free-placed like every other control).
- Idle de-emphasis: after `kFullscreenIdleTimeout` (6 s) the clusters fade to 45% opacity IN PLACE; any interaction restores prominence. Positions never change on idle.
- The customizer's per-control picker now assigns controls to floating groups (existing + Hidden + New group); positions are direct-manipulated on the canvas, not configured modally.
- Immersive mode now also draws the canvas edge-to-edge (body SafeArea top inset not consumed in immersive) while clusters clamp into `MediaQuery.viewPadding` — the device-reported unused status-bar strip is addressed on the Flutter side (bars already hidden via `SystemUiMode.immersiveSticky`).

The landscape device-class model (`WorkspaceClass`) survives. The compact-landscape **bottom** `LandscapeBar` was later replaced (2026-08-25 follow-up): tools live on the LEFT `MobileToolRail` and actions on the RIGHT `LandscapeActionRail` so the short vertical axis stays canvas. Fullscreen clusters gained a dedicated drag handle, idle opacity 0.82, and `cluster_drag_*` diagnostics.
