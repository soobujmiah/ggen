# GGEN Professional Workspace Shell

**Status:** Proposed design specification — documentation only
**Date:** 2026-08-24
**Scope:** Mobile/tablet creative workspace UI

## 1. Goal

GGEN requires a stable, professional creative-editor workspace rather than a collection of independently customizable bars.

The shell shall prioritize canvas space, predictable tool discovery, contextual precision controls, and touch-safe targets. The layout must remain coherent when the device changes orientation, the keyboard appears, an inspector opens, or the user enters immersive mode.

## 2. Design reference boundary

Vector Ink is a behavioral reference for this design discussion, not a source to copy. Its current documentation describes an adaptive control bar that changes with the active tool, a bottom control bar on phones, contextual transform/object/align/arrange controls, and a mobile layers location. citeturn0search0turn0search2turn0search3

GGEN shall use the underlying interaction principle — **stable primary tools + contextual controls** — while retaining an original GGEN information architecture, visual language and product identity.

## 3. Canonical workspace regions

The workspace has five logical regions:

```text
+---------------------------------------------------+
| Primary Actions / document context / overflow     |
+-----+---------------------------------------------+
|     |                                             |
| Tool|                                             |
| Rail|                 CANVAS                      |
|     |                                             |
|     |                                             |
+-----+---------------------------------------------+
|      Contextual Action / Precision Bar            |
+---------------------------------------------------+
```

Not every region is visible in every mode.

### 3.1 Primary action region

Purpose:

- document/project actions;
- undo/redo where appropriate;
- save/status;
- search or command entry where introduced;
- overflow (`More`) for secondary workspace actions.

Rules:

- fixed structural position;
- never dynamically grow until it pushes essential controls off-screen;
- overflow is explicit;
- pinned actions are bounded and scrollable rather than unbounded rows;
- no user customization may create an invalid layout.

### 3.2 Primary tool rail

The primary tool rail is stable and contains the most frequent editing tools.

Initial conceptual groups:

- Select;
- Draw/Pen;
- Shape;
- Text;
- Image/Media;
- navigation/pan when needed;
- tool-group expansion.

A tool group opens a contextual palette instead of permanently adding every member to the rail.

The rail is not a generic navigation bar. Tool identity is typed and independent from visual index positions.

### 3.3 Canvas

The canvas is the primary work surface.

Requirements:

- maximize usable area;
- preserve predictable coordinate transforms;
- support pan/zoom without accidental tool activation;
- expose selection affordances appropriate to the active tool;
- maintain correct geometry when keyboard or panels consume space;
- support immersive mode without losing access to recovery/exit controls.

### 3.4 Contextual action bar

The contextual bar is the main precision/action surface.

It changes according to the active tool and selection state.

Examples:

**No selection:**

- undo;
- redo;
- zoom out;
- zoom level/fit;
- zoom in;
- view/grid;
- layers.

**One object selected:**

- transform;
- align;
- arrange/order;
- duplicate;
- delete;
- object properties;
- tool-specific controls.

**Multiple objects selected:**

- group/ungroup;
- align;
- distribute/arrange;
- combine/boolean where applicable;
- duplicate;
- delete.

**Text selected:**

- typography;
- font;
- size;
- alignment;
- spacing;
- columns/text flow where applicable;
- text-specific properties.

The bar should prefer a compact set of high-frequency actions and provide an overflow/context panel for the rest.

### 3.5 Inspector/panels

Inspector and Layers are secondary surfaces. They must not compete with the primary canvas indefinitely on narrow screens.

- phone: modal sheet/drawer/panel;
- landscape/tablet: dockable side panel;
- desktop-class width: persistent inspector may be appropriate.

Panel state must be constrained to valid configurations.

## 4. Mobile behavior

At approximately the current portrait evidence size (`471 × 1020` logical workspace measurement), the canonical mobile shell shall remain usable without horizontal overflow.

Rules:

- touch targets are at least 40 dp for compact editor controls and preferably 44–48 dp for primary actions;
- no fixed collection of buttons may assume unlimited horizontal space;
- labels are optional for compact controls but tooltips/accessibility labels remain mandatory;
- primary tool rail remains discoverable;
- contextual controls can scroll horizontally;
- secondary actions move into a sheet/menu rather than shrinking below usable touch targets.

## 5. Landscape/tablet behavior

At the observed `1020 × 471` layout, the shell may use:

- persistent left tool rail;
- right inspector/layers panel;
- contextual control bar near the canvas edge;
- expanded action labels where space permits.

Panels must reduce canvas bounds through a single authoritative geometry calculation rather than independent guesses.

## 6. Immersive mode

Immersive mode hides nonessential chrome while preserving:

- canvas navigation;
- an obvious exit path;
- essential tool access or a gesture/command to restore chrome;
- safe-state persistence.

Immersive mode is a presentation state, not a separate workspace architecture.

## 7. Customization policy

The previous accumulation of arbitrary toolbar customization caused layout instability. Future customization shall be constrained.

Allowed customization:

- choose favorite tools/actions;
- reorder within defined slots/groups;
- pin secondary actions to bounded regions;
- save named workspace profiles.

Not allowed:

- arbitrary absolute placement of core controls;
- configurations that remove the only path to exit immersive mode;
- configurations that create inaccessible tools without a documented recovery path;
- unlimited pinned actions in fixed-width regions;
- persistence of obsolete layout schema without migration/fail-closed handling.

## 8. State model

Workspace state should be modeled independently from widget indexes.

Conceptual states:

```text
WorkspaceMode
  compact
  wide
  immersive

Tool
  select
  draw
  shape
  text
  image
  ...

SelectionState
  none
  single
  multiple

PanelState
  closed
  layers
  inspector
  both

ContextActionState
  base
  selection
  text
  toolSpecific
```

Invalid combinations must resolve deterministically rather than producing index errors.

## 9. Geometry contract

One layout coordinator shall own the authoritative usable canvas rectangle.

Inputs:

- viewport width/height;
- orientation;
- safe areas;
- keyboard inset;
- visible panels;
- primary/action bar visibility;
- immersive state.

Output:

```text
CanvasGeometry {
  left
  top
  width
  height
}
```

Every canvas-dependent interaction surface must consume this result instead of independently subtracting panel sizes.

## 10. Accessibility and discoverability

Every icon-only control requires:

- semantic label;
- tooltip/help text where platform-appropriate;
- active/disabled state semantics;
- sufficient touch target;
- keyboard/alternate input path where supported.

The interface must not rely on icon appearance alone for essential operations.

## 11. Regression requirements

The workspace shell must have automated coverage for:

- 320dp-class narrow width;
- current 471px portrait evidence width;
- 1020px landscape evidence width;
- keyboard-visible state;
- immersive mode;
- inspector open/closed;
- layers open/closed;
- maximum allowed pins;
- selection state transitions;
- tool-group transitions;
- orientation transition;
- reset to canonical defaults;
- persisted workspace migration;
- invalid legacy configuration recovery.

The test suite must assert absence of layout overflow and absence of invalid tool-state/index errors.

## 12. Definition of done for the redesign

The workspace redesign is not complete when it merely builds.

It is complete when:

1. one canonical shell replaces competing toolbar architectures;
2. tool identity is independent of visual position;
3. contextual controls adapt to tool/selection state;
4. mobile and landscape layouts share the same state model;
5. customization is bounded and recoverable;
6. canvas geometry has one authoritative source;
7. all regression tests pass;
8. a fresh APK is physically exercised on the Redmi Turbo 4 Pro;
9. the device diagnostics contain no new layout overflow or gesture/state exceptions;
10. documentation records the exact verified behavior and remaining limitations.

## 13. Explicit non-goals

This specification does not prescribe:

- exact colors;
- icon artwork;
- branding;
- copying Vector Ink visual identity;
- a specific Flutter widget hierarchy;
- a specific state-management package;
- desktop-only UI patterns on a phone;
- AI functionality inside the workspace shell.

Those choices belong to later design/implementation decisions.
