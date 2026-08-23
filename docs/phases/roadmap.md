# Development roadmap

The master sequence remains documentation-first. GGEN is an independent **AI Creative & Document Studio**, not a Vector Ink clone or generic mobile drawing app. Vector Studio and Document Studio are the immediate professional foundations. External products are capability/quality references only; their UI, branding, code and proprietary interaction design are not copied.

Research baseline: `docs/research/mobile-creative-document-benchmark.md`.

Target intersection: **precision vector + true document layout + editable PDF + templates/assets + AI assistance + provider independence + offline/manual operation + deep workspace customization.**

## Phase 0 — Audit, architecture, environment and governance

Reference audits, protected assets, licensing, architecture/interfaces, hybrid brain/environment YAML, security limits, test/evidence policy, font/3D architecture and owner decisions. No major application implementation.

## Phase 1 — Core/manual document vertical slice

UDM v1, assets, settings, projects, undo/history/autosave/recovery, job runtime, plugins foundation, secure storage boundaries, original Flutter canvas shell. First slice: one manual offline page with text/image/vector shape/layers/transforms and PDF/PNG fidelity report.

Research-derived acceptance: the UDM must support both freeform vector objects and true page-layout semantics. Document foundations must include pages, text frames, images, vector objects, margins, bleed, guides and future linked text flow without coupling the model to one output format.

## Phase 2 — 2D creative engines

Vector/raster canvas, selection, typography integration, layers, masks, brushes, color and non-destructive operations.

### Phase 2A — Vector Studio priority slice

1. Selection/direct selection and multi-select.
2. Pen/Bezier, pencil and stabilized freehand.
3. Node/path model and cleanup.
4. Shapes + Boolean/path operations.
5. Stroke/fill/gradient/pattern.
6. Clipping/masks and transforms.
7. Align/distribute + snapping/guides/grid.
8. Layers/groups/components/symbols.
9. Artboards/pages as appropriate.
10. Typography and text-on-path.
11. SVG/PDF import/export with fidelity evidence.
12. Touch/stylus pressure/tilt and gesture semantics.

### Phase 2B — Professional mobile workspace

1. Adaptive command bar with individual command visibility and ordering.
2. Bottom/left/right/floating modes with hard safe-area bounds.
3. No collision with project identity or system/navigation surfaces.
4. No unreachable floating state; one-action reset/recovery.
5. Persistent workspace profiles and progressive disclosure.
6. Immersive canvas mode with minimal chrome.
7. Accessibility and touch/stylus precision.
8. Zero known layout overflow on supported device classes.

## Phase 3 — Document Studio professional layout

1. Multi-page UDM and page management.
2. Text frames, columns, gutters and linked text flow.
3. Margins, bleed, guides, grids and master/template pages.
4. Headers/footers and page numbering.
5. Images, vectors, tables, QR/barcodes, signatures and dynamic fields.
6. Reusable styles, themes, brand kits and asset libraries.
7. PDF import with editable structure where fidelity permits.
8. PDF export with print/color/fidelity controls.
9. DOCX/HTML/Markdown/ODT/RTF interoperability adapters.
10. Template reconstruction: scan/image/PDF → OCR → layout/object/typography analysis → editable structure.
11. Review/comments/version/history semantics.

## Phase 4 — Font Creation Studio program

1. HarfBuzz-class shaping, fallback, variable-font and typography inspector.
2. Font project schema, glyph browser, outline/node/metrics editor.
3. Components, anchors, kerning classes and OpenType features.
4. Masters, variable axes/interpolation and proofing.
5. Validated TTF/OTF/WOFF2/UFO/designspace workflows.

## Phase 5 — 3D DCC program

1. Native-engine feasibility: scene graph, PBR viewport, glTF, picking/transforms and frame evidence.
2. Mesh modeling, modifiers, materials, UV and 3D assets.
3. Sculpt/paint/retopology and 3D brush system.
4. Rigging, animation, curves/timeline and sequencing.
5. Offline renderer, render passes, compositing and bounded worker protocol.
6. Procedural geometry, simulations, production interoperability and plugins.

Every 3D stage must be independently useful. Blender-quality is a quality target, not an early parity claim.

## Phase 6 — BG image-processing adapter

Segmentation/background/enhancement through evidence-aware image contracts, real timing and explicit bitmap/resource ownership.

## Phase 7 — RGEN protected document adapter

Read-only verified protected templates/assets, certificate/routine/testimonial contracts, bounded CSV/XLSX streaming batch generation and layout regressions.

## Phase 8 — Local AI

Model registry/lab, router, CPU/GPU/NNAPI/QNN adapters and physical-device evidence.

## Phase 9 — Cloud/custom AI

Provider adapters, custom endpoints, secure credentials, privacy/cost approval and structured evidence.

## Phase 10 — AI creative tools

Image generation/editing, editable document generation, template reconstruction, font/3D AI assistants that always produce reviewable/manual structures where possible.

## Phase 11 — Workflow automation

Visual workflow editor/runtime, AI-proposed workflows, checkpointed batches, scheduling and worker routing.

## Phase 12 — Universal export and interoperability

Progressive PDF/SVG/PNG/JPEG/WebP/DOCX/PPTX/HTML/data/native/font/3D adapters with fidelity reports.

## Phase 13 — Professional hardening

Original adaptive UX, accessibility, keyboard/stylus, performance, security fuzzing, recovery, signed releases, SBOM/provenance and device matrix.

## Sequencing rule

Font and 3D architecture is approved as scope, not permission to begin both engines immediately. Phase 1 must first validate the project/job/storage/history/plugin/UDM foundation they depend on. Vector and document professional slices are now the immediate product work; AI, font and 3D build on those foundations.