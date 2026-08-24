# AI Gateway Runtime — GGEN Integration Handoff

## Objective

Integrate GGEN with the **canonical LAI AI/runtime platform** through the versioned capability contract. This document no longer authorizes implementation of a provider/runtime stack inside GGEN.

## Critical ownership correction

The former GGEN-local AI Gateway implementation sequence is **superseded**.

- **LAI** owns provider adapters, provider routing/failover, credentials, model execution, local CPU/GPU/NPU runtime, device scheduling, Android tool authority, agent runtime, runtime security/audit and execution evidence.
- **GGEN** owns creative/document UX, document/creative state, AI task intent, context assembly, user-facing execution preferences/constraints, and incorporation/presentation of AI results.
- The repositories remain independent.
- GGEN must not embed llama.cpp, Vulkan, QNN, provider SDK stacks, Android automation authority or a duplicate canonical gateway merely to obtain AI capabilities.

## Required reading

1. `AI_ASSISTANT.md`
2. `CURRENT_STATE.md`
3. `MASTER_SPEC.md`
4. `docs/architecture/ggen-lai-boundary.md`
5. `docs/architecture/GGEN_LAI_INTEGRATION_SPEC.md`
6. `docs/architecture/ai-gateway-runtime.md`
7. SKB `architecture/GGEN_LAI_CAPABILITY_OWNERSHIP_MATRIX.md`
8. SKB `research/ANDROID_BEST_IN_CLASS_RESEARCH_PROTOCOL.md`
9. corresponding LAI runtime/integration documents

## Correct execution order

### P0 — Contract reconciliation

Before coding:

- inspect current GGEN and LAI source/tests/docs;
- search SKB for existing knowledge and duplicate specifications;
- reconcile capability IDs, request/response/error schemas, privacy constraints, evidence semantics, streaming and cancellation;
- record contradictions and resolve them from implementation/evidence rather than document age;
- confirm one canonical owner per capability.

### P1 — LAI runtime

Implementation of provider/runtime infrastructure occurs in LAI. GGEN agents must not start a parallel implementation here.

### P2 — GGEN client integration

Only after the LAI contract is sufficiently stable, implement the smallest GGEN-side client/adapter needed to:

- discover supported capabilities;
- send normalized requests;
- consume streaming/cancellation where supported;
- consume typed errors;
- preserve provenance/evidence;
- present user-facing recovery UX.

The adapter must not contain provider routing, credentials, Android permission decisions or runtime scheduling.

### P3 — End-to-end validation

Validate the smallest supported capabilities first, including:

- text generation;
- OCR;
- cancellation;
- unavailable runtime/provider;
- local-only policy;
- malformed request;
- unsupported capability;
- timeout/retry semantics;
- provenance/evidence preservation.

Expand to image generation/editing, embeddings, tools and agent capabilities only when the contract and LAI implementation are validated.

## Scope discipline

Do not add speculative providers, unnecessary dependencies, autonomous agent behavior, unrestricted shell/filesystem access, privileged Android actions, or UI polish under the name of gateway implementation.

Do not destabilize GGEN's working creative/editor implementation to create runtime infrastructure that belongs to LAI.

## Git workflow — mandatory

For every completed GGEN integration milestone:

1. inspect status and diff;
2. run relevant tests/build/CI-equivalent checks;
3. update documentation/status;
4. commit;
5. push to the designated branch;
6. verify the remote branch contains the commit;
7. record SHA and verification evidence.

Do not claim completion without remote verification.

## Milestone report

```text
Milestone:
Status:

Implemented:
- ...

Contract version:
LAI capability(s):
Tests:
Failure tests:
Security checks:
Build:
Files changed:
Known limitations:
Architecture deviations:
Commit SHA:
Remote branch:
Push status:
Remote verification:
Next milestone:
```

## First action

Do **not** implement the former GGEN M1 gateway foundation. First perform P0 contract reconciliation against current GGEN + LAI source/docs/tests and the SKB ownership matrix. If the contract is already sufficiently reconciled, proceed only to the smallest GGEN client integration task explicitly justified by current LAI evidence.