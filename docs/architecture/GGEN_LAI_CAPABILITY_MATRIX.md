# GGEN ↔ LAI Capability & Ownership Matrix

**Status:** Architecture baseline
**Date:** 2026-08-24

## Canonical ownership

| Capability/domain | GGEN | LAI | Boundary |
|---|---|---|---|
| Creative canvas | **Canonical** | — | GGEN internal |
| Vector editing | **Canonical** | — | GGEN internal |
| Raster editing/painting | **Canonical** | — | GGEN internal |
| Typography/font workspace | **Canonical** | — | GGEN internal |
| 3D DCC | **Canonical** | Heavy worker infrastructure may be external | Worker contract |
| Documents/PDF/templates | **Canonical** | — | GGEN internal |
| OCR UX + placement/editing | **Canonical orchestration** | **Runtime/model execution** | `ocr.extract` |
| Image generation UX | **Canonical orchestration** | Optional runtime/provider | `image.generate` |
| Image editing UX | **Canonical orchestration** | Optional runtime/provider | `image.edit` |
| Asset/project storage | **Canonical** | — | GGEN storage model |
| Export/import | **Canonical** | — | GGEN format adapters |
| Creative workflows | **Canonical authoring** | Optional agent execution | workflow contract |
| AI provider abstraction | **Canonical consumer interface** | Provider implementation possible | capability API |
| AI routing | Policy/request side | **Canonical execution router** | provider request |
| Local LLM inference | Provider consumer | **Canonical** | inference contract |
| Model registry/runtime | — | **Canonical** | LAI API |
| CPU/GPU/NPU backends | — | **Canonical** | runtime boundary |
| Vulkan/QNN/OpenCL/llama.cpp | — | **Canonical** | LAI internal |
| Device thermal/memory scheduling | — | **Canonical** | LAI scheduler |
| Agent runtime | — | **Canonical** | `agent.run` |
| Android Accessibility | — | **Canonical** | tool gateway |
| Shizuku/elevated device operations | — | **Canonical** | policy-gated tool API |
| RAG/memory | Optional consumer | **Canonical intelligence service** | retrieval/memory API |
| AI audit/evidence | UI/report consumer | **Canonical execution evidence** | diagnostics metadata |
| Cloud AI adapters | Consumer adapters | May host gateway | provider API |
| Custom REST adapters | **Canonical adapter surface** | Optional gateway | provider API |
| Plugin system | **Creative/plugin host** | **AI/runtime plugin host** | Separate versioned APIs |
| Developer workstation | — | **Canonical** | LAI product surface |
| Git/terminal/build tooling | — | **Canonical** | LAI developer tools |

## Rules

1. If a capability primarily changes a GGEN project artifact, GGEN owns its domain semantics.
2. If a capability primarily executes intelligence, models or privileged device operations, LAI owns the runtime semantics.
3. Shared capability names do not imply shared implementation.
4. GGEN may consume LAI capabilities but must remain functional without LAI.
5. LAI must not import GGEN project internals.
6. Cross-boundary calls use stable contracts, not direct source dependencies.
7. Any future ownership change requires an architecture decision record.

## Priority integration capabilities

### Tier 1
- `text.generate`
- `vision.analyze`
- `ocr.extract`
- `image.generate`
- `image.edit`
- `embedding.create`

### Tier 2
- `structured.generate`
- `agent.run`
- `tool.execute`
- `workflow.plan`

### Tier 3
- multimodal streaming sessions
- model management visibility
- device/runtime telemetry
- long-running jobs
- remote worker orchestration
