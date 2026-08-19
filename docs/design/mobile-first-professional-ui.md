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

## Performance targets

Targets are established per device class and measured, not assumed. Interactive canvas reports frame-time percentiles and input latency. When resource pressure rises, GGEN may reduce preview resolution/LOD with a visible indicator, but preserves final-quality settings and project data.

## Design originality

These principles are derived from GGEN's requirements. Do not copy BG, RGEN, Blender, FontForge, Photoshop, PicsArt, Illustrator, Infinite Design or Infinite Painter screen layouts, icons, colors, terminology arrangement or branding. Reference products define capability expectations only.
