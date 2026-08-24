# GGEN / LAI Best-in-Class Capability Research

**Status:** Research baseline — 2026-08-24

## Purpose

Research current leaders and convert useful patterns into engineering requirements without blindly copying feature lists. Every capability must also respect the GGEN↔LAI ownership contract.

## Creative/document benchmark

### Canva

Current Canva documentation covers templates, elements, images, text/fonts, pages/guides/layers/version history, Docs, Whiteboards, tables, charts, audio, video/animation, apps and integrations. Its AI photo editor supports prompt-driven edits, object insertion/removal, background generation/removal, subject manipulation, text extraction/editing and upscaling. citeturn0search14turn0search13

**GGEN lessons:** one coherent visual workspace; contextual AI actions; editable templates; structured documents and designs in one editor model; AI output remains user-controlled and editable.

### Adobe Express / Acrobat

Adobe Express currently combines templates, images, video, PDFs, generative image/template/text-effect features, object insertion/removal, resizing, brand assets and scheduling. Adobe documents editable AI-generated templates and presentation generation from source documents. Acrobat/Express integration supports PDF design enhancement, templates, AI image generation, page insertion, themes and font suggestions. citeturn0search6turn0search0turn0search3turn0search2

**GGEN lessons:** PDF and creative workflows should interoperate; AI should operate on document structure as well as images; source-document→presentation is a valuable workflow; brand consistency should be first-class; generated output should remain editable.

### Target

GGEN should combine accessible visual workflows with professional document/creative integration, strong AI-assisted editing, offline/local capability where feasible, inspectable document architecture, Bangla-first UX/typography, and LAI-provided AI runtime independence.

## AI image editing requirements

Best-in-class behavior includes natural-language image modification, object-aware selection, insert/remove, background generation/removal, upscaling and localized editing. citeturn0search13turn0search6

**Engineering target:** represent edits as editable/auditable operations against assets and selections/masks where possible, not only flattened generated bitmaps.

## Document/PDF requirements

Benchmark workflows include create/edit/organize/convert/export PDF, AI document Q&A, summaries and cited answers, PDF-to-design, generated covers/presentations, template-based creation and editable AI output. Adobe currently documents AI PDF insights, cited answers, summaries, presentation generation and chat-based PDF operations. citeturn0search4turn0search5

**Engineering target:** GGEN's document model preserves semantic structure—pages, text frames, images, shapes, links and metadata—so AI can operate on structure rather than only rendered pixels.

## Android AI runtime benchmark

### llama.cpp

llama.cpp provides Android support and an Android binding/sample; its Android documentation covers GGUF metadata loading from Android URIs/private storage and hardware-aware kernels. citeturn1search12

**LAI lesson:** retain a lightweight direct native LLM path and explicit user-controlled model storage.

### ExecuTorch

ExecuTorch provides Android Java/Kotlin AAR integration and CPU/XNNPACK, Vulkan GPU, Qualcomm AI Engine, MediaTek and other accelerator backends. It also provides Android LLM runtime components. citeturn1search0turn1search4turn1search1

**LAI lesson:** a backend-neutral runtime contract with replaceable hardware adapters is the correct abstraction; application code should not bind directly to one accelerator SDK.

### ONNX Runtime

ONNX Runtime provides Android Java/Kotlin and C/C++ packages and supports Android builds plus QNN execution-provider integration. citeturn1search2turn1search14

**LAI lesson:** ONNX is an interoperability/backend option, not the universal abstraction for GGUF-centric LLM execution.

## Backend architecture conclusion

```text
LAI Inference Contract
        |
        +-- llama.cpp / GGUF
        +-- ExecuTorch
        +-- ONNX Runtime
        +-- Qualcomm/QNN
        +-- Vulkan
        +-- CPU fallback
```

The scheduler selects based on model format, capabilities, device, memory, thermal state, reliability and measured evidence. Product-level agent logic stays above the backend layer.

## Tool/agent target

Android capabilities should be typed tools with stable IDs/versions, schema validation, risk levels, permission requirements, explicit confirmation for consequential operations, bounded execution, normalized results, audit events and idempotency for side-effecting operations where possible.

## Build vs integrate

**Build:** GGEN document/creative model and editor UX; LAI runtime orchestration, Android permission/tool authority, device-aware scheduling, Bangla-first runtime capabilities, and the GGEN↔LAI contract.

**Adapt/integrate:** AI providers, model runtimes, hardware SDKs, compatible file-format libraries, and external generation services.

**Never duplicate:** provider routers, Android automation authorities, model schedulers, provider secrets, or runtime permission authorities.

## Research rule

Research does not authorize blind competitor parity. The target is a coherent architecture in which GGEN approaches best-in-class creative/document workflows while LAI supplies reusable AI/device runtime services.

Before implementing any capability, document: current leaders, open-source alternatives, data/file model implications, Android/offline implications, licensing, security/privacy, testability, canonical owner, integration boundary, MVP scope and best-in-class target behavior.
