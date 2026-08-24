# Cross-Repository Architecture Decisions

**Date:** 2026-08-24

## ADR-001 — Keep GGEN and LAI separate

**Decision:** GGEN and LAI remain separate repositories and products.

**Reason:** Their domains differ. GGEN is a creative/document product; LAI is an AI/runtime/automation platform. A shared codebase would increase coupling and make either product's evolution harder.

## ADR-002 — GGEN consumes AI capabilities through providers

**Decision:** GGEN does not embed a mandatory local LLM runtime. Local AI is accessed through a provider boundary, with LAI as the preferred local provider.

**Reason:** Keeps GGEN lightweight, provider-neutral and manually usable while allowing LAI to evolve its llama.cpp/GPU/NPU/runtime stack independently.

## ADR-003 — Capability-first contracts

**Decision:** Integrate by capability IDs such as `text.generate`, `ocr.extract`, `image.generate`, `agent.run`, not by provider-specific APIs in GGEN core.

**Reason:** Providers can be replaced or added without rewriting creative-domain code.

## ADR-004 — Execution evidence is explicit

**Decision:** Accelerator/runtime claims require evidence fields and must distinguish availability, acceptance, delegation, completion, validation and measurement.

**Reason:** LAI already uses evidence-gated accelerator scheduling. This prevents GGEN from displaying misleading GPU/NPU claims.

## ADR-005 — Manual operation is a hard invariant

**Decision:** AI/provider failure must never make core GGEN editing unusable.

**Reason:** The GGEN product specification explicitly requires useful manual operation without AI or network.

## ADR-006 — Tool ownership follows domain responsibility

**Decision:** GGEN owns artifact/creative/document semantics; LAI owns intelligence/runtime/device authority.

**Reason:** Prevents duplicate implementations and unsafe movement of privileged capabilities.

## ADR-007 — Documentation precedes integration

**Decision:** Complete boundary, capability inventory, ownership matrix and contract design before substantial cross-repository implementation.

**Reason:** Future AI coding agents must implement against stable architecture rather than rediscovering it from source.
