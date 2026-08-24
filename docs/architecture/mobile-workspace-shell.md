# Mobile workspace shell — canonical compact layout

**Date:** 2026-08-24
**Branch:** `feat/mobile-workspace-shell`
**Trigger:** Redmi Turbo 4 Pro (`25053RT47C`) device diagnostics of 2026-08-24.

## Device findings addressed

1. **`A RenderFlex overflowed by 1.2 pixels on the right.`**
2. **`RangeError (length): Invalid value: Not in inclusive range 0..2: 3`** while using the Text tool.
3. Toolbar/button layout accumulated from successive customizations rather than one coherent editor UI.

These are treated as real device findings; the fixes below were reproduced and pinned in widget tests at the 471px-class portrait geometry (471×1020 and the exact fractional 471.04×1020.46 at devicePixelRatio 2.59).

## Root causes

### RangeError (finding 2)

The compact bottom `NavigationBar` (`CompactNavigationBar`) exposed **4 destinations** — Select, Draw, Text, and a contextual *Columns* entry — but the shell's tool state was a raw `int` indexing a **3-entry** tool-name list (`['Select', 'Draw', 'Text']`). Tapping the Columns destination forwarded destination index **3** to `_selectTool`, which logged `_toolNames[index]` → `RangeError: Not in inclusive range 0..2: 3`. The guard (`if (i == 3 && columnsEnabled)`) short-circuited only when a text frame was selected; with the Text tool active and nothing selected, index 3 went straight into the 3-entry list.

**Fix (structural, not a suppression):** tool identity is now a typed enum, `StudioTool` (`lib/src/workspace/studio_tool.dart`), the single source of truth for tool order, labels and icons. Both the compact `MobileToolRail` and the wide `NavigationRail` render from `StudioTool.values`, and the shell state is `StudioTool _tool` — an out-of-range tool state is now unrepresentable. Contextual actions (Columns) are no longer disguised as navigation destinations.

### RenderFlex overflow (finding 1)

The transparent top action bar (`_TopActionBar`) laid out its pinned actions in an unbounded `Row`. Each pinned action costs 52px (48px `IconButton` + 4px padding); with all 8 actions pinned at the device's 471.04px logical width, the row's intrinsic width exceeded the incoming constraint by ~1px — the exact class of the reported 1.2px overflow (reproduced in a widget test before the fix; the magnitude varies with text scale/DPR).

**Fix (correct layout contract, not a clip):** the pinned region is now a `Flexible` → horizontal `SingleChildScrollView` → `mainAxisSize.min` `Row`. The pinned region shrinks to content when it fits and scrolls when it does not, so the outer `Row` is mathematically incapable of exceeding its constraints at any width; the More button keeps its fixed right-edge slot. (The legacy dock/toolbar actions were also removed — see below — so the realistic pin set is smaller.)

### Accumulated toolbar layout (finding 3)

The compact shell had **three competing bottom/side surfaces**: the dockable/collapsible `_SecondaryCanvasToolbar` (bottom/left/right × full/mini/hidden = 9 persisted layout states), the 4-destination `CompactNavigationBar`, plus floating canvas buttons. Controls jumped between edges depending on stored preferences.

**Fix — one canonical mobile workspace (Vector-Ink-style principles, not a copy):**

```
PHONE PORTRAIT (<700px)
┌──────────────────────────────┐
│ transparent top action bar   │  document/workspace actions + More
├──┬───────────────────────────┤
│T │                           │
│O │         CANVAS            │  visually dominant
│O │                           │
│L │                           │
│S │                           │
├──┴───────────────────────────┤
│ contextual action bar        │  history | zoom | view | context
└──────────────────────────────┘
```

- **`MobileToolRail`** (`lib/src/workspace/workspace_bars.dart`): stable 52px vertical rail, left edge, primary tools only, not dockable/collapsible/reorderable. Selected tool state uses the filled icon + primary-container background.
- **`ContextualActionBar`**: the ONE bottom surface. Fixed groups with separators — history (undo/redo), zoom (out/in/fit), view (grid/layers) — plus contextual entries that exist only in meaningful states: multi-select (Select tool active), Columns (selected node is a text frame). Centered when content fits; horizontally scrollable below that, so it cannot overflow.
- **`ToolButton`**: single reusable control (40×40 box, 20px icon, obvious selected state) used by every shell toolbar surface.
- Secondary/advanced controls stay in sheets (Columns/text-flow sheet, layers sheet, settings sheet, More menu) — nothing new pinned over the canvas.

## Product decision: predictable before customizable

The `canvas toolbar dock left/right/bottom` and `full/mini/hidden` customization is **removed**, not migrated: preserving it would have kept the broken multi-surface architecture alive. Underlying functionality (undo/redo/zoom/fit/grid/layers/multi-select/columns) is fully preserved on the canonical surfaces. Saved project data is untouched.

- `WorkspacePreferences` no longer reads `workspace.secondary_toolbar_mode` / `workspace.secondary_toolbar_dock`; stale stored values are ignored on load and **deleted** on the next save/clear.
- The `EditorTopAction.canvasToolbar` / `dockToolbar` actions are gone; stored pins/orders naming them fail closed through the existing sanitizers (pinned test).
- Workspace reset returns to the canonical layout (pinned test).
- Wide (≥700px) layouts are unchanged apart from the shared `StudioTool` metadata; the wide rail, inspector docking and top-bar pinning behave as before.

## Verification (this change)

- `flutter analyze`: no new findings (6 pre-existing, one baseline warning removed with the deleted legacy code).
- App suite: **254/254** (237 baseline kept/updated + 17 new regression tests in `test/mobile_workspace_shell_test.dart`); core suite: **143/143**. Exact CI toolchains (Flutter 3.47.0 / Dart 3.13.0).
- New regression tests pin: no RangeError through the full Text-tool gesture cycle (tool switches, frame creation, editing, outside taps, keyboard insets, repeated taps); no RenderFlex overflow at 471×1020 and 471.04×1020.46 with the maximal pinned-action set; contextual bar states for no/one/multiple/text selection and per-tool; exactly one rail + one bar in every tool state; reset-to-canonical; save/load; linked-text-flow sheet reachability.
- Updated legacy tests: compact-layout expectations now assert the canonical rail/bar instead of the removed `NavigationBar`/secondary toolbar; Columns entry is asserted via its contextual action tooltip.

**Not verified here:** physical-device behavior. A debug APK from `android-build.yml` is the device-validation candidate; device validation is complete only when on-device results are reported and recorded.
