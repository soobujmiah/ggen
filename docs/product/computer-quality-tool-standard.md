# Computer-Quality Tool Standard

## Owner directive

Every GGEN creative tool must target **desktop/professional quality**, adapted intelligently to phone, tablet, stylus, mouse and keyboard. Reference quality categories include mature 3D DCC, font engineering, raster/photo, vector design, digital painting, document layout and PDF software. These products are capability/quality references only; GGEN must not copy their UI, branding, icons, layout, workflows verbatim or protected implementation.

“Computer quality” does not mean claiming complete parity at launch. It means every shipped tool has professional semantics, precision, reliability and evidence; reduced mobile controls may change presentation but not corrupt the underlying model.

## Universal release gate for every tool

A tool is not production-ready until it has:

1. **Manual completeness:** core operation works without AI, network or model.
2. **Precision:** numeric inspector, units, snapping/constraints where relevant, deterministic geometry and no hidden rounding.
3. **Non-destructive path:** operation supports editable parameters, masks/modifiers/history where the domain allows; destructive apply is explicit.
4. **Input quality:** touch, stylus, mouse and keyboard behavior is specified; pressure/tilt/hover/buttons are used only when hardware reports them.
5. **Undo/redo:** one semantic operation creates one reversible transaction; cancellation leaves no half state.
6. **Performance:** frame/task budgets, progressive preview, background work, memory admission and real measurements.
7. **Interoperability:** documented import/export mapping and fidelity report; unsupported data is never silently lost.
8. **Persistence/recovery:** autosave, crash journal and schema migration tests.
9. **Accessibility:** keyboard reachability, semantics, focus, contrast, scaling and reduced motion.
10. **Customization:** parameters, presets, shortcut, gesture and defaults use typed settings.
11. **Security:** untrusted inputs are bounded; canonical paths and resource policies apply.
12. **Tests/evidence:** pure tests, golden/contract tests, interaction tests and physical-device evidence where applicable.
13. **Documentation:** purpose, parameters, limitations, file effects, performance scope and examples.
14. **Honest status:** `DESIGNED`, `IMPLEMENTED`, `BUILD_VERIFIED`, `DEVICE_VERIFIED`, `PRODUCTION_READY`; no skipped state.

## Quality families

### 3D DCC quality bar

Professional scene graph/dependency model, exact transforms, modeling topology, modifiers, UV/materials, sculpt/paint, rigging/animation, render/composite, interoperability, large-scene strategy and recoverability. Blender is a depth/reliability benchmark, not a design template.

### Font engineering quality bar

Standards-correct shaping, glyph outlines/components/anchors, metrics/kerning/OpenType features, masters/variation, script proofing, validation and deterministic export. FontForge and other mature type tools are capability references, not UI templates.

### Raster/photo quality bar

Color-managed, high-bit-depth-capable architecture; selections/masks/layers/blends/adjustments, retouching, transforms, filters, non-destructive history, large-image tiling and predictable export. Photoshop/PicsArt represent different professional and mobile usability expectations; neither UI is copied.

### Vector quality bar

Exact Bezier/node editing, compound paths/booleans, strokes/fills/gradients, transforms/align/snapping, artboards/symbols/components, typography and SVG/PDF fidelity. Illustrator and Infinite Design are capability references only.

### Digital painting quality bar

Low-latency stroke engine, spacing/smoothing/stabilization, pressure/tilt/velocity dynamics, texture/scatter, blend/wet-media roadmap, brush libraries/presets, symmetry/assistants, canvas rotation and large-canvas management. Infinite Painter is a capability/interaction quality reference only.

### Document/PDF quality bar

Multipage layout, master structures/styles, tables/fields, preflight, bleed/print/color, tagged/accessibility strategy, exact typography, data merge, PDF object preservation/editing where supported, signatures/QR/barcodes and fidelity reports.

## Mobile adaptation rule

The same domain command must be invokable from compact touch UI, tablet panels, keyboard shortcut, command palette and plugin/workflow API. Responsive UI may hide panels behind context, but must not create a lower-quality data model.

## AI rule

AI may propose selections, masks, designs, retouching, topology, layouts, fonts, materials or workflows. Results remain editable and reviewable. AI never replaces the manual command, bypasses history, silently uploads private content, or converts an uncertain suggestion into a verified result.
