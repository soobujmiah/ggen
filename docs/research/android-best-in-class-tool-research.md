# GGEN Android Best-in-Class Tool Research

**Status:** Research baseline / agent guidance
**Date:** 2026-08-24
**Scope:** Android-first creative, design, document and media capabilities that GGEN may own.

## 1. Purpose

This document expands the generic best-in-class research into an **Android-specific benchmark layer**. It is intended for AI agents and engineers deciding what GGEN should BUILD, ADAPT, INTEGRATE, or REJECT.

Android apps are benchmarks, not dependencies. A benchmark is selected because it demonstrates a strong workflow, interaction model, file model, or mobile constraint solution. GGEN must not copy proprietary implementation or couple itself to a benchmark app.

## 2. Decision vocabulary

- **BUILD** — GGEN should own the capability and implement the product behavior.
- **ADAPT** — adopt a proven interaction/model pattern while implementing it in GGEN's architecture.
- **INTEGRATE** — use an external/open-source/library/service capability where ownership is unnecessary.
- **PROVIDER** — consume execution from LAI or another external capability provider.
- **REJECT** — benchmarked behavior is not worth reproducing or conflicts with GGEN's architecture.

## 3. Benchmark matrix

| Capability | Android benchmark set | Strong pattern to study | GGEN target | Decision |
|---|---|---|---|---|
| Vector illustration | Infinite Design, Concepts, Vector Ink, TouchDraw | Bézier/path editing, node control, snapping, infinite canvas, SVG/PDF export | Professional vector workspace with precise touch/stylus interaction and structured SVG | BUILD + ADAPT |
| Sketch/painting | Infinite Painter, Sketchbook, ibis Paint X, Krita, Clip Studio Paint | Brush engine, pressure/tilt, layers, stabilizers, masks, tablet UX | Raster engine with professional brush/layer workflow | BUILD + ADAPT |
| Infinite canvas / ideation | Concepts | Vector strokes, infinite canvas, non-destructive editing, stylus-first UX | Optional infinite canvas mode sharing GGEN document model | ADAPT |
| Diagram / technical drawing | TouchDraw, Grapholite, Concepts | snapping, connectors, geometry, structured objects | Structured diagram objects and connectors | BUILD + ADAPT |
| 3D sculpting | Nomad Sculpt | pressure-sensitive sculpting, multiresolution, voxel remesh, dynamic topology, masks, PBR preview | Mobile-first sculpting interaction; native 3D engine remains GGEN-owned | ADAPT |
| 3D modeling / scene | Prisma3D, 3D Modeling App, Blockbench Android-capable workflows | object/scene management, materials, camera/light, animation | Structured 3D scene model and editor | BUILD + ADAPT |
| 3D CAD | Onshape, AutoCAD mobile-class workflows | constraint-driven modeling, precise geometry, cloud/project model | Integrate/target CAD interoperability rather than duplicate full CAD initially | INTEGRATE + ADAPT |
| PDF reading/markup | Xodo, Adobe Acrobat, Foxit, PDFgear | fast navigation, annotations, forms, signing, page operations | Native document/PDF workflow integrated with GGEN model | BUILD + ADAPT |
| PDF text editing | PDFgear, Foxit, Acrobat, iLovePDF | editable text, page manipulation, OCR boundary | Semantic PDF editing rather than annotation-only | BUILD + ADAPT |
| Document authoring | Microsoft 365, WPS Office, Collabora Office | structured text, tables, page layout, office-format fidelity | Universal Document Model with rich text/layout | BUILD + ADAPT |
| Presentation | PowerPoint/Microsoft 365, WPS Office, Canva | slide structure, templates, presenter workflow | Presentation as a document specialization | BUILD + ADAPT |
| Spreadsheet/data | Excel/Microsoft 365, WPS Office, Collabora Office | tables, formulas, charts, structured data | Structured tables/charts; avoid rebuilding a full spreadsheet suite initially | BUILD + INTEGRATE |
| OCR/scanning | Adobe Scan, Google Drive scanner, current Android scanning tools | capture cleanup, perspective correction, OCR, PDF creation | OCR capability consumed from LAI; capture/document UX in GGEN | GGEN UX + LAI PROVIDER |
| 2D animation | Alight Motion, FlipaClip, CapCut | timeline, keyframes, layers, effects, touch manipulation | Animation layer/timeline integrated with document model | BUILD + ADAPT |
| Motion graphics | Alight Motion, CapCut | multi-layer timeline, transforms, effects, audio sync | Reusable scene/timeline model | BUILD + ADAPT |
| Image generation/editing | Canva, Adobe Express, current AI image apps | prompt editing, selection/mask-aware edits, object removal/insertion, background generation | Editable asset operations; execution through LAI | GGEN UX + LAI PROVIDER |
| File/asset management | Solid Explorer, Material Files, Files by Google | two-pane browsing, cloud providers, metadata, fast preview | Asset registry + safe import/export; Android storage adapter | BUILD + ADAPT |
| Fonts/typography | Concepts + professional font workflows | font discovery, preview, shaping, OpenType behavior | Typography engine and font registry | BUILD + INTEGRATE |
| Collaboration/versioning | Canva, Microsoft 365, Google Workspace | version history, comments, sharing, conflict handling | Versioned document model; collaboration later | BUILD LATER |
| Whiteboard | Concepts, Miro/FigJam Android workflows | infinite canvas, objects, connectors, quick manipulation | Whiteboard as a document specialization | BUILD + ADAPT |

## 4. 3D benchmark deep dive

### Nomad Sculpt

Use as the primary Android benchmark for **tactile sculpting**, not as a complete 3D suite. Study pressure-sensitive stylus interaction, multiresolution sculpting, voxel remeshing, dynamic topology, masks, symmetry, painting and PBR preview. Its scope should not be interpreted as a requirement to reproduce a full character-animation or CAD system.

### Prisma3D

Use as the primary Android benchmark for **general mobile 3D scene/model/animation workflow**. Study object/scene hierarchy, materials, cameras/lights, keyframes, rigging/skinning, model libraries and mobile interaction.

### GGEN implication

GGEN should not choose between Nomad Sculpt and Prisma3D. Their strengths are complementary:

`Nomad tactile sculpting + Prisma3D scene/animation workflow + professional interchange formats`

The GGEN 3D architecture should therefore separate:

- scene/document model
- mesh operations
- sculpt engine
- materials/textures
- animation/timeline
- rendering
- import/export

## 5. Vector benchmark deep dive

### Infinite Design

Benchmark for Android-native precision vector illustration: Bézier curves, node editing, boolean operations, snapping/alignment, layers and SVG/PDF export.

### Concepts

Benchmark for infinite vector canvas, editable strokes, stylus interaction, ideation, planning and SVG/PDF export.

### Vector Ink

Benchmark for approachable shape/path editing, node manipulation, layers and SVG workflows.

### TouchDraw

Benchmark for technical/diagrammatic vector work: geometry, snapping, connectors and structured SVG/PDF output.

### GGEN implication

The target is not a clone. Combine:

`Infinite Design precision + Concepts infinite/stylus canvas + Vector Ink simplicity + TouchDraw structured geometry`

while retaining GGEN's own document model.

## 6. Raster/painting benchmark

Use **Infinite Painter** for professional Android painting/stylus behavior, **Sketchbook** for low-friction drawing UX, **ibis Paint X** for layer/brush/comic workflows, and **Krita/Clip Studio Paint** for deeper production workflows.

The target is a common raster engine with:

- non-destructive layers
- masks/selections
- pressure/tilt
- brush presets
- stabilization
- transforms
- filters/effects
- color management
- large-canvas performance
- undo/history
- export fidelity

## 7. PDF/document benchmark

Android PDF research must distinguish **reader/annotator**, **true text editor**, **OCR**, **page organizer**, **form/signing**, and **conversion**. Current 2026 comparisons identify Xodo as a strong reading/markup workflow, Acrobat as a broad ecosystem/reference, Foxit as a professional editing reference, and PDFgear as a notable free text-editing option for searchable PDFs. citeturn0search0turn0search8turn0search6

GGEN should implement PDF through the Universal Document Model and preserve semantic structure wherever possible. OCR is a capability boundary owned by LAI; GGEN owns capture/import and document presentation.

## 8. OCR benchmark

Adobe Scan remains a major Android benchmark for scan cleanup/OCR/document capture. Current 2026 comparisons also identify Google Drive scanning as a convenient integrated option. citeturn1search9turn1search17

GGEN should not embed provider-specific OCR logic. It should request an OCR capability from LAI and consume structured text/blocks/confidence/provenance.

## 9. Animation benchmark

Use Alight Motion for mobile motion-graphics interaction and FlipaClip for frame-oriented 2D animation. Use CapCut as a broader media-editing benchmark, not as the architecture model for GGEN.

The target is a document-native timeline that can animate object properties without forcing creative content into a video-only representation.

## 10. File and asset management

Solid Explorer is a useful benchmark for advanced Android file management, including multi-pane workflows, cloud storage access and extensibility. Material Files and Files by Google provide useful simplicity/Material and system-integrated patterns. citeturn1search35turn1search28

GGEN must maintain its own asset registry and provenance model. Android storage access belongs behind a platform adapter; arbitrary paths must never be accepted directly by importers.

## 11. Android-specific product requirements

Every capability benchmark must explicitly evaluate:

- touch-only operation
- active stylus/pressure/tilt
- phone vs tablet layout
- split-screen/multitasking
- Android back/navigation behavior
- SAF import/export
- offline operation
- memory pressure
- large-file performance
- battery/thermal behavior
- accessibility
- Bangla typography/IME behavior
- external keyboard/mouse
- crash/recovery behavior

## 12. Agent research protocol

An AI agent implementing a capability must first read this document and the relevant capability specification. It must not infer that a benchmark feature is already implemented in GGEN.

For each new capability, the agent must record:

1. benchmark apps;
2. exact feature being borrowed as a pattern;
3. why the pattern is valuable;
4. GGEN current implementation status;
5. GGEN ownership;
6. LAI dependency, if any;
7. build/adapt/integrate/reject decision;
8. file/document model impact;
9. Android constraints;
10. tests and acceptance evidence.

## 13. Source examples

- Infinite Design: https://play.google.com/store/apps/details?id=com.brakefield.idfree
- Concepts: https://concepts.app/
- Nomad Sculpt: https://nomadsculpt.com/
- Prisma3D: https://prisma3d.net/
- Adobe Scan: https://play.google.com/store/apps/details?id=com.adobe.scan.android
- Collabora Office: https://www.collaboraonline.com/collabora-office-android/
- Solid Explorer: https://neatbytes.com/solidexplorer/
- Current Android vector comparison: https://geekchamp.com/best-vector-graphics-software-apps-for-android-in-2026/
- Current Android drawing comparison: https://bestappsforandroid.com/best-drawing-apps-for-android/
- Current Android PDF comparison: https://bestappsforandroid.com/best-pdf-editor-apps-for-android/

## 14. Research boundary

This is a living research baseline, not a claim that every listed app is universally best. Before a production decision, agents should re-check the vendor's current Android documentation, licensing, export behavior and device compatibility. The benchmark set must be updated when a capability changes materially.
