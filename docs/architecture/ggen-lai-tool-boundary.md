# GGEN ↔ LAI Tool Boundary

**Status:** Documentation-only design baseline
**Date:** 2026-08-24

This document separates GGEN's **creative/document tools** from LAI's **AI/runtime/automation tools**. It is a boundary map, not an implementation commitment.

## GGEN-owned tool families

| Family | Examples | Owner |
|---|---|---|
| Selection/navigation | select, multi-select, pan, zoom, guides | GGEN |
| Vector | shapes, paths, pen/node editing, boolean operations | GGEN |
| Raster | image placement, crop, transform, masking, pixel operations | GGEN |
| Painting | brush, eraser, fills, strokes, pressure/input handling | GGEN |
| Typography | text frames, font controls, columns, linked text flow, layout | GGEN |
| Document | pages, sections, tables, headers/footers, layout | GGEN |
| PDF | import, page editing, annotations, export | GGEN |
| 3D | scene/object/material/camera tools | GGEN |
| OCR presentation | OCR result review, placement, correction, document integration | GGEN |
| Templates | template creation, parameter editing, application | GGEN |
| Batch/workflow authoring | user-authored creative/document workflows | GGEN |
| Export/import | project/document/image/PDF interchange | GGEN |

These tools must remain manually usable wherever their underlying operation does not inherently require AI.

## LAI-owned capability families

| Family | Examples | Owner |
|---|---|---|
| Inference | local model execution, streaming generation, model sessions | LAI |
| Model lifecycle | catalog, verification, download/import, model registry | LAI |
| Backend execution | CPU/GPU/NPU adapters, runtime selection | LAI |
| Scheduling | memory, thermal, battery and backend-aware routing | LAI |
| OCR runtime | OCR model/runtime execution | LAI |
| Agent runtime | planning/execution policy, bounded agent sessions | LAI |
| Tool authority | typed Android operations, permission and audit gates | LAI |
| Android automation | Accessibility and Shizuku authority | LAI |
| RAG/memory | embeddings, retrieval, local memory infrastructure | LAI |
| Runtime diagnostics | backend/model/device execution evidence | LAI |

## Shared through capability contracts

The following should cross the repository boundary only as semantic capabilities:

- text generation;
- OCR extraction;
- visual analysis;
- structured generation;
- image generation/editing;
- embeddings;
- workflow planning;
- agent execution requests;
- explicitly declared tool execution requests.

GGEN should never call LAI internal Kotlin classes, JNI functions, llama.cpp APIs, QNN APIs, Vulkan APIs or Android automation services directly.

## AI-assisted creative operation

A typical GGEN operation should look like:

```text
User intent
   ↓
GGEN creative/document context
   ↓
Capability request
   ↓
Provider selection
   ├── LAI
   ├── Cloud provider
   └── Custom endpoint
   ↓
Result + evidence + typed error
   ↓
GGEN validates/applies result to project
```

The final mutation of a GGEN project remains a GGEN responsibility. AI output is untrusted input to the creative/document domain and must pass GGEN validation before becoming project state.

## Important anti-coupling rules

1. No GGEN dependency on LAI source packages.
2. No LAI dependency on GGEN project/document classes.
3. No shared mutable database between repositories.
4. No implicit network fallback.
5. No AI provider may mutate GGEN project state without an explicit GGEN operation.
6. No GGEN feature may require a particular inference engine when a non-AI/manual path is semantically possible.
7. No LAI automation authority is implied by ordinary text/image generation.

## Tool quality rule

A tool belongs to GGEN when it primarily manipulates the user's creative/document artifact. A capability belongs to LAI when it primarily performs intelligence, model execution, device automation, or runtime scheduling. When both are involved, use a contract boundary rather than moving ownership merely for convenience.

This rule prevents architecture drift as both repositories grow.
