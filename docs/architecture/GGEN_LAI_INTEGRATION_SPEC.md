# GGEN ↔ LAI Integration Specification

**Status:** Canonical cross-repository integration contract
**Date:** 2026-08-24
**Scope:** GGEN Creative & Document Studio ↔ LAI AI/runtime platform

## 1. Purpose

This document defines the boundary between GGEN and LAI. It is an integration contract, not permission to merge the repositories or duplicate runtime infrastructure.

## 2. Non-negotiable boundary

- GGEN remains the user-facing Creative + Document Studio.
- LAI remains the AI intelligence, inference, agent, automation and execution platform.
- Repositories remain independent.
- GGEN MUST NOT embed llama.cpp, Vulkan, QNN, device scheduling, Android automation, provider adapters, provider secrets, or LAI model-runtime internals merely to obtain AI capabilities.
- LAI MUST NOT become a required dependency for basic GGEN editing, document production, import/export, or offline non-AI workflows.
- Communication occurs through versioned capability contracts.
- Either side may evolve independently when the contract remains compatible.

## 3. Capability ownership

The capability is requested by GGEN, but runtime authority is owned by LAI where the capability concerns AI execution or Android/device execution.

| Capability | GGEN responsibility | LAI responsibility |
|---|---|---|
| `text.generate` | request/context/result UX | model/provider execution |
| `vision.analyze` | document/image context and result UX | multimodal execution |
| `ocr.extract` | source/result document workflow | OCR execution where supplied by runtime |
| `image.generate` | creative workflow and editable result | generation provider/runtime |
| `image.edit` | selection/mask/document integration | image model/provider execution |
| `embedding.create` | knowledge/document use | embedding runtime/provider |
| `document.transform` | document semantics and user approval | AI transformation execution |
| `tool.execute` | request declared capability | policy, permission and execution authority |
| `agent.run` | task objective and user-facing controls | bounded agent runtime and execution authority |

## 4. Provider ownership

**LAI is the canonical owner of provider adapters, provider routing/failover, runtime credentials, model execution selection, and execution evidence.**

GGEN may present provider choices and user policy controls, but those are expressed as runtime constraints/preferences. GGEN MUST NOT maintain a second provider adapter/router stack for the same providers.

Preferred topology:

```text
GGEN
  Creative/Product UX
       |
       | capability contract + user constraints
       v
LAI Runtime Gateway
       |
   +---+---------+----------------+
   |             |                |
 Local runtime  Cloud providers  Custom endpoints
 CPU/GPU/NPU    OpenAI/etc.       LAN/remote
```

A future GGEN direct external-provider adapter is a client-side compatibility/fallback mechanism only; it must not duplicate LAI's Android/device authority or become a second canonical runtime. Any such adapter requires an explicit ADR and ownership review.

## 5. Initial capability identifiers

- `text.generate`
- `vision.analyze`
- `ocr.extract`
- `image.generate`
- `image.edit`
- `embedding.create`
- `document.transform`
- `tool.execute`
- `agent.run`

Unknown capabilities MUST fail with a typed unsupported-capability error.

## 6. Canonical request envelope

A transport may use JSON, HTTP, local IPC, Android Binder, or another mechanism. The logical envelope remains stable.

```json
{
  "protocol_version": "1.0",
  "request_id": "uuid",
  "capability": "text.generate",
  "operation": "generate",
  "source": {"application": "ggen", "application_version": "..."},
  "input": {},
  "context": {},
  "constraints": {
    "execution": "auto",
    "privacy": "local_preferred",
    "latency_class": "interactive",
    "max_cost": null
  },
  "stream": false,
  "metadata": {}
}
```

Requirements: unique request ID; explicit capability; explicit media/document references; no implicit shared filesystem paths; secrets excluded from ordinary metadata.

## 7. Canonical response envelope

```json
{
  "protocol_version": "1.0",
  "request_id": "uuid",
  "status": "success",
  "output": {},
  "provider": {"id": "lai", "execution": "local"},
  "usage": {},
  "provenance": {},
  "warnings": [],
  "error": null
}
```

Statuses: `success`, `partial`, `failed`, `cancelled`, `unsupported`, `denied`, `timeout`.

## 8. Error contract

Stable machine-readable errors include `invalid_request`, `unsupported_capability`, `unsupported_version`, `authentication_failed`, `authorization_denied`, `privacy_policy_denied`, `provider_unavailable`, `model_unavailable`, `resource_exhausted`, `input_invalid`, `output_invalid`, `tool_denied`, `timeout`, `cancelled`, and `internal_error`.

The runtime decides retry/failover. GGEN receives normalized errors and presents appropriate UX.

## 9. Discovery, health, streaming and cancellation

LAI/runtime providers SHOULD expose protocol version, identity/version, supported capabilities/media, streaming/cancellation support, authentication mode, execution locality and health/readiness. GGEN MUST NOT infer support from provider names.

Interactive generation SHOULD support streaming. Stream events carry request ID and monotonic sequence number. Cancellation is explicit and must eventually resolve to a terminal state.

## 10. File and media boundary

No hidden shared data directory between repositories. Prefer bounded payloads for small content, explicit expiring file/blob references, or provider-managed transfer. Arbitrary filesystem paths MUST NOT cross the boundary.

## 11. Privacy and execution locality

GGEN expresses `local_only`, `local_preferred`, `cloud_allowed`, `remote_allowed`, or `network_required`. LAI enforces runtime execution policy. `local_only` MUST never silently leave the device.

GGEN remains usable if LAI is absent; manual/non-AI workflows never depend on LAI.

## 12. Tool and agent boundary

GGEN requests capabilities; LAI owns policy, permission and execution. Tool requests must be explicitly declared, schema-validated, authorized, bounded, auditable, and fail closed when uncertain. For Android automation, LAI owns Accessibility/Shizuku/runtime safety; GGEN communicates intent rather than privileged handles.

A bounded agent request carries objective, selected resource IDs, allowed capabilities/tools, constraints, confirmation policy, timeout and desired output type. The agent must not expand authority silently.

## 13. Fallback and idempotency

Provider fallback is a runtime concern. The runtime may move from preferred local execution to another allowed provider only when privacy, cost, capability and side-effect constraints permit it. `local_only` and non-idempotent side effects block unsafe fallback.

Read/generation operations SHOULD support safe retries. Side-effecting operations MUST use an idempotency key or equivalent where practical; a timeout must not accidentally duplicate edits, files, external actions or charges.

## 14. Authentication and versioning

Authentication is transport-specific. Provider credentials are runtime-owned and must never be persisted in ordinary GGEN project documents.

Protocol and capability versions are independent. Additive optional fields should remain compatible; breaking changes require a new version.

## 15. Observability and provenance

AI operations SHOULD produce request ID, capability, provider/runtime identity, execution locality, duration, status, usage/cost where available, warnings and evidence level. This does not authorize exposing private prompts or document contents.

## 16. Contract ownership

GGEN owns creative/document UX, creative/document domain state, document selection/context assembly, user-facing AI preferences/constraints, presentation/incorporation of AI results, and offline non-AI functionality.

LAI owns provider adapters/connectivity, routing/failover, local inference backends, model lifecycle/execution, device scheduling, agent runtime, privileged Android automation, runtime security/audit, execution evidence and runtime telemetry.

Neither repository owns the other's internals.

## 17. Implementation sequence

### P0 — Contract reconciliation

Freeze capability IDs, request/response/error schemas, discovery/health, privacy constraints, media references and versioning. Reconcile all existing provider/router documentation in both repositories with this ownership decision before implementation.

### P1 — LAI runtime gateway

Implement the runtime-side contract in LAI without disturbing existing CPU/device-validated paths.

### P2 — GGEN client integration

Add only the GGEN client/transport/capability layer required to consume LAI. Existing GGEN AI UX remains independent of runtime internals.

### P3 — End-to-end validation

Validate text, OCR, vision, image generation/editing, cancellation, unavailable providers, local-only policy, malformed requests, unsupported capabilities, timeout/retry/idempotency and provenance. Expand only after the smallest contract is stable.

## 18. Explicit non-goals

This specification does not authorize moving LAI code into GGEN, moving GGEN's document model into LAI, embedding a second canonical provider/runtime stack in GGEN, unrestricted agent filesystem/shell access, direct GGEN coupling to llama.cpp/Vulkan/QNN, replacing manual workflows with AI-only workflows, or making LAI mandatory for GGEN startup/basic editing.

## 19. Agent instruction

Before implementation, inspect current repository architecture, source, tests and documentation in **both** repositories. Preserve working behavior. The first implementation task is contract reconciliation and repository-specific mapping, not a large refactor.
