# GGEN ↔ LAI Cross-Repository Tool Inventory

**Status:** Evidence-backed baseline
**Date:** 2026-08-24

This inventory separates existing tools from roadmap items and records the correct owner. It is intentionally conservative: source presence is not execution evidence, and roadmap documentation is not implementation.

## GGEN — current/tooling surface

| Capability/tool | Evidence | Owner | AI/network | Boundary |
|---|---|---|---|---|
| Canvas/workspace shell | device evidence + merged PR #54 | GGEN | no | internal |
| Select / Draw / Text | source + device diagnostics | GGEN | no | `StudioTool`/editor |
| Layers / Inspector | source + device diagnostics | GGEN | no | editor |
| Grid / zoom / history | source + device diagnostics | GGEN | no | editor |
| Project/storage | source + product contracts | GGEN | no | project model |
| Text-flow/multi-column | source + tests; linked flow needs separate device validation | GGEN | no | document model |
| Tool sessions/contracts | `ggen_core` tool contract/session modules | GGEN | optional | internal tool API |
| AI provider/router contract | documented interface; integration not yet established | GGEN | yes | provider API |
| Creative quality/tool standards | documented benchmark | GGEN | no | product quality gate |
| Vector/raster/painting/font/3D | product roadmap/architecture | GGEN | optional | internal engines |
| Document/PDF/templates/export | product architecture/roadmap | GGEN | optional | internal document model |
| Workflow authoring | product architecture/roadmap | GGEN | optional | versioned workflow contract |
| Plugins | architecture/roadmap | GGEN | optional | plugin API |

## LAI — current/tooling surface

| Capability/tool | Evidence | Owner | AI/network | Boundary |
|---|---|---|---|---|
| `InferenceEngine` | build verified | LAI | local | provider contract |
| llama.cpp CPU | device validated | LAI | local | inference runtime |
| Vulkan | implemented; qualification pending/driver boundary | LAI | local | backend internal |
| OpenCL | implemented track; qualification pending | LAI | local | backend internal |
| QNN/HTP | planned | LAI | local | backend future |
| InferenceScheduler | CPU device validated; accelerator evidence-gated | LAI | local | runtime policy |
| Model catalog/download/import | build verified | LAI | inbound network for reviewed artifacts | model lifecycle |
| Accessibility snapshot/click/type/scroll | device/build evidence by tool | LAI | local | Android authority |
| Shizuku allowlisted operations | device validated | LAI | local | privileged tool gateway |
| Tool policy/gate/audit | build/device evidence | LAI | local | authority boundary |
| `ocr.current_screen` | scaffold; model required | LAI | local | `ocr.extract` |
| `AgentRuntime` | policy-gated execution boundary | LAI | local | `agent.run` |
| Diagnostics/logging/export | ready/build verified | LAI | local | evidence/diagnostics |
| RAG/embeddings | architecture/roadmap; not to be inferred as complete | LAI | local/future | `embedding.create` |
| Developer AI/Git/Linux | roadmap/tool catalog | LAI | optional network | separate developer surface |

## Ownership rules

1. GGEN owns semantics that create or modify GGEN project artifacts.
2. LAI owns intelligence execution, model/runtime infrastructure and privileged device authority.
3. A similar function in both repositories does not justify copying or merging it.
4. Cross-repository reuse uses a stable protocol, not source imports.
5. GGEN may operate without LAI.
6. LAI must not import GGEN project internals.

## Highest-value first integrations

### Tier 1 — safe foundational capabilities

1. `text.generate`
2. `ocr.extract` (after real OCR model availability)
3. `vision.analyze`
4. `embedding.create`

### Tier 2 — creative generation

5. `image.generate`
6. `image.edit`
7. `structured.generate`

### Tier 3 — authority-bearing capabilities

8. `workflow.plan`
9. `agent.run`
10. `tool.execute`

Tier 3 requires explicit consent/risk/policy/audit semantics and must never be enabled merely by installing a provider.

## Research-quality reference classes

GGEN's quality matrix already uses Illustrator/Infinite Design, Photoshop/PicsArt, Infinite Painter, Blender, FontForge and professional page-layout/PDF tools as capability references. LAI's tool catalog uses typed, policy-gated, audited operations rather than raw shell. External provider research reinforces capability discovery, typed tool schemas, host-side authorization, normalized streaming and explicit cancellation/error semantics.

References are quality/architecture references only; no UI or proprietary implementation is copied.

## Update rule

Whenever a tool is added, removed, moved or promoted from roadmap to implementation:

- update this inventory;
- record source path;
- record tests/evidence;
- record owner and contract;
- update the relevant ADR if ownership changes.
