# GGEN Tool & Capability Inventory

**Status:** Architecture/research baseline
**Date:** 2026-08-24
**Owner:** GGEN product architecture

## 1. Purpose

This is the canonical GGEN-side inventory of professional tool families. It distinguishes product intent from current implementation and prevents agents from treating a button, prototype, or documentation claim as a finished professional tool.

The governing product specification defines GGEN as an AI Creative & Document Studio and requires manual-first operation, provider-neutral AI, professional computer-quality semantics, mobile adaptation, plugins, workflows, broad import/export, and evidence-backed status. `docs/product/computer-quality-tool-standard.md` is the release gate for every tool.

## 2. Status vocabulary

- `DESIGNED` — documented contract/UX intent exists.
- `PARTIAL` — some implementation exists, but the professional contract is incomplete.
- `IMPLEMENTED` — core behavior is implemented and tested, but device/production evidence may be incomplete.
- `BUILD_VERIFIED` — CI/build verification completed.
- `DEVICE_VERIFIED` — physical-device behavior verified.
- `PRODUCTION_READY` — all applicable quality gates are satisfied.
- `PLANNED` — product requirement with no meaningful implementation yet.

Current status must never be inferred from filenames or UI presence.

## 3. Tool-family inventory

| Family | Core capabilities | GGEN ownership | AI assist | Current maturity* | Priority |
|---|---|---|---|---|---|
| Select/Transform | select, multi-select, move, resize, rotate, constraints, alignment | GGEN | optional | PARTIAL | P0 |
| Canvas/Viewport | pan, zoom, fit, guides, grid, snapping, viewport state | GGEN | no | IMPLEMENTED/PARTIAL | P0 |
| Layers/Objects | hierarchy, visibility, lock, reorder, grouping, object metadata | GGEN | optional | PARTIAL | P0 |
| Vector shapes | primitives, fills, strokes, gradients, transforms | GGEN | optional | PARTIAL | P0 |
| Pen/Bezier | paths, nodes, handles, compound paths, booleans | GGEN | optional | PLANNED/PARTIAL | P0 |
| Typography | text frames, shaping, styles, layout, bidi/Bangla | GGEN | optional | PARTIAL | P0 |
| Digital painting | brush, eraser, smudge, stabilization, pressure/tilt, presets | GGEN | optional | PLANNED | P1 |
| Raster editing | layers, masks, selections, adjustments, transforms, retouch | GGEN | optional | PLANNED | P1 |
| Image AI | generation, edit, inpaint/outpaint, enhancement, background/object operations | GGEN UX; provider execution external | yes | PLANNED | P1 |
| OCR | document/image text extraction and structured regions | GGEN UX; runtime provider external | yes | PARTIAL/PLANNED | P0 |
| Document Studio | multipage layout, styles, tables, fields, headers/footers | GGEN | optional | PARTIAL | P0 |
| PDF | import/edit/preserve/export/preflight/signatures/codes | GGEN | optional | PLANNED/PARTIAL | P1 |
| Template Studio | editable templates, fields, assets, validation | GGEN | optional | PARTIAL | P1 |
| Batch/Data Merge | CSV/XLSX/JSON mapping, bounded generation, resume/cancel | GGEN | optional | PLANNED | P1 |
| Workflow | visual nodes, versioning, run/pause/resume/cancel/schedule | GGEN | optional; planning may use LAI | PLANNED | P1 |
| Asset Library | assets, metadata, tags, versions, previews, dedupe | GGEN | optional | PARTIAL | P1 |
| Brush/Tool Presets | create/edit/import/export/reset, dynamics and shortcuts | GGEN | no | PLANNED | P1 |
| Font Studio | glyphs, OpenType, kerning, masters/axes, proofing, export | GGEN | optional | PLANNED | P2 |
| 3D DCC | scene graph, modeling, UV, materials, sculpt, rig, animation, render | GGEN shell + native engine | optional | PLANNED | P2 |
| Components/Symbols | reusable design structures and instances | GGEN | optional | PLANNED | P2 |
| Import/Export | universal internal model and format adapters | GGEN | no | PARTIAL | P0 |
| Plugins | tools, panels, providers, formats, workflow nodes, assets | GGEN | no | PLANNED | P1 |
| Command system | command palette, shortcuts, API/workflow invocation | GGEN | no | PARTIAL | P0 |
| History/Recovery | semantic undo, redo, journal, autosave, crash recovery | GGEN | no | PARTIAL | P0 |
| Inspector | typed numeric editing, contextual properties, units | GGEN | optional | PARTIAL | P0 |

*The maturity column is an architecture baseline, not a substitute for test evidence. It should be updated after repository audits and implementation milestones.

## 4. Universal tool contract

Every tool must define:

1. command identity and version;
2. typed input parameters and units;
3. selection/context requirements;
4. manual execution path;
5. AI-assisted path, if any;
6. undo/redo transaction boundary;
7. cancellation semantics;
8. persistence/schema impact;
9. import/export impact;
10. accessibility and input modalities;
11. performance/memory limits;
12. security limits for imported/untrusted data;
13. plugin/workflow exposure;
14. tests and evidence;
15. honest lifecycle status.

The same semantic command should be callable from compact mobile UI, tablet/desktop UI, keyboard/shortcut, command palette, workflow engine and plugin API. This follows the existing computer-quality standard.

## 5. AI boundary

AI is an optional implementation assistant, never the owner of the artifact model. For example:

`background.remove` may be requested by a user, executed by a local/cloud provider, and return a mask; GGEN validates and owns the resulting editable mask/layer.

`ocr.extract` returns text/regions; GGEN owns placement, text frames and document mutation.

`image.generate` returns media plus provider evidence; GGEN owns asset ingestion, placement and project history.

`workflow.plan` may be generated by an AI provider, but the resulting workflow is inert until the user reviews/authorizes it.

## 6. Professional references

Capability research should use mature tools as quality benchmarks, not UI templates:

- vector: Illustrator-class precision and SVG/PDF interoperability;
- raster/photo: Photoshop-class non-destructive editing and color discipline;
- mobile painting: Infinite Painter-class touch/stylus responsiveness;
- 3D: Blender-class depth, topology, scene and recovery semantics;
- font engineering: FontForge-class standards coverage plus modern variable-font workflows;
- document/PDF: professional DTP/PDF preflight and fidelity reporting.

These references inform acceptance criteria only. GGEN's UI, interaction design, branding and implementation remain original.

## 7. Priority implementation order

### P0 — foundation

Select/transform, canvas/viewport, layers/objects, typography, inspector, history/recovery, command system, internal document model, import/export foundation, provider abstraction and OCR contract.

### P1 — professional creative/document production

Vector path editing, raster layers/masks, painting engine, image AI, PDF/document depth, templates, batch/data merge, workflows, assets, plugins.

### P2 — advanced professional systems

Font engineering, 3D DCC, advanced animation/rendering, deeper simulation, advanced interoperability and ecosystem tooling.

## 8. Acceptance rule

A tool is not promoted because a UI button exists. Promotion requires the universal computer-quality gate: manual completeness, precision, non-destructive behavior, input quality, semantic history, performance, interoperability, recovery, accessibility, customization, security, tests/evidence, documentation and honest status.

## 9. Research update rule

When a tool family reaches implementation planning, create a dedicated capability study covering at least three mature/open-source references, compare architecture and file-format behavior, identify licenses/provenance, define GGEN's minimum professional bar, and record what is intentionally not copied.
