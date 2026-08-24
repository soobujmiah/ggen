# Vector Studio — Milestone 1

**Status:** IMPLEMENTED (2026-08-24)
**Owner:** GGEN
**Runtime dependency:** none for manual vector editing
**AI dependency:** none
**Date:** 2026-08-24

## Goal

Turn the existing shape-node foundation into the first genuinely useful professional vector-editing slice without introducing a second document/runtime model.

The milestone is manual-first and must work fully offline. It extends the existing `DocumentNodeKind.shape` + geometry-extension model and existing selection/move/resize/history infrastructure.

## Research basis

### Infinite Design — Android vector benchmark

The Android Google Play listing identifies infinite canvas, path editing, boolean operations, alignment/distribution, unlimited layers/undo, pen construction, perspective guides, text-on-path, transforms, gradients/pattern fills, shape detection, grid/snapping, vectorization and SVG import/export. These are useful benchmarks for the depth GGEN should ultimately target, not a claim of parity.

### Concepts — Android precision/infinite-canvas benchmark

Concepts documents an infinite canvas, editable vector-based strokes, 120Hz rendering, pressure/tilt/velocity/azimuth support, lasso/item selection, transforms, grids/snap/measurement, shape guides, layers, PDF support and cross-format export. Its Android feature matrix also makes platform differences explicit; GGEN should similarly record platform-specific evidence instead of assuming parity.

### Vector Ink — Android shape/SVG benchmark

Vector Ink documents a path-builder workflow, stabilized drawing, distribution, gradients, multiple color pickers, palettes, outline text, vector tracing, pen/boolean operations, layer management and SVG/PNG/JPG import/export. Its path-builder and SVG-oriented workflow are particularly relevant to GGEN's first structured-vector slice.

## Milestone scope

1. **Explicit primitive type**
   - rectangle
   - ellipse
   - future path/line types remain out of scope for this slice

2. **Persistent vector geometry**
   - x/y/width/height
   - primitive type
   - fill color
   - optional stroke color/width
   - validated finite geometry

3. **Creation**
   - create rectangle and ellipse as real shape nodes
   - clamp creation to artboard bounds
   - one creation = one undoable transaction

4. **Selection/editing**
   - existing hit-testing remains authoritative
   - existing move and resize remain one-step undoable operations
   - selection handles work for both primitives
   - preserve multi-select/group behavior

5. **Precision**
   - grid snap when the existing modifier/snap policy is active
   - no hidden rounding that changes stored geometry
   - geometry remains artboard-space values

6. **Style**
   - fill is independent from geometry
   - stroke is optional and has validated non-negative width
   - rendering must distinguish rectangle and ellipse without rasterizing the document model

7. **Persistence**
   - project codec round-trip preserves primitive type and style
   - malformed geometry fails closed

8. **Tests**
   - controller creation, move, resize, undo/redo
   - rectangle/ellipse rendering smoke tests
   - hit-test tests
   - serialization round-trip
   - malformed extension tests
   - compact/tablet/wide widget coverage where the tool surface changes

## Explicit non-goals

- Bezier/node editing
- boolean path operations
- arbitrary SVG path authoring
- gradient editor
- pattern fills
- text-on-path
- vectorization
- AI vectorization
- full Illustrator/Infinite Design parity

Those belong to later milestones after this primitive foundation is validated.

## Architecture rules

- GGEN owns vector semantics and editing UX.
- LAI is not required for manual vector creation.
- Do not introduce a second vector document model.
- Do not add a provider/runtime dependency for this milestone.
- Do not rewrite the existing selection/move/resize/history infrastructure.
- Preserve schema compatibility: new extension keys must be version-safe and fail closed.
- Every implemented claim must have tests; device-specific performance claims require device evidence.

## Acceptance gate

Milestone is complete only when a user can create, select, move, resize, style, save/reload, undo and redo both rectangle and ellipse objects without losing vector semantics, and the same project remains editable after reload.
