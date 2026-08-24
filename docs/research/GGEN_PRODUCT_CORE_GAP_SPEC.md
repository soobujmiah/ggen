# GGEN Product Core — Research-to-Engineering Gap Specification

**Status:** Active engineering planning baseline
**Date:** 2026-08-24
**Scope:** Vector, raster, 3D, document/PDF, typography, templates/brand

## Rule

This document converts the cross-project SKB gap matrix into GGEN-specific engineering targets. It does not duplicate LAI runtime/provider research.

## 1. Vector

**Benchmark family:** Infinite Design, Concepts, Vector Ink, professional vector editors.

**Target:** production-quality mobile vector editing with deterministic geometry and export.

**Priority gaps to verify in source before implementation:**
- node/path editing;
- Bézier handles;
- boolean operations;
- snapping/guides/alignment;
- grouping/locking;
- transforms and precision controls;
- stroke/fill/gradient fidelity;
- text-on-path;
- SVG import/export fidelity;
- undo/redo and selection semantics;
- touch/pen ergonomics.

**Engineering rule:** preserve existing canvas/document architecture; do not replace working foundations without evidence.

## 2. Raster/image editing

**Benchmark family:** Infinite Painter, ibisPaint, Krita, Adobe-class workflows.

**Target:** non-destructive mobile raster workflow integrated with GGEN assets.

**Gap checklist:**
- layer compositing;
- masks/selections;
- crop/transform;
- brush/stroke pipeline;
- filters/adjustments;
- opacity/blend modes;
- image import/export;
- resolution/color-management behavior;
- undo/redo and memory pressure;
- large-image performance.

AI editing is a GGEN UX concern but execution remains LAI-owned.

## 3. 3D

**Benchmark family:** Nomad Sculpt, Prisma3D, Blender-class references.

**Target:** useful Android-first 3D creation, not a premature Blender clone.

**Capability decomposition before coding:**
1. scene/document model;
2. primitive/object creation;
3. transform/navigation;
4. mesh editing;
5. sculpting;
6. materials/textures;
7. lighting/camera;
8. animation/rigging;
9. import/export (GLB/GLTF/OBJ and other justified formats);
10. rendering/preview;
11. touch/pen interaction;
12. asset library.

Each sub-capability requires separate research and maturity evidence.

## 4. Document/PDF

**Benchmark family:** Acrobat, Xodo, Foxit, Microsoft 365/WPS/Collabora.

**Target:** one coherent document model that can author, lay out, import, annotate and export without treating PDF as merely an image format.

**Gap checklist:**
- pagination;
- styles;
- linked text flow;
- multi-column layout;
- tables;
- headers/footers;
- media;
- annotations;
- forms where justified;
- OCR insertion;
- PDF import/export fidelity;
- font embedding/substitution;
- accessibility metadata where feasible.

Do not introduce a second document model for PDF without architecture review.

## 5. Typography

**Benchmark family:** professional publishing/design tools + Android font/text shaping ecosystem.

**Target:** predictable high-quality multilingual typography.

**Gap checklist:**
- shaping;
- script-aware line breaking;
- font fallback;
- variable fonts;
- OpenType features;
- kerning/ligatures;
- baseline/alignment;
- text measurement;
- export consistency;
- Bangla-specific rendering validation.

Typography is foundational infrastructure for both vector and document workflows; prioritize it before cosmetic editor features.

## 6. Templates and brand system

**Benchmark family:** Canva, Adobe Express, presentation/template products.

**Target:** reusable structured creative assets rather than screenshot-like templates.

**Required model concepts:**
- template metadata/version;
- editable slots;
- design tokens;
- colors;
- typography roles;
- spacing/layout rules;
- locked vs editable elements;
- asset references;
- responsive/adaptive variants;
- provenance/licensing metadata.

## Cross-cutting acceptance gates

Every implemented capability must have:

1. research evidence;
2. current-state audit;
3. explicit maturity state;
4. specification before implementation;
5. automated tests where practical;
6. device/UI validation where applicable;
7. import/export or persistence tests where applicable;
8. performance/memory evidence for heavy media;
9. no duplicate runtime/provider/tool authority;
10. commit → push → remote verification → SHA.

## Agent instruction

Before implementing a row, the agent must inspect the live GGEN repository and this document, search SKB for related research, and verify that the proposed work is not already implemented. If benchmark evidence or current implementation changes the gap, update the specification first.
