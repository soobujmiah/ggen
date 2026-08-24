# GGEN / LAI Best-in-Class Capability Research

**Status:** Research baseline — 2026-08-24

## Purpose

Research current leaders and convert useful patterns into engineering requirements without blindly copying feature lists. Every capability must also respect the GGEN↔LAI ownership contract.

## Research structure

This file is the **cross-capability synthesis**. Detailed Android benchmark research is maintained separately in `docs/research/android-best-in-class-tool-research.md` so the same large benchmark matrix is not duplicated.

For every capability, agents must research:

1. strongest Android-native/Android-available tools;
2. strongest professional reference;
3. strongest relevant open-source implementation;
4. specialist tools for important sub-capabilities;
5. feature, UX, architecture, licensing, device and interoperability implications;
6. GGEN current state and gap;
7. canonical owner and BUILD/ADAPT/INTEGRATE/PROVIDER/REJECT decision.

The detailed Android benchmark set includes vector, raster, 3D, PDF, document, presentation, spreadsheet/data, OCR, animation, motion graphics, image generation/editing, asset management, typography, whiteboard and collaboration workflows.

## Creative/document benchmark

### Canva

Current Canva documentation covers templates, elements, images, text/fonts, pages/guides/layers/version history, Docs, Whiteboards, tables, charts, audio, video/animation, apps and integrations. Its AI photo editor supports prompt-driven edits, object insertion/removal, background generation/removal, subject manipulation, text extraction/editing and upscaling. citeturn0search14turn0search13

**GGEN lessons:** one coherent visual workspace; contextual AI actions; editable templates; structured documents and designs in one editor model; AI output remains user-controlled and editable.

### Adobe Express / Acrobat

Adobe Express currently combines templates, images, video, PDFs, generative image/template/text-effect features, object insertion/removal, resizing, brand assets and scheduling. Adobe documents editable AI-generated templates and presentation generation from source documents. Acrobat/Express integration supports PDF design enhancement, templates, AI image generation, page insertion, themes and font suggestions. citeturn0search6turn0search0turn0search3turn0search2

**GGEN lessons:** PDF and creative workflows should interoperate; AI should operate on document structure as well as images; source-document→presentation is a valuable workflow; brand consistency should be first-class; generated output should remain editable.

### Android-first benchmarks

The Android-specific benchmark document is authoritative for the detailed app/tool matrix. Important examples include:

- **Vector:** Infinite Design, Concepts, Vector Ink, TouchDraw
- **Raster/painting:** Infinite Painter, Sketchbook, ibis Paint X, Krita, Clip Studio Paint
- **3D sculpting:** Nomad Sculpt
- **3D scene/model/animation:** Prisma3D
- **PDF:** Xodo, Adobe Acrobat, Foxit, PDFgear
- **Office/document:** Microsoft 365, WPS Office, Collabora Office
- **OCR/scanning:** Adobe Scan and Android scanning workflows
- **Animation/motion:** Alight Motion, FlipaClip, CapCut
- **File/asset management:** Solid Explorer, Material Files, Files by Google
- **Whiteboard/infinite canvas:** Concepts and comparable Android workflows

Do not treat these names as a dependency list. They are evidence sources for feature/UX/architecture decisions. See `docs/research/android-best-in-class-tool-research.md` for the detailed matrix and sub-capability decomposition.

## Target

GGEN should combine accessible visual workflows with professional document/creative integration, strong AI-assisted editing, offline/local capability where feasible, inspectable document architecture, Bangla-first UX/typography, and LAI-provided AI runtime independence.

## AI image editing requirements

Best-in-class behavior includes natural-language image modification, object-aware selection, insert/remove, background generation/removal, upscaling and localized editing. citeturn0search13turn0search6

**Engineering target:** represent edits as editable/auditable operations against assets and selections/masks where possible, not only flattened generated bitmaps. AI execution remains a LAI capability; GGEN owns the creative interaction and resulting artifact model.

## Document/PDF requirements

Benchmark workflows include create/edit/organize/convert/export PDF, AI document Q&A, summaries and cited answers, PDF-to-design, generated covers/presentations, template-based creation and editable AI output. Adobe currently documents AI PDF insights, cited answers, summaries, presentation generation and chat-based PDF operations. citeturn0search4turn0search5

**Engineering target:** GGEN's document model preserves semantic structure—pages, text frames, images, shapes, links and metadata—so AI can operate on structure rather than only rendered pixels.

## Android AI runtime benchmark

Runtime benchmarking belongs to LAI. GGEN should consume LAI capability contracts rather than reproduce runtime/provider infrastructure. See the LAI repository's `docs/research/android-best-in-class-runtime-tool-research.md` for the Android runtime/tool benchmark.

### llama.cpp / ExecuTorch / ONNX Runtime

These remain important architecture references for LAI's backend-neutral execution strategy, not GGEN dependencies. citeturn1search12turn1search0turn1search4turn1search2turn1search14

## Tool/agent target

GGEN-facing AI actions should be expressed as stable capability contracts. Provider routing, model execution, Android authority, permission enforcement, terminal execution, tool registry and runtime audit remain LAI-owned.

## Build vs integrate

**Build:** GGEN document/creative model and editor UX, creative workflows, artifact presentation and GGEN-side AI capability consumption.

**Adapt/integrate:** compatible file-format libraries, rendering/editing engines, font/media libraries and external creative services where ownership is unnecessary.

**Provider:** consume AI inference, OCR execution, provider routing and Android tools through LAI contracts.

**Never duplicate:** provider routers, Android automation authorities, model schedulers, provider secrets, or runtime permission authorities.

## Research rule

Research does not authorize blind competitor parity. The target is a coherent architecture in which GGEN approaches best-in-class creative/document workflows while LAI supplies reusable AI/device runtime services.

Before implementing any capability, document: current leaders, Android benchmarks, open-source alternatives, data/file model implications, Android/offline implications, licensing, security/privacy, testability, canonical owner, integration boundary, MVP scope and best-in-class target behavior.
