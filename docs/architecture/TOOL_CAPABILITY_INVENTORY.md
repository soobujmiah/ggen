# GGEN ↔ LAI Tool & Capability Inventory

**Status:** Inventory baseline/schema
**Date:** 2026-08-24

This document establishes the authoritative format for the detailed tool inventory. It deliberately distinguishes current implementation from target capability so agents cannot mistake a roadmap item for an existing tool.

## Classification

Each discovered tool/capability receives one status:

- `IMPLEMENTED`
- `BUILD_VERIFIED`
- `DEVICE_VALIDATED`
- `SCAFFOLD`
- `PLANNED`
- `DEPRECATED`

## Required record

```text
id
name
repository
module/path
status
canonical_owner
purpose
inputs
outputs
side_effects
ai_dependency
network_dependency
privacy_class
security_risk
runtime_dependency
reusable_boundary
current_tests
device_evidence
target_quality_reference
replacement_candidate
migration_action
priority
```

## Initial high-level inventory

### GGEN

- Canvas/workspace shell — `IMPLEMENTED/DEVICE_VALIDATED` according to current device evidence.
- Select/Draw/Text tools — implemented and device exercised.
- Layers/inspector/grid/history — implemented with device evidence.
- Multi-column text frame layout — implemented/build verified.
- Linked text flow — implementation exists; device validation remains a separate milestone.
- Document/template/project model — core product domain.
- Vector/raster/font/3D systems — product roadmap at different implementation phases; do not mark as implemented without source/test evidence.
- AI provider abstraction — required architecture; integration implementation is a later milestone.

### LAI

- InferenceEngine / generation contracts — build verified.
- llama.cpp CPU backend — device validated.
- Vulkan backend — implemented; GPU qualification pending because of the known driver crash boundary.
- OpenCL backend track — implemented; device qualification pending.
- QNN/HTP — planned boundary, no code.
- InferenceScheduler — CPU device validated; accelerator evidence-gated.
- Accessibility gateway — device validated for service/snapshot paths.
- Tool policy/gate/audit — implemented/build verified with device evidence for selected paths.
- Shizuku integration — device validated.
- OCR contract — build verified; real Bangla OCR model remains pending.
- AgentRuntime — policy-gated execution boundary.
- Diagnostics/logging/export — ready/build verified.
- Model catalog/download/import lifecycle — implemented/build verified.

## Inventory procedure

1. Inspect repository tree and module boundaries.
2. Enumerate public contracts/interfaces first.
3. Enumerate concrete implementations.
4. Link each implementation to tests and device evidence.
5. Record dependencies and side effects.
6. Assign canonical owner.
7. Identify duplicate/overlapping capabilities.
8. Research best-in-class reference tools for quality—not implementation copying.
9. Record whether reuse should occur through API, file format, plugin, worker or remain independent.
10. Update this inventory before implementation of cross-repository integration.

## Evidence rule

A README or roadmap statement is not device evidence. A source implementation is not proof of execution. A provider/backend label is not proof of accelerator use. Every inventory status must be traceable to source, automated tests, or explicit physical-device evidence.
