# GGEN Tool Research & Quality Matrix

**Status:** Research baseline for future implementation
**Date:** 2026-08-24

This document records capability references, not copied UI or implementation. GGEN's release bar remains the project-specific `computer-quality-tool-standard.md`.

## Reference families

| GGEN capability family | Mature references / quality anchors | What GGEN should learn | What GGEN must not copy |
|---|---|---|---|
| Vector design | Adobe Illustrator, Inkscape, Affinity Designer, Infinite Design | Bezier precision, booleans, snapping, typography, SVG/PDF fidelity | UI, branding, icons, proprietary implementation |
| Raster/photo | Adobe Photoshop, Affinity Photo, Krita | Layers, masks, selections, non-destructive editing, color management, large-image strategy | UI/layout/branding or proprietary effects implementation |
| Digital painting | Krita, Procreate, Infinite Painter | Low-latency strokes, pressure/tilt, brush engine, stabilization, texture/dynamics | Brush assets, UI identity, proprietary algorithms |
| Layout/publishing | Adobe InDesign, Affinity Publisher, Scribus | Multipage layout, master structures, styles, preflight, print/PDF fidelity | UI or proprietary document engine code |
| PDF/document | Adobe Acrobat, PDFium/Poppler ecosystem, LibreOffice | Object preservation where supported, forms, annotations, accessibility, export fidelity | Proprietary code/assets |
| Font engineering | FontForge, Glyphs, RoboFont | OpenType shaping, glyph/node editing, kerning, masters/axes, validation | UI/branding or proprietary components |
| 3D DCC | Blender, Houdini, Autodesk Maya/3ds Max | Scene graph, modifiers, topology, UV, animation, rendering, recovery | Blender UI or source-derived design |
| Mobile creative | Infinite Design, Infinite Painter, Procreate | Touch/stylus adaptation, gesture ergonomics, progressive disclosure | Mobile UI cloning |
| Template/data production | Canva, Adobe Express, LibreOffice mail merge ecosystems | Template fields, data mapping, bounded batch generation, preview and recovery | Their templates, branding, proprietary assets |

## Universal tool requirements

Every shipped tool must satisfy the GGEN computer-quality release gate:

1. Manual operation works without AI/network/model.
2. Core semantics are precise and deterministic where the domain permits.
3. Undo/redo is transactional; cancellation cannot leave a half-state.
4. Parameters are inspectable and editable.
5. Touch, stylus, mouse and keyboard behavior is specified.
6. Work is non-blocking with bounded memory/disk usage.
7. Import/export behavior and fidelity limits are documented.
8. Persistence, autosave and recovery paths are tested.
9. Accessibility is first-class.
10. Settings/presets/shortcuts use typed contracts.
11. Untrusted input is bounded and validated.
12. Unit/contract/golden/interaction tests exist as appropriate.
13. Device/performance evidence is measured rather than inferred.
14. Documentation records purpose, parameters, limitations, file effects and evidence.

## AI augmentation rule

AI can propose or accelerate work but cannot replace the underlying professional command. AI output must remain inspectable, editable and undoable. Private content must not leave the device without explicit routing permission.

## Research status vocabulary

- `REFERENCE`: established external quality anchor.
- `DESIGNED`: GGEN contract exists.
- `IMPLEMENTED`: source exists.
- `BUILD_VERIFIED`: CI proves the implementation builds/tests.
- `DEVICE_VERIFIED`: physical-device evidence exists.
- `PRODUCTION_READY`: all applicable quality gates pass.

A reference product is never evidence that GGEN has implemented the capability.

## Research rule for agents

Before implementing a major tool, the agent shall inspect the relevant quality family, compare at least two mature references, document the intended GGEN semantics, define imports/exports and security/resource limits, define tests, and only then modify code. Research may inform quality; it does not authorize feature implementation by itself.
