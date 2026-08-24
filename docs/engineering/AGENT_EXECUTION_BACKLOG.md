# GGEN Agent Execution Backlog

**Status:** Ready for agent execution
**Date:** 2026-08-24
**Scope:** product-core engineering after research/architecture gates

## Execution contract

Each task is atomic. Before starting: read SKB ownership matrix + research protocol + GGEN product-core gap spec, inspect live code/tests, and verify the gap still exists. Do not duplicate LAI runtime/provider/tool infrastructure.

Completion requires tests/evidence, documentation update when behavior changes, commit, push, remote verification and recorded SHA.

## P0 — Preserve architecture

### GGEN-P0-01 — Capability contract freeze
- Reconcile GGEN capability IDs and request/response types with LAI.
- Remove/mark any GGEN-local runtime assumptions.
- Acceptance: contract document and tests agree; no provider-specific objects cross boundary.

### GGEN-P0-02 — AI integration client boundary
- Implement only the minimal GGEN-side client/adapter required to consume LAI.
- Acceptance: manual workflows work without LAI; unsupported capability fails visibly and safely.

## P1 — Product foundations

### GGEN-P1-01 — Typography quality audit
- Audit shaping, fallback, variable fonts, OpenType behavior, measurement and Bangla rendering.
- Produce evidence and implement only verified gaps.
- Acceptance: regression tests + representative Bangla/Latin/mixed-script validation.

### GGEN-P1-02 — Vector editor gap closure
- Audit node/path editing, Bézier handles, boolean operations, snapping, transforms, gradients, text-on-path and SVG fidelity.
- Implement highest-value verified gaps incrementally.
- Acceptance: interaction tests + SVG round-trip tests + no regression in existing canvas.

### GGEN-P1-03 — Raster foundation audit
- Audit layers, masks/selections, transforms, brushes, filters, blend modes, import/export and large-image memory behavior.
- Implement only gaps supported by benchmark and source evidence.
- Acceptance: image workflow tests + memory/performance evidence.

### GGEN-P1-04 — Document/PDF convergence
- Audit the existing document model against pagination, linked text, columns, tables, headers/footers, media, annotations and PDF import/export.
- Do not create a second PDF document model.
- Acceptance: representative document/PDF round-trip tests.

### GGEN-P1-05 — Template/brand schema
- Define structured templates, editable slots, design tokens, locked/editable elements, asset references and versioning.
- Acceptance: create/edit/save/reopen template fixture with stable schema.

### GGEN-P1-06 — 3D capability spike
- Research and validate one narrow vertical slice using Nomad Sculpt/Prisma3D-informed UX: scene + primitive + transform + camera/navigation.
- Do not begin a full 3D suite.
- Acceptance: documented device performance and architecture decision for next 3D slice.

## P2 — AI-powered creative features

### GGEN-P2-01 — Text generation UX
- Consume LAI `text.generate`; implement user-facing context/constraint/result presentation only.
- Acceptance: provider-neutral integration; manual workflow remains independent.

### GGEN-P2-02 — OCR integration UX
- Consume LAI `ocr.extract`; map confidence/provenance into document workflow.
- Acceptance: source references preserved; no OCR engine duplicated in GGEN.

### GGEN-P2-03 — Image generation integration
- Consume LAI `image.generate`; map generated assets into GGEN asset/document model.
- Acceptance: provider-neutral UX and reproducible asset provenance.

### GGEN-P2-04 — AI image editing UX
- Consume LAI `image.edit`; own masks/selections/result presentation and undo semantics.
- Acceptance: non-destructive workflow; execution remains LAI-owned.

## Definition of Done

A task is complete only when:
- the claimed gap was verified against live code;
- research/benchmark evidence is recorded;
- ownership is correct;
- implementation is scoped to GGEN;
- tests/evidence pass;
- docs are synchronized;
- Git commit exists;
- remote branch is updated;
- remote state is verified;
- SHA is recorded.

## Ordering

Do not skip P0. Within P1, prioritize typography → document/canvas stability → vector/raster → templates → 3D spike. P2 begins after the contract and relevant product foundation are stable.
