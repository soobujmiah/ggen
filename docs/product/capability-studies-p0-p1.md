# GGEN P0/P1 Capability Studies

**Status:** Architecture / documentation baseline
**Date:** 2026-08-24
**Purpose:** Turn the tool inventory into implementation-grade contracts for future coding agents. This document does not authorize implementation by itself.

## 1. Contract rules

Every capability MUST preserve GGEN's authoritative project state. AI providers may propose content or operations; they do not own the document model, undo history, persistence, or final validation.

Every implementation MUST support, where applicable:

- deterministic validation before mutation;
- undo/redo through the canonical command/history mechanism;
- cancellation for long-running work;
- bounded memory/time/resource use;
- manual operation without AI/network;
- explicit provenance for generated/imported content;
- safe import/export boundaries;
- testable behavior and evidence;
- provider-neutral AI integration;
- accessibility and mobile-friendly interaction without sacrificing computer-quality capability.

Reference quality is based on established professional patterns rather than UI copying. Illustrator demonstrates precision path editing, anchor manipulation, Shape Builder and Pathfinder workflows. citeturn0search10 Krita demonstrates layered raster/vector composition, masks, brush engines and resource management. citeturn0search1turn0search9 PDF work should target PDF 2.0 as the modern reference and treat Tagged PDF/PDF-UA as first-class accessibility requirements. citeturn0search2turn0search4

---

## 2. P0 — Canvas / Select / Transform

### Purpose
Authoritative manipulation surface for every editable object.

### Required model
- stable object IDs;
- parent/group relationship;
- local and document-space transforms;
- selection set;
- z-order;
- bounding geometry;
- visibility/lock state;
- snapping metadata where supported.

### Operations
Select, multi-select, marquee, move, scale, rotate, duplicate, delete, group/ungroup, reorder, align/distribute, constrain, snap, nudge.

### Acceptance criteria
- no operation creates an invalid transform or orphan reference;
- all mutations are undoable/redoable;
- multi-selection behaves atomically;
- hit testing remains deterministic;
- transforms preserve object identity;
- keyboard, pointer and touch paths map to the same semantic commands;
- selection state never becomes authoritative document content.

### Performance target
Interactive manipulation must remain responsive on the authoritative Android device with representative document sizes; exact thresholds must be established by benchmark evidence rather than guessed.

---

## 3. P0 — Vector / Bezier

### Required primitives
Path, line, polyline, cubic/quadratic curve where supported, compound path, fill, stroke, gradient, transform.

### Professional requirements
- anchor insertion/deletion;
- corner/smooth conversion;
- handle editing;
- path continuation;
- boolean operations;
- shape construction;
- stroke/fill editing;
- SVG-compatible interchange where practical.

Illustrator's current documented workflow confirms anchor editing, Direct Selection, Shape Builder and Pathfinder as important professional patterns. citeturn0search10

### Acceptance criteria
- geometry is deterministic and serializable;
- booleans do not silently destroy source objects unless explicitly requested;
- invalid/self-intersecting geometry is handled predictably;
- import/export round trips are tested;
- zoom-independent precision is preserved.

---

## 4. P0 — Typography

### Required capabilities
Text object, font reference, size, weight/style, tracking, leading, alignment, paragraph properties, wrapping, baseline/position, text selection/editing.

### Future capabilities
Text-on-path, variable fonts, OpenType features, multilingual shaping, RTL/Bangla quality, font fallback and embedding/substitution policy.

### Critical architecture rule
A text object stores semantic text and font references; it must not depend on rasterized screenshots for editability.

### Acceptance criteria
- text remains editable after save/load;
- font absence is explicit, not silently substituted without provenance;
- Unicode and Bangla text round-trip correctly;
- layout changes are deterministic for the same font/runtime inputs;
- export preserves text semantics whenever the target format permits.

---

## 5. P0 — Raster / Layers / Masks

Krita's documented architecture demonstrates the value of explicit paint, vector, group, clone, filter and mask layers. citeturn0search1turn0search6

### Required capabilities
- raster/paint layers;
- groups;
- alpha/transparency masks;
- non-destructive filters where supported;
- blend modes;
- opacity;
- clipping/containment;
- layer reorder/duplicate/merge;
- basic brush/eraser pipeline.

### Acceptance criteria
- layer ordering is deterministic;
- masks remain editable;
- destructive operations require explicit commands;
- large images are bounded against memory exhaustion;
- imported raster data is validated before allocation;
- undo does not require unbounded full-image snapshots.

---

## 6. P0 — OCR

### Architecture
GGEN exposes `ocr.extract`; the provider may be LAI, cloud, or another endpoint. OCR output is a proposal that must be represented with confidence/provenance and optionally converted into editable document objects.

### Required output
- recognized text;
- page/region coordinates;
- confidence where available;
- language/script metadata;
- provider/model identity;
- optional structured blocks (paragraph/table/line/word).

### Acceptance criteria
- source image/PDF is never overwritten by OCR;
- low-confidence output is visibly distinguishable;
- Bangla and mixed-script text are first-class test cases;
- repeated runs can be compared;
- OCR failures are recoverable and do not corrupt the project.

---

## 7. P0 — Document / PDF

### Required model
Page, dimensions, margins, text blocks, graphics, images, reading order and metadata must remain distinct concepts.

### PDF requirements
- import/render;
- page insertion/deletion/reordering;
- text/image/graphic placement;
- annotations where supported;
- export;
- metadata;
- validation/preflight architecture.

### Accessibility
Tagged PDF is essential for accessible document structure. PDF/UA-2 (ISO 14289-2:2024) is the current PDF 2.0 accessibility standard; PDF Association guidance recommends ISO 32000-2:2020 as the PDF development reference. citeturn0search0turn0search2turn0search8

### Acceptance criteria
- page content is not reduced to screenshots unless explicitly rasterized;
- reading order/structure is retained where possible;
- export failures never silently produce a corrupt artifact;
- PDF/A and PDF/UA are validation targets, not marketing claims without evidence.

---

## 8. P1 — AI Image Generation / Editing

### Contract
`image.generate` and `image.edit` MUST be provider-neutral.

Input may include prompt, reference images, masks, seed/options and generation constraints. Output MUST include artifact identity, provenance and provider/model metadata.

### GGEN responsibilities
- user intent and project context;
- input validation;
- preview;
- acceptance/rejection;
- insertion into project;
- undo/redo;
- provenance.

### Provider responsibilities
- model execution;
- inference/runtime;
- GPU/NPU/CPU scheduling;
- model lifecycle.

### Acceptance criteria
- generated pixels never silently replace editable source;
- asynchronous jobs are cancellable;
- provider failures are surfaced as structured errors;
- generated assets can be regenerated without losing project state.

---

## 9. P1 — Batch / Data Merge

### Required capabilities
Dataset import, schema validation, template binding, preview, batch execution, per-item result/error state, export package.

### Safety
- bounded row count and payload size;
- explicit field mapping;
- deterministic ordering;
- resumable job state;
- partial failure isolation.

### Acceptance criteria
One bad row must not invalidate unrelated completed rows. A batch run must be reproducible from a saved input snapshot, template revision and provider/configuration receipt.

---

## 10. P1 — Workflow

### Model
A workflow is a typed DAG/command graph, not arbitrary executable code.

Nodes may represent document commands, transforms, AI capabilities, imports/exports and validation steps.

### Required properties
- typed inputs/outputs;
- explicit dependencies;
- cancellation;
- retry policy;
- bounded concurrency;
- provenance;
- dry-run/preview where meaningful;
- deterministic serialization.

### Security
Arbitrary shell/network execution MUST NOT be implicitly available to a document workflow. Privileged execution belongs behind explicit capability boundaries and, where appropriate, LAI.

---

## 11. P1 — Plugin / Extension System

### Goals
Extend tools without turning the application core into an unbounded dependency surface.

### Contract
Plugin manifest, stable API version, declared capabilities, permissions, lifecycle, resource limits, compatibility range and provenance.

### Rules
- least privilege;
- no implicit access to credentials;
- no unrestricted project/network/filesystem access;
- plugin failures isolated from core state;
- versioned API;
- deterministic uninstall/disable behavior.

---

## 12. P0 — AI Provider Router

### Provider-neutral capabilities
- `text.generate`
- `vision.analyze`
- `ocr.extract`
- `image.generate`
- `image.edit`
- `embedding.create`
- `tool.execute`
- `agent.run`

### Router responsibilities
Capability discovery, provider selection, authentication reference handling, timeout/cancellation, fallback policy, result normalization, provenance and error normalization.

### Critical boundary
GGEN MUST NOT embed llama.cpp, Vulkan, QNN, model files, thermal policy or Android privileged automation merely to obtain local AI. Those remain provider/runtime concerns. LAI is the preferred local provider but not a hard dependency.

### Acceptance criteria
- provider can be replaced without changing document semantics;
- offline/manual mode remains functional;
- credentials never enter project files or logs;
- provider-specific errors are normalized;
- fallback cannot silently change a destructive operation's semantics.

---

## 13. P0 — History / Recovery

### Required semantics
Every mutating user-visible command has a reversible history representation where technically possible. Recovery journal must support bounded persistence and crash recovery without replaying arbitrary code.

### Acceptance criteria
- undo/redo is deterministic;
- save/load does not alter semantic history unexpectedly;
- recovery never executes untrusted imported instructions;
- journal size is bounded;
- crash recovery can distinguish committed from incomplete operations.

---

## 14. Implementation order

### Wave A — authoritative editing
1. Canvas/select/transform
2. Vector/Bezier
3. Typography
4. Raster/layers/masks
5. History/recovery

### Wave B — document production
6. Document/PDF
7. OCR
8. Import/export/preflight

### Wave C — intelligent production
9. AI provider router
10. AI image generation/editing
11. Batch/data merge
12. Workflow

### Wave D — ecosystem
13. Plugin system
14. advanced 3D/font/animation capabilities

The ordering deliberately makes AI depend on a stable editable artifact model rather than allowing AI infrastructure to define the product architecture.

## 15. Agent implementation gate

A coding agent may implement a capability only after its study has:

1. identified the authoritative state model;
2. defined the command contract;
3. defined failure/cancellation behavior;
4. defined manual and AI paths;
5. defined persistence/interchange requirements;
6. defined security/resource limits;
7. defined acceptance tests;
8. identified external/professional references;
9. identified evidence required for completion.

A feature is **not complete** because it renders a demo. It is complete only when the contract, implementation, tests, documentation and evidence agree.
