# GGEN Mobile Creative & Document Benchmark

**Status:** Research baseline / implementation input
**Date:** 2026-08-23
**Purpose:** Convert external product research into implementation requirements without copying proprietary UI, branding, code, or interaction design.

## 1. Product direction

GGEN is **not** a Vector Ink clone and must not become one. The product is a mobile-first AI Creative & Document Studio. Vector editing is a core creative engine; document/PDF/template design is a second major vertical; raster, AI, workflows, typography/font creation and long-term 3D are additional engines.

The benchmark is used to identify proven capabilities, mobile interaction patterns, quality gaps and opportunities. It does not authorize copying competitor UI or proprietary implementation.

## 2. Mobile vector benchmark

### Vector Ink

Useful capability reference: shape-driven vector editing, Bezier/path workflows, drawing, path/boolean operations, layers, typography, gradients, SVG-oriented workflows and mobile-first creation. It is a direct reference for the problem GGEN is solving: serious vector creation on a touch device.

GGEN lesson: keep the useful vector fundamentals, but improve command discoverability, customization, collision-safe workspace chrome, recovery from floating/docked tool states, and progressive disclosure.

### Infinite Design

Android-focused vector illustration reference. Public 2026 comparisons identify Bezier curves, Boolean operations, snapping, alignment, multiple layer types, structured document control and SVG export as important capabilities.

GGEN lesson: Android-native vector precision matters. Prioritize node/path editing, snapping, alignment, structured layers and clean SVG/PDF handoff.

### Concepts

Vector-based infinite-canvas reference with editable strokes, scalable work, stylus-oriented interaction and strong ideation/planning workflows. It is useful as a reference for infinite canvas and sketch-to-structured-work thinking rather than a traditional page-bound Illustrator replacement.

GGEN lesson: separate **freeform ideation space** from **precision production canvas**. Both can share the UDM and vector engine.

### iPad professional references

Linearity Curve, Affinity Designer 2 and Adobe Illustrator for iPad establish the high end of mobile/tablet vector expectations. Public comparisons highlight touch/Pencil workflows, node/path editing, Boolean/Shape Builder-style operations, typography, masks/gradients, professional export and desktop handoff. Affinity is also a reference for combining vector, pixel and professional production workflows; Concepts is the infinite-canvas specialist.

GGEN lesson: mobile UI should not imply reduced project semantics. Tool quality remains professional while command density adapts to screen size.

## 3. Mobile document/design benchmark

### Adobe Express

Adobe Express is a strong mobile visual-document/template benchmark. Its current mobile capabilities include templates, brand kits, PDF import/edit workflows, text/image editing, styles/themes, multi-page canvas actions, comments, custom templates, copy/paste from Word/Excel/PowerPoint/Google documents with formatting preservation, PDF table import improvements, webpage/table-of-contents features and presentation workflows. Adobe documents Android/iOS mobile support and ongoing navigation improvements.

GGEN lesson: document design should combine page layout, templates, reusable brand assets, multi-page operations, import/reconstruction and rapid contextual actions rather than becoming a basic word processor.

### Acrobat + Express document workflow

Adobe's Android Acrobat integration can create documents from Express templates with editable text/images/themes. Adobe also supports designing new PDF pages from Express templates and inserting them into existing documents on the web.

GGEN lesson: PDF should be a first-class document surface, not merely an export format. Pages, objects, templates and PDF content should remain editable through the internal universal document model.

### Affinity Publisher on iPad

Affinity Publisher is the benchmark for serious page-layout semantics on tablet: text frames, columns, gutters, text flow/auto-flow across frames and pages, placed external documents, PDF placement and print-oriented document setup. It demonstrates that professional mobile publishing needs true page-layout primitives rather than only freeform boxes.

GGEN lesson: implement real page-layout semantics: pages, master/template concepts, text frames, columns, flow chains, margins, bleed, grids, headers/footers, placed assets and print/export settings.

### Canva

Canva is a benchmark for fast template-driven mobile production, reusable brand assets, broad design templates and rapid content creation. It is particularly relevant to the "make a professional deliverable quickly" workflow rather than precision vector editing.

GGEN lesson: templates, asset libraries, styles and brand systems should be first-class, but the underlying document must remain editable and interoperable.

## 4. Capability synthesis

### Vector Studio — priority capabilities

1. Selection/direct selection and multi-select.
2. Pen/Bezier, pencil and stabilized freehand.
3. Node editing and path cleanup.
4. Shapes and Boolean/path operations.
5. Stroke/fill/gradient/pattern.
6. Clipping/masks and transforms.
7. Align/distribute, snapping, guides and grid.
8. Layers/groups/components/symbols.
9. Artboards/pages where appropriate.
10. Typography and text-on-path.
11. SVG/PDF import/export with fidelity reporting.
12. Stylus pressure/tilt and touch gestures.

### Document Studio — priority capabilities

1. Multi-page document model.
2. Text/image/vector/shape/table/QR/barcode/signature/dynamic-field objects.
3. Text frames, columns, gutters and linked text flow.
4. Margins, bleed, guides, grids and page masters/templates.
5. Headers/footers and page numbering.
6. Reusable styles, themes, brand kits and asset libraries.
7. PDF import with editable structure where fidelity permits.
8. DOCX/PPTX/ODT/RTF/HTML/Markdown interoperability.
9. PDF export with print/color/fidelity controls.
10. Template reconstruction from scan/image/PDF using OCR and layout analysis.
11. Data mapping from CSV/XLSX/JSON for bounded batch generation.
12. Comments/review and version/history support.

## 5. GGEN differentiation requirements

The benchmark products demonstrate that no single mobile product combines all desired dimensions cleanly. GGEN should target the intersection:

**precision vector + true document layout + editable PDF + templates/assets + AI assistance + provider independence + offline/manual operation + deep workspace customization.**

The UI must be original. The key differentiator is a canvas-first, adaptive command system where users can choose exactly which commands are visible, where they dock, how dense they are, and how immersive the workspace becomes. Safe-area and navigation-bar collision prevention is mandatory.

## 6. Evidence rules

External research establishes requirements, not implementation completion. A feature is complete only when code, automated tests, device behavior and relevant artifacts/evidence agree. Do not claim parity with any benchmark product without explicit evidence.

## 7. Immediate implementation sequence

### Now

- Preserve the existing working GGEN canvas/layer/shape/text foundation.
- Do not rewrite the product around one competitor.
- Treat toolbar/workspace UX as a cross-cutting infrastructure concern.

### Next vector slice

- Stable UDM vector object schema.
- Selection/multi-select.
- Node/path model.
- Pen/Bezier and pencil/stabilizer.
- Shapes + Boolean operations.
- Stroke/fill/gradient.
- Align/distribute + snapping/guides/grid.
- Layer/group/component semantics.
- SVG import/export fidelity tests.

### Next document slice

- Multi-page UDM.
- Text frames and linked flow.
- Columns/gutters/margins/bleed.
- Master/template pages.
- Image/vector/table/QR/barcode/signature objects.
- PDF import/export fidelity baseline.
- DOCX/HTML/Markdown interoperability adapters.

### Then

- Template/asset/brand systems.
- OCR + editable template reconstruction.
- Structured-data mapping and bounded batch generation.
- AI-assisted vector/document operations.
- Local/cloud/custom endpoint routing.

## 8. UX acceptance standard

Every mobile tool must satisfy:

- No toolbar/panel overlap with project identity or system/navigation surfaces.
- No unreachable floating state.
- Safe-area aware positioning.
- Individual command visibility and ordering.
- Persistent workspace configuration.
- One-action reset to a sane default workspace.
- Progressive disclosure instead of permanent button clutter.
- Touch/stylus precision without sacrificing desktop-quality semantics.
- Immersive canvas mode with minimal chrome.
- No known layout overflow in supported device classes.
