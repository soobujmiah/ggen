# GGEN — AI Creative & Document Studio

## Master Product, Architecture & Development Specification

**Status:** Master Specification  
**Priority:** Highest  
**Repository type:** Public Apache-2.0 source repository with a separate private protected-asset vault  
**Reference repositories:** `soobujmiah/bg`, `soobujmiah/rgen`  
**Initial platform:** Android-first Flutter  
**Core rule:** Reference functionality and engineering knowledge only. Never copy BG/RGEN UI, UX, visual identity, layout, branding, interaction design, colors, typography system, icons, or navigation.

This file is the authoritative product directive. Architecture decisions refine implementation but may not silently weaken these requirements.

## 1. Vision

Build a world-class, professional, AI-native Creative & Document Studio combining vector/raster creation, AI image generation/editing, document/PDF/template creation, template reconstruction, batch generation, OCR, structured-data automation, model management, local/cloud/custom AI, hardware acceleration, workflows, universal import/export, plugins, tool customization, and professional workspace customization.

The product must work in five useful states: manual without AI, local AI, cloud AI, custom endpoints, and hybrid/automatic routing. It must never depend on one vendor, model, hardware backend, or file format.

## 2. Repository/reference boundary

GGEN is independent. BG and RGEN are read-only references.

Allowed reference knowledge: capabilities, algorithms, processing pipelines, model contracts, document-generation logic, template behavior, file-format handling, tests, validation, performance/security lessons, and backend concepts.

Forbidden copying: UI/UX, screen layouts, colors, fonts as design identity, component/interaction/navigation design, branding, icons, and visual identity. Protected RGEN production assets are never part of this public source tree; their private-vault boundary and metadata-only registry are governed by §6. Their existence does not authorize copying RGEN UI.

## 3. Documentation-first development

Before major implementation: read this specification; inspect BG/RGEN and their deep audits; inventory capabilities, unsafe behavior, protected assets, and provenance; design architecture; define interfaces, tests, migration/integration boundaries, security limits, and evidence rules. Documentation and implementation must stay synchronized.

## 4. BG reference capabilities and lessons

Reusable through clean interfaces: semantic segmentation, global/tiled inference, mask feathering/refinement, background replacement (transparent/solid/blur), adjustments, rotate/flip, PNG/JPEG/WebP, and TFLite pipeline.

Do not inherit false NPU/GPU detection, delegate-accepted-as-execution, stale backend labels, fabricated 60/20/20 timing, unwired batch/settings, weak bitmap ownership, broad permissions, or unverified claims.

## 5. RGEN reference capabilities and lessons

Reusable through adapters/interfaces: certificate/routine/testimonial engines, template validation, vector-first PDFs, batch generation, CSV/XLSX mapping, text/image/photo/signature fields, QR/barcode, OCR, portable packages, custom-template behavior, and layout-regression testing.

Do not inherit unbounded imports/complexity/spreadsheets, unsafe manifest paths, all-files access, debug production signing, incomplete provenance, memory-retained batch ZIPs, or unverified feature claims.

## 6. Protected RGEN assets

The owner selected the current RGEN production asset snapshot for private preservation in `soobujmiah/ggen-protected-assets`. The public logical registry is `config/protected-asset-registry.json`; it records stable IDs, sizes, SHA-256 values, purposes, source repository/commit, license status and blocked distribution status without exposing bytes.

Rules for an owner-approved private pack: never modify, overwrite, delete, re-quantize, optimize, migrate, or silently replace. A verifier accepts only canonical relative paths with exact registry size and SHA-256 values, rejects missing or extra entries, and performs no writes. Public builds and tests must work with no pack and must never download restricted bytes automatically.

Private preservation does not establish redistribution rights. Genuine Lucida fonts, signatures, seals/logos, production templates, OCR/model files and other assets with unresolved provenance remain blocked from public and commercial distribution until rights and authorization are reviewed.

## 7. Independent identity and professional UX

GGEN must have its own name, logo, brand, design system, color, typography, iconography, motion, interaction language, navigation, and workspace model. It must be polished, accessible, touch/mouse/keyboard/stylus friendly, responsive, and original—not an imitation of BG, RGEN, or one competitor.

Required interaction qualities: high-FPS canvas, smooth zoom/pan, immediate selection feedback, progressive rendering, non-blocking work, contextual controls, smart inspector, command palette/search/shortcuts, undo/redo/history, autosave/crash recovery, persistent workspaces, before/after, progress/cancellation/error recovery.

## 8. Manual-first and AI modes

All important drawing, painting, vector/raster editing, text/layout/template/document/layer/export/batch operations must be manually usable. AI is optional.

Modes: `MANUAL`, `LOCAL_AI`, `CLOUD_AI`, `HYBRID`, `AUTO`. Policies: Always Manual, Prefer Local, Prefer Cloud, Auto, Ask Before AI.

## 9. Provider and endpoint abstraction

Define capability-driven providers: Local, OpenAI, Gemini, Anthropic, OpenAI-compatible, Custom REST, and Plugin. Capabilities may include text, vision, image generation/editing, OCR, embeddings, audio/video, structured output, tools/agents/workflows.

Custom endpoint configuration: name, URL, secure API key reference, auth, headers, model, request/response mapping, timeout/retry/streaming, capabilities, privacy, and usage limits. Support LAN/self-hosted/remote services. Never commit keys; use platform secure storage.

## 10. Central AI router and evidence

Route by required capability, quality, privacy, cost, speed, available model/hardware, policy, and task constraints. Pipeline: task → policy/router → selected backend/provider → execute → verify → result/evidence.

Hardware states must distinguish: API available, delegate accepted, operations delegated, execution completed, backend verified, performance measured. Never infer hardware execution from API availability. Every metric must be measured and scoped.

## 11. Local runtime and Model Lab

Extensible CPU, GPU, NNAPI, QNN/Hexagon, and future backend adapters. Model Lab: import/inspect/validate/benchmark/compare/version/test/deploy/rollback, conversion/optimization/quantization where safe, datasets, fine-tuning/LoRA where appropriate. Protected assets are excluded from destructive Model Lab operations.

One image may produce an extracted asset, mask, vectorized asset, reference, dataset sample, component, or AI profile; never falsely call that full neural-network training.

## 12. Creative engines

### Vector Studio
Selection/direct selection, pen/Bezier/pencil/node editing, shapes, booleans/path operations, stroke/fill/gradients/patterns, clipping, transforms/perspective, align/distribute, guides/grid/snapping, artboards, components/symbols/groups/layers.

### Raster Studio
Brush/pencil/eraser/airbrush/smudge/clone/heal/blur/sharpen/dodge/burn, selections/lasso/magic selection, crop/transform/warp, masks/alpha/blend modes, filters/curves/levels/color/noise/restoration, BG-adapter background removal, object removal/inpainting/outpainting/super-resolution/AI enhancement.

### Tools/brushes
Deep per-tool size/opacity/flow/hardness/spacing/smoothing/stabilization/pressure/tilt/rotation/velocity/dynamics/jitter/blend/cursor/gesture/shortcut customization; create/edit/duplicate/delete/organize/import/export/reset presets. Professional brush shapes/textures/scatter/dynamics/libraries/custom creation.

## 13. Application customization

Theme/accent/density/font/icon/panel/toolbar/canvas/motion/transparency; custom save/load/reset workspaces; dock/undock/reorder/hide panels; custom toolbar; complete shortcut editor/profiles/import/export/conflict detection; mouse/touch/stylus buttons/gestures/wheel/pressure/tilt/pan/zoom/rotation.

AI settings: default provider/model, local/cloud/privacy/cost/token/context policies, supported sampling controls, image resolution/seed, system/custom/model instructions.

## 14. AI image and document creation

Image generation studio: text/image/reference generation, inpaint/outpaint/background/object replacement/style/variations/batch/resolution/seed/history/comparison with local/cloud providers.

Document Studio: multipage layers, text/images/shapes/tables/QR/barcodes/signatures/dynamic fields/headers/footers/margins/bleed/print/color/templates.

Natural-language document generation should produce an editable universal document whenever possible. AI template reconstruction pipeline: image/PDF/scan → OCR → layout/object/typography analysis → asset/field extraction → editable template. Every AI structure remains inspectable and manually correctable.

## 15. Data automation and workflow engine

CSV/XLSX/JSON and extensible structured-data mapping to templates and hundreds/thousands of outputs. Must be bounded, streaming/memory-safe, cancellable, resumable, and explicit about partial completion.

Visual workflows: create/edit/save/duplicate/version/share, run/pause/resume/cancel/schedule. Nodes may load files, process images, OCR, map data, generate documents, add codes, export, and archive. Natural language may generate a reviewable workflow; it must not silently execute risky steps.

## 16. Universal document and format model

Internal model independent from output formats. Export adapters for PDF, DOCX, PPTX, SVG, PNG/JPEG/WebP/TIFF, HTML, Markdown, JSON, native project, template/workflow/model/dataset packages, and protected RGEN compatibility. Warn on unsupported fidelity; never silently destroy content.

Progressive format ecosystem: PDF/DOCX/ODT/RTF/TXT/Markdown/HTML/EPUB; PNG/JPEG/WebP/AVIF/TIFF/BMP/SVG; CSV/TSV/XLSX/XLS/JSON/XML; PPTX/ODP; native/project/package/ZIP formats. Plugins may add formats.

## 17. Assets and plugins

Asset library for templates, images, logos, signatures, fonts, brushes, colors, gradients, patterns, models, backgrounds, components, symbols, workflows, presets, with search/tags/folders/favorites/metadata/version/preview/deduplication.

Stable plugin system for tools, panels, import/export, AI providers/models, templates/brushes/filters/workflow nodes/automation/formats without normal core modification. Plugins are capability-scoped, versioned, validated, and sandboxed where platform permits.

## 18. Privacy and security

Per-content routing policy: local-only, cloud allowed, ask first, or local preferred. Before cloud transfer, identify exactly what leaves device, destination, reason, retention/policy, and cost; require appropriate consent.

Imported files are untrusted. Enforce archive byte/entry/uncompressed/compression limits, schema and canonical-child paths, PDF/image/spreadsheet/font/page/element/cell limits, memory/disk admission, cancellation, cleanup, and process-death recovery. Use SAF/MediaStore/platform storage instead of broad all-files access.

## 19. Performance and testing

Non-blocking UI, background task runtime, incremental/progressive rendering, safe parallelism, caches, cancellation, memory awareness, backend-specific real metrics. Record preprocessing/inference/postprocessing/total separately with backend/model/resolution/memory/device/thermal context.

Tests must cover document/vector/raster geometry, protected assets, model contracts, providers/router/evidence, OCR, export formats, batch limits/cancellation/recovery, import/ZIP/path/schema security, workflows, settings/tool customization/plugins, UI/accessibility, and physical-device acceleration/performance.

## 20. Development phases

0. Audit/documentation/protected inventory/licensing/architecture/interfaces/tests — **no major features before complete**.
1. Core: UDM, assets, settings, plugins, storage, undo/history/projects.
2. Graphics: vector/raster/canvas/layers/selection/type/brush/mask.
3. BG adapter: segmentation/background/enhancement/evidence-aware backends.
4. RGEN adapter: protected templates, document engines, bounded batch/data mapping.
5. Local AI: registry/router and CPU/GPU/NNAPI/QNN adapters.
6. Cloud/custom AI providers and secure credentials.
7. AI creative tools and editable template reconstruction.
8. Workflow editor/runtime/AI generation/batch/scheduling.
9. Universal export adapters.
10. Professional polish, accessibility, performance, recovery, production hardening.

## 21. Absolute rules

Do not copy reference UI/design; modify protected assets; claim unsupported capability; fabricate metrics; claim GPU/NPU without evidence; make AI mandatory; lock to one provider/backend/format; create a monolith; implement major features without docs; silently degrade conversion; expose keys; trust imports; freeze UI for background work; rewrite proven reference logic without technical reason; or ship significant features without tests/documentation.

## 22. Final product definition

A unified, independently designed professional environment for manual vector/raster/3D/font creation, AI generation/editing, documents/PDF/templates/reconstruction, RGEN-compatible protected production documents, structured batch generation, models and hardware backends, cloud/custom AI, workflows, broad export, deep customization, plugins, complete offline/manual use, and optional provider-agnostic AI.

## 23. Premium font creation and typography

GGEN must support professional OpenType typography and a phased full font-engineering workspace: script-aware shaping, Bangla and bidi correctness, variable fonts, kerning, ligatures/features, glyph outline/node editing, components/anchors, metrics, kerning classes, masters/axes/interpolation, proofing, validation and reviewed TTF/OTF/WOFF2/UFO/designspace import/export. Font licensing and embedding rights are first-class metadata. Protected fonts cannot be modified by the font editor.

See `docs/architecture/font-creation-studio.md`.

## 24. Full professional 3D DCC roadmap

GGEN must have a long-term original 3D DCC subsystem covering scene graph, modeling, sculpting, UV, PBR materials, painting, rigging, animation, procedural tools, simulations, physically based rendering and compositing. Blender is a quality/depth reference only; do not copy Blender UI or claim parity before evidence. Flutter owns the shell; a native high-performance engine owns scene/render operations. The subsystem must be resource-bounded, progressive, recoverable, offline-capable for core editing, and able to use explicit privacy-approved workers for heavy jobs.

See `docs/architecture/3d-dcc-studio.md`.

## 25. GitHub-centric hybrid brain

GitHub is canonical memory/control plane. Arena Agent is the disposable orchestration brain for audits, architecture, documentation and source generation. GitHub Codespaces is the planned pinned interactive build environment; Actions performs reproducible CI/release; Redmi Turbo 4 Pro provides physical Android truth; optional isolated workers may handle large 3D/AI jobs. No authoritative state may exist only on a transient machine.

The machine-readable contract is `config/development-environments.yaml`; see `docs/environment/github-centric-hybrid-brain.md` and ADR-0002.

## 26. Mandatory computer-quality tools with mobile-friendly UI

Every shipped tool must have professional computer-quality semantics, precision, history, customization, interoperability, performance and evidence. The mobile interface must be touch/stylus friendly, responsive, discoverable and accessible; it may adapt panel density and command access but may not reduce the underlying project/tool quality. GGEN prefers fewer complete professional tools over many demo-quality buttons.

Blender, FontForge, Photoshop, PicsArt, Adobe Illustrator, Infinite Design and Infinite Painter are capability/quality references only. Their UI, brand, icons, layouts and proprietary implementation must not be copied. The mandatory release standard is `docs/product/computer-quality-tool-standard.md`; adaptive behavior is defined in `docs/design/mobile-first-professional-ui.md`; machine rules are in `config/tool-quality-standard.yaml`.
