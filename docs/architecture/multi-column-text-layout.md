# Multi-column text frame layout & gutter geometry

**Status:** implemented in `ggen_core` and the Flutter shell at 2026-08-24. CI/widget-test verified. **Not yet physical-device validated on the Redmi Turbo 4 Pro.**

## Why this looks the way it does

At the start of this work GGEN had no text-flow engine, no frame rectangle and no page/column geometry: a "text frame" was a single-line `DocumentNode` of kind `textFrame` whose payload lived in loose extensions (`x, y, size, text, color`) and was rendered by the canvas as one `Text` widget with an approximate bounding box. The milestone asked to *extend an existing Phase 3 text-flow foundation* that did not exist in the repository (the canonical roadmap defines Phase 3 as the Font Creation Studio).

Per the repository rule "repository truth always overrides a prompt", the missing foundation was built first, in the smallest deterministic, platform-neutral form that the milestone could sit on top of, without changing the schema version or breaking legacy single-line text nodes.

## Core model (`packages/ggen_core/lib/src/text/`)

`frame_geometry.dart`
: Platform-neutral `FrameRect` (left/top/width/height, `contains`, `overlaps`, no Flutter import) and `FrameGeometry` (outer `x/y/frameWidth/frameHeight` plus `innerPadding`). `contentRect` derives the interior rectangle; padding that consumes the content fails closed.

`column_layout.dart`
: `ColumnLayout` is the canonical, immutable configuration: `columnCount` (1..24), `gutter` (finite, ≥ 0), `direction` (only `leftToRight` shipped; `rightToLeft` is declared but rejected so RTL is not silently mis-ordered), `balanced` (always `false`; newspaper balancing is **planned, not implemented**). Defaults are one column / zero gutter, which every legacy document decodes to.
: `ColumnGeometry.layout(layout, content)` computes N equal-width columns:

```
availableWidth = content.width - (N - 1) * gutter
columnWidth    = availableWidth / N
```

  It rejects `availableWidth <= 0`, empty content and non-finite results (fail closed). It exposes `columnBounds`, `columnCount`, `gutter`, `totalContentBounds`, `containsPoint` and `columnAtPoint` (a point in a gutter is inside the content but in **no** column). Columns never overlap and are fully contained.

`text_flow_engine.dart`
: `TextMeasurementProvider` is the rendering-free abstraction core asks for capacity (`charactersThatFit`, `measureTextHeight`, `lineHeight`). `MonospaceMeasurementProvider` is the deterministic CI/test provider; the shell supplies a `TextPainter`-backed `FlutterTextMeasurement`.
: `TextFlowEngine.flow(story, frames, fontSize)` fills columns left→right, top→bottom within each frame, then proceeds to the next linked frame in order. For each column it greedily wraps one visual line at a time, honors explicit `\n`, and guarantees:

```
sum(rendered chars across all columns/frames) + terminal overflow == story.length
```

  `TextFlowResult.conserves(story)` verifies the concatenated slices equal the exact story prefix (zero loss/duplication/reordering). The last non-empty column of the final frame carries `hasOverflow` when text remains; empty trailing columns are never flagged.

## Serialization & backward compatibility

- Column config is stored on the text node's existing extensions map as `columns` (int) and `gutter` (double), alongside the new `w`/`h` frame size. No schema-version bump is required and `ProjectCodec` is unchanged — unknown/absent fields are ignored by codec policy.
- **Legacy documents:** a text node with no `columns`/`gutter`/`w`/`h` decodes and renders exactly as before (single-line `Text` widget, approximate bounds). The first time such a node is given columns through the controller, it receives the default frame size (480×360) so columns have a real content rectangle; until then nothing about it changes.
- Malformed column config (non-int count, negative/non-finite gutter, unknown direction, `balanced: true`) throws on construction/decode — fail closed, never a silently wrong layout.

## Transactions & UI

- `StudioController.configureTextColumns(id, columnCount, gutter)` and `resetTextColumns(id)` each go through one `ProjectToolSession` → exactly one `ProjectTransaction` (one revision, undoable/redoable). Invalid input throws **before** any revision; a no-op returns `false` and burns no revision. Only the targeted node's extensions change.
- Wide layout (≥900 px): the inspector panel gains a **Columns** section (count slider, gutter field, Reset, full-width Apply) below the existing text content/size/position fields.
- Compact 471 px-class layout: there is no side inspector, so a **Columns** destination in the bottom navigation opens a mobile bottom sheet (`_ColumnsSheet`) with the same controls and live column guides. The sheet owns its `TextEditingController` so it survives the exit animation.
- The canvas renders each column's visible slice as a real clipped `Text` widget (testable, interactive) and overlays column guides (solid when selected, dashed otherwise; always visible for >1 column) plus a red corner overflow tab. A `CustomPainter` is used only for guides/tab, not for text.

## Reading order and multi-frame flow

Reading order is column 1 → 2 → … → N within a frame, then the next linked frame's column 1 → … The engine already supports an ordered list of `TextFlowFrameInput` (core tests cover a 3-frame / 2-column chain with strict conservation). The Flutter canvas currently flows a single selected frame; chaining the on-canvas render across multiple linked frames is a later UI step that the core contract already supports.

## Deliberately not done

- Newspaper-style automatic column balancing (declared, rejected).
- Right-to-left column order (declared, rejected until needed).
- Linked multi-frame rendering in the shell UI (core supports it; canvas wiring deferred).
- Frame resize handles for text frames (shape handles remain shape-only).
- Physical-device validation — see the pending Redmi round in `phase-2-status.md`.
