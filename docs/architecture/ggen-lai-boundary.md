# GGEN ↔ LAI Boundary & Ownership Contract

**Status:** Canonical architecture decision
**Scope:** Cross-repository responsibility, overlap reduction, integration boundary
**Last reviewed:** 2026-08-24

## 1. Purpose

GGEN and LAI are complementary systems, not two implementations of the same product.

- **GGEN** owns the creative/document product domain and user-facing creative workflows.
- **LAI** owns Android AI execution/runtime authority: local inference, device-aware backend selection, Android automation/tool authority, permissions/consent, and provider connectivity/runtime policy.

The goal is to remove duplicated infrastructure while preserving clean contracts between the repositories.

## 2. Ownership rule

When a capability is primarily about **what the user creates**, it belongs in GGEN.

When a capability is primarily about **how AI executes or how Android/device capabilities are accessed**, it belongs in LAI.

A capability may have a client-side facade in GGEN, but the underlying runtime authority must have one canonical owner.

## 3. Canonical ownership matrix

| Capability | GGEN | LAI | Rule |
|---|---|---|---|
| Creative/document UX | **Owner** | Consumer only | GGEN owns product UX |
| Canvas/editor | **Owner** | — | No duplication |
| Vector/raster editing | **Owner** | — | Creative domain |
| PDF/document authoring | **Owner** | — | Creative/document domain |
| Templates/brand assets | **Owner** | — | Creative domain |
| OCR user workflow | **Owner** | Runtime/provider | GGEN owns UX/data model; LAI may supply device OCR runtime |
| AI task UX | **Owner** | Runtime | GGEN defines task intent; LAI executes AI |
| AI provider adapters | **Consumer** | **Owner** | One canonical provider layer |
| Provider routing/failover | **Consumer** | **Owner** | Do not duplicate router logic |
| Model registry/runtime metadata | Consumer | **Owner** | GGEN requests capability/model; LAI owns runtime registry |
| Local LLM inference | Consumer | **Owner** | CPU/GPU/NPU execution belongs to LAI |
| Backend scheduling | — | **Owner** | Device/thermal/memory aware |
| Android tool registry | — | **Owner** | One tool authority |
| Android permission/consent | — | **Owner** | Security boundary |
| Accessibility automation | — | **Owner** | Android authority |
| Shizuku/elevated operations | — | **Owner** | Typed/policy-gated operations |
| Tool audit/security events | — | **Owner** | Runtime authority |
| Workflow definition | **Owner** | Runtime executor | GGEN defines creative workflow; LAI executes permitted AI/device steps |
| AI-generated creative content | **Owner of product result** | Runtime/provider | Result enters GGEN's document model |
| Provider credentials | — | **Owner** | Never duplicate secrets in GGEN |
| Cloud API transport | Consumer | **Owner** | GGEN uses contract |
| Custom endpoint support | Consumer | **Owner** | Adapter/runtime concern |
| Local/cloud/hybrid selection | Policy consumer | **Owner of runtime capability** | GGEN can request a mode; LAI resolves execution |

## 4. Integration direction

```text
GGEN Creative/Product Layer
          |
          | stable AI Runtime contract
          v
LAI AI/Device Runtime
          |
     +----+-----+----------------+
     |          |                |
   Local      Cloud          Android Tools
 CPU/GPU/NPU  Providers       Accessibility/
              /Custom         Shizuku/etc.
```

GGEN must not import LAI implementation internals. Integration should use a stable contract/adapter boundary.

LAI must not absorb GGEN's document/canvas domain model. LAI returns normalized AI/tool results; GGEN owns interpretation into creative/document state.

## 5. Explicit non-duplication rules

Do not implement these independently in both repositories:

- provider adapters;
- API-key/secret storage;
- retry/failover router;
- model execution scheduler;
- Android tool registry;
- Android permission authority;
- Accessibility automation executor;
- Shizuku operation authority;
- device/thermal backend selection;
- runtime audit chain.

If GGEN needs one of these capabilities, it consumes the LAI contract instead of cloning the subsystem.

## 6. Contract boundary

A future stable integration contract should expose concepts such as:

```text
AiRuntimeClient
 ├── capabilities()
 ├── models()
 ├── generate(request)
 ├── stream(request)
 ├── executeTool(call)
 └── health()
```

The exact wire/API representation is an implementation decision and must not leak provider SDK classes or Android framework objects into GGEN's domain model.

## 7. Failure ownership

- GGEN owns user-visible creative failure handling and recovery UX.
- LAI owns provider/runtime failures, retry/failover, device backend failures, permission denial, and tool execution failures.
- GGEN receives normalized failure classes rather than provider-specific exceptions.

## 8. Security boundary

GGEN may request an operation, but LAI decides whether and how it may execute.

```text
GGEN intent
   ↓
LAI policy
   ↓
permission / consent
   ↓
provider or Android tool
   ↓
normalized result
   ↓
GGEN
```

A model response must never be treated as authorization.

## 9. Local vs cloud AI

GGEN should be capable of working with:

- LAI local inference;
- LAI cloud providers;
- LAI custom endpoints;
- LAI hybrid routing.

GGEN therefore does not need to own a second local-model engine or provider router merely to expose these product capabilities.

## 10. Decision rule for future features

1. Creating/editing documents or creative assets → GGEN.
2. Executing an AI model → LAI.
3. Selecting/failing over AI providers → LAI.
4. Android permissions/device automation → LAI.
5. Creative result/document representation/UX → GGEN.
6. Both required → split at the contract boundary; never duplicate the underlying authority.

## 11. Migration rule for existing overlap

Existing duplicated functionality must not be deleted blindly.

For each overlap:

1. identify both implementations;
2. choose canonical owner using this contract;
3. document compatibility requirements;
4. introduce/verify the integration contract;
5. migrate the consumer;
6. remove or freeze the duplicate implementation;
7. add a regression check preventing ownership drift.

## 12. AI Gateway documentation relationship

Generic AI Gateway/provider-routing documentation in GGEN is an **architecture/integration reference**, not permission to create a second provider runtime inside GGEN. Canonical runtime ownership is LAI.

The existing `docs/architecture/ai-gateway-runtime.md` must therefore be interpreted through this boundary until it is fully migrated to the cross-repository contract.

## 13. Completion criterion

The overlap-reduction effort is complete when each capability has one canonical owner, both repositories document the same boundary, no duplicate runtime subsystem is introduced, integration contracts are explicit, provider/device secrets remain in LAI, GGEN remains independently understandable as a creative/document product, LAI remains independently understandable as an Android AI runtime, and research/specification documents point to the correct owner.
