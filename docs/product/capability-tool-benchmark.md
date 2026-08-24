# GGEN Capability & Tool Benchmark Foundation

**Status:** Architecture/documentation baseline
**Date:** 2026-08-24
**Scope:** GGEN capabilities, external benchmarks, adoption policy, and future tool research

## 1. Purpose

GGEN is the user-facing **AI Creative & Document Studio**. It must remain useful without AI, without a network connection, and without LAI. AI is an optional capability provider, not the definition of the product.

This document is the canonical starting point for researching GGEN tools. It intentionally separates:

- what GGEN owns;
- what external technology can benchmark;
- what should be adopted as a dependency;
- what should be adapted as an architectural pattern;
- what must be built in GGEN itself; and
- what belongs behind an AI/provider boundary rather than inside GGEN.

## 2. Current verified foundation

The repository already has a documentation-first tool platform, tool contracts, typed parameters, quality gates, licensing/provenance concepts, project serialization, bounded jobs/recovery, and an AI-provider-router interface. The current Flutter shell has a canonical mobile tool rail and contextual action bar. The latest merged shell work fixed the reported RangeError and 471px-class RenderFlex overflow structurally rather than suppressing either failure.

The current mobile shell defines `StudioTool` as the typed source of truth for primary tool identity; contextual actions such as Columns are no longer navigation destinations. The compact shell has one stable tool rail and one contextual action bar. fileciteturn28file0L2-L2

## 3. Capability inventory

| Capability family | GGEN ownership | Current state | Benchmark set | Initial disposition |
|---|---|---|---|---|
| Canvas / viewport | GGEN | foundation | Figma, Illustrator, Inkscape, Krita | BUILD/ADAPT |
| Selection / transform | GGEN | foundation | Illustrator, Figma, Inkscape | BUILD |
| Vector paths / nodes | GGEN | early | Inkscape, Illustrator, Penpot | BUILD with standards |
| Shapes / fills / strokes | GGEN | early | Illustrator, Inkscape, Figma | BUILD |
| Digital painting | GGEN | roadmap | Krita | BUILD/ADAPT |
| Raster/image editing | GGEN | roadmap | GIMP, Krita, Photoshop | BUILD/ADAPT |
| Typography / text | GGEN | foundation + text flow | Illustrator, InDesign, Figma | BUILD |
| Linked text flow | GGEN | Stage 4 complete | InDesign, Affinity Publisher | BUILD |
| Layers / groups | GGEN | foundation | Photoshop, Illustrator, Figma | BUILD |
| Components / reusable assets | GGEN | roadmap | Figma, Penpot | ADAPT |
| 3D | GGEN | roadmap | Blender, Illustrator 3D, Spline | BUILD/INTEGRATE carefully |
| Document authoring | GGEN | roadmap | InDesign, LibreOffice, Affinity Publisher | BUILD |
| PDF viewing/rendering | GGEN | roadmap | MuPDF, PDFium, PDF.js | ADOPT/ADAPT |
| PDF editing | GGEN | roadmap | Acrobat, PDF-XChange, MuPDF | ADAPT |
| OCR | GGEN capability; engine may be external | interface/roadmap | PaddleOCR, Tesseract, Docling, OCRmyPDF | PROVIDER/ADAPT |
| Templates | GGEN | roadmap | Canva, Figma, InDesign | BUILD |
| Batch generation | GGEN | bounded jobs foundation | ImageMagick, GIMP batch, design APIs | BUILD |
| Workflow automation | GGEN UX; execution may delegate | roadmap | n8n, ComfyUI, Blender nodes | BUILD/ADAPT |
| Import/export | GGEN | foundation | SVG, PDF, PSD, PNG/JPEG, DOCX ecosystems | BUILD with bounded parsers |
| AI text generation | GGEN provider abstraction | interface | OpenAI, Anthropic, Gemini, local endpoints | PROVIDER |
| AI image generation/editing | GGEN provider abstraction | roadmap | OpenAI, Gemini, Flux ecosystem, ComfyUI | PROVIDER |
| Embeddings / retrieval | GGEN provider abstraction | roadmap | local/cloud embedding providers | PROVIDER |
| Agent/tool execution | GGEN consumer boundary | roadmap | MCP ecosystem, LAI | PROVIDER |
| Plugin ecosystem | GGEN | architecture | Figma plugins, Blender add-ons, VS Code extension model | ADAPT |

## 4. Benchmark interpretation

### Vector

Inkscape is the strongest open-source benchmark for deep SVG-centric illustration; Penpot is a stronger benchmark for collaborative product/design-system workflows. They solve different problems and must not be treated as interchangeable. Current ecosystem research confirms that Inkscape remains a mature local SVG editor while Penpot emphasizes collaborative design, components and prototyping. citeturn0search5turn0search2

**GGEN decision:** own the document/canvas model and interaction layer. Prefer standards such as SVG where appropriate. Do not embed Inkscape or Penpot wholesale.

### Raster and painting

GIMP is the stronger benchmark for photo/raster manipulation; Krita is the stronger benchmark for digital painting, brush engines and illustration. citeturn0search0turn0search1

**GGEN decision:** separate raster-editing and painting capability families. Do not force one engine to be both if a clean internal abstraction is possible.

### PDF

MuPDF is a strong technical benchmark for PDF rendering and document manipulation. Its current product surface explicitly targets PDF document management and has active 2026 releases. citeturn0search9

**GGEN decision:** evaluate MuPDF/PDFium/PDF.js and license terms before selecting an implementation dependency. PDF is an interoperability boundary, not permission to couple the whole editor to a PDF engine.

### OCR

OCR must be treated as a replaceable service boundary. PaddleOCR, Tesseract, Docling and OCRmyPDF represent different points in the recognition-to-document pipeline.

**GGEN decision:** expose structured OCR input/output contracts and keep the recognition engine replaceable. Do not hard-code a single OCR vendor into document models.

### AI providers

GGEN should not embed a local LLM runtime merely to make AI available. It should expose capability requests and route them to providers such as LAI, cloud APIs, OpenAI-compatible endpoints or other reviewed endpoints.

The existing AI-provider-router documentation is therefore a strategic boundary, not a temporary abstraction. fileciteturn32file16L81-L85

## 5. Adoption policy

### ADOPT

Use a technology directly only when its license, platform model, binary footprint, maintenance profile and architecture fit GGEN's product boundary.

### ADAPT

Use the external project's proven design or interoperability model while keeping GGEN's own data model and UX authoritative.

### BUILD

Implement capability natively when it is core product IP, requires tight integration with GGEN's document model, or no dependency meets the required mobile/offline/privacy constraints.

### PROVIDER

Expose a stable GGEN capability contract and allow the implementation to live outside GGEN. This is the preferred category for AI inference, agent execution, OCR engines and other replaceable intelligence services.

### REJECT

Do not import a tool simply because it is feature-rich. Reject solutions that introduce incompatible licensing, protected assets, unnecessary runtime weight, vendor lock-in, unsafe execution, or architectural duplication.

## 6. Required research record for every future tool

Before an implementation dependency is approved, record:

1. Project and exact version/revision reviewed.
2. License and redistribution implications.
3. Supported platforms and architecture.
4. Android viability.
5. Offline viability.
6. Binary/dependency footprint.
7. Performance evidence.
8. Data-format compatibility.
9. Automation/API surface.
10. Plugin/extensibility model.
11. Security/trust boundary.
12. Maintenance/community health.
13. Why ADOPT, ADAPT, BUILD, PROVIDER or REJECT.
14. Exit/replacement strategy.

## 7. Non-negotiable GGEN boundary

GGEN must never become a disguised AI runtime. It owns the creative/document user experience, artifact model, editing semantics, workflow UX and provider abstraction. LAI may provide local intelligence, but GGEN must continue to work without LAI.

## 8. Next research passes

1. Complete the vector/path benchmark matrix.
2. Complete raster/painting engine matrix.
3. Complete typography/font/layout matrix.
4. Complete document/DOCX/ODF/PDF matrix.
5. Complete OCR/document-understanding matrix.
6. Complete workflow/batch/automation matrix.
7. Complete plugin/extensibility matrix.
8. Complete AI provider capability matrix.
9. Map each approved capability to GGEN's internal interfaces.
10. Convert accepted decisions into agent-ready implementation specifications.
