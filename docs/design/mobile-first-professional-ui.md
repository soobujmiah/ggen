# Mobile-Friendly Professional UI

## Non-negotiable rule

**Computer-quality capability is mandatory; mobile-friendly interaction is equally mandatory.** GGEN must not become a simplified mobile toy, and it must not squeeze a desktop interface onto a phone.

The underlying document, scene, font, vector, raster and tool models keep desktop-grade precision. The presentation adapts to screen, posture and input device.

## Adaptive workspace classes

### Compact phone

- full-screen canvas with edge-to-edge safe insets;
- one primary contextual tool rail at a time;
- bottom or side quick controls reachable by thumb;
- inspector as a searchable sheet with pinned favorites;
- long-press/radial/command-palette access to less frequent commands;
- two-finger canvas pan/zoom/rotate separated from one-pointer tool input;
- numeric entry and exact constraints always available;
- transient panels preserve canvas state and never force destructive mode changes.

### Foldable / tablet

- dockable tool rail, layers and inspector;
- split preview/reference/document panes;
- stylus hover/pressure/tilt where reported;
- detachable keyboard and mouse shortcuts;
- panel presets for painting, vector, font, document and 3D workflows.

### Desktop window (future Flutter target)

- multi-panel and multi-window workspace;
- complete keyboard/mouse context menus and shortcuts;
- larger inspectors/timelines/node editors;
- same project/tool commands as mobile—not a separate lower-compatibility product.

## Interaction requirements

- Minimum touch targets follow accessibility guidance even when icons are visually compact.
- Canvas handles scale in screen space and support precision zoom; they do not become impossible to touch at large/small document scales.
- Stylus drawing does not trigger touch gestures; palm rejection uses platform capability rather than guesses.
- Every gesture has a discoverable command/menu alternative.
- Every keyboard shortcut has conflict detection and editable profiles.
- Context mode and destructive effects are always visible.
- Back/system navigation never discards work; pending sessions prompt or safely cancel.
- Heavy tasks show progress, stage, cancellation and background/resume behavior.
- Reduced motion, font scaling, contrast, screen readers and left/right-handed layouts are first-class.

## Professional mobile patterns

- **Contextual density:** show parameters relevant to the active tool while keeping all advanced parameters searchable.
- **Progressive precision:** quick drag for speed, tap numeric value for exact input, modifiers/constraints for experts.
- **Workspace presets:** Painting, Photo, Vector, Font, Document, 3D Modeling, Sculpting, Animation and custom arrangements.
- **Command palette:** universal searchable access so hidden compact UI never means missing capability.
- **Quick favorites:** user pins tool parameters/actions without changing tool semantics.
- **Before/after and preview quality:** low-resolution progressive previews are labeled; final render never silently uses preview quality.

## Overlay chrome rules (2026-08-22 device feedback)

The shell chrome follows a zero-chrome overlay model on the canvas:

- **Top action bar is transparent and title-less.** No AppBar background and
  no title: only icons, drawn INSIDE the canvas bounds at the status-bar
  boundary, in the contrast color of the surface they float over (white
  icons with a soft shadow over the dark canvas). Project actions therefore
  never consume layout space and never cover the artwork with a bar.
- **Everything lives behind More.** Every top-level action (New, Save,
  Settings, Diagnostics, Immersive, Dock inspector) sits inside the More
  menu by default; the menu is a bottom sheet showing the actions in a
  user-configurable order. Tapping a row runs the action; the star toggles
  whether the action is pinned to the bar; the up/down arrows reorder the
  menu. Pinned actions render left of the More button, in user order, and
  the choice plus order persist in workspace preferences (sanitized,
  bounded, fail-closed).
- **No hidden AppBar actions anywhere** (the wide "dock inspector"
  affordance also lives in More).
- **Secondary canvas toolbar is fully configurable.** Three levels: full
  (multi-select / undo-redo / layers / grid / zoom row), mini (compact
  essentials strip: undo, redo, zoom +/−, fit, expand) and hidden (NO
  remnant — the canvas gets the full height, per device feedback "hiding
  leaves a strip, so what's the point"). Three docks: bottom (floating
  strip above the navigation bar), left and right (vertical floating
  strip over the canvas edge, below the top bar). The strip is
  transparent (each button carries its own translucent circular
  background), the level and dock persist across launches, and the
  level is also reachable from the More menu ("Canvas toolbar" toggles
  hidden/full, "Dock canvas toolbar" cycles bottom → left → right).
  The bottom navigation bar stays fixed in normal mode; in fullscreen
  every bar is hidden except the top bar, whose actions are all
  hideable and rearrangeable from More.
- **Bottom navigation is tools-only.** Select / Draw / Text remain; the
  Settings tab moved into More (either behind the menu or pinned out to the
  bar by the user).
- **Default artboard is portrait, device-ratio sized.** New projects create
  a portrait canvas (1080 wide, height = width x screen ratio, clamped to
  1:1 .. 9:20) instead of a fixed landscape 1200x800 — phone-first content
  starts on a canvas that matches the display.
- **Fit-to-screen is edge-to-edge.** The fit margin is 0 so the artboard
  spans the full viewport on its limiting axis ("fit must match the screen
  resolution; no gap on the sides").
- **Every action keeps a discoverable path:** anything unpinned is one tap
  away in More; nothing exists only behind a hidden bar or a keyboard
  shortcut.

## Performance targets

Targets are established per device class and measured, not assumed. Interactive canvas reports frame-time percentiles and input latency. When resource pressure rises, GGEN may reduce preview resolution/LOD with a visible indicator, but preserves final-quality settings and project data.

## Design originality

These principles are derived from GGEN's requirements. Do not copy BG, RGEN, Blender, FontForge, Photoshop, PicsArt, Illustrator, Infinite Design or Infinite Painter screen layouts, icons, colors, terminology arrangement or branding. Reference products define capability expectations only.
