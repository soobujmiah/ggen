# GGEN ↔ LAI Integration Specification

**Status:** Architecture baseline / implementation contract
**Date:** 2026-08-24
**Scope:** GGEN Creative & Document Studio ↔ LAI AI/runtime platform

## 1. Purpose

This document defines the architectural boundary between GGEN and LAI. It is intentionally implementation-oriented: coding agents should treat this document as the contract to implement against, not as permission to merge the two repositories.

## 2. Non-negotiable boundary

- GGEN remains a user-facing Creative + Document Studio.
- LAI remains an AI intelligence, inference, agent, automation and execution platform.
- Repositories remain independent.
- GGEN MUST NOT embed llama.cpp, Vulkan, QNN, device scheduling, Android automation, or LAI model-runtime internals merely to obtain AI capabilities.
- LAI MUST NOT become a required dependency for basic GGEN editing, document production, import/export, or offline non-AI workflows.
- Communication occurs through versioned capability contracts.
- Either side may evolve independently when the contract remains compatible.

## 3. Capability model

The integration is capability-oriented rather than provider-oriented. GGEN asks for a capability; a provider decides how to satisfy it.

Initial capability identifiers:

| Capability | Purpose |
|---|---|
| `text.generate` | Generate or transform text |
| `vision.analyze` | Analyze an image/document visual input |
| `ocr.extract` | Extract text/layout from an image or document |
| `image.generate` | Generate an image from a prompt/specification |
| `image.edit` | Edit an existing image |
| `embedding.create` | Create embeddings |
| `document.transform` | AI-assisted document transformation |
| `tool.execute` | Execute an explicitly authorized tool operation |
| `agent.run` | Run a bounded agent task |

Capabilities are extensible. Unknown capabilities MUST fail with a typed unsupported-capability error; clients MUST NOT silently reinterpret them.

## 4. Provider abstraction

GGEN SHOULD expose a provider registry with providers such as:

- `lai`
- `openai`
- `gemini`
- `anthropic`
- `openai_compatible`
- `custom_http`
- future local/remote providers

The GGEN UI and domain model SHOULD depend on capability interfaces, not provider-specific SDKs.

Preferred routing examples:

```text
GGEN → LAI → local CPU
GGEN → LAI → Vulkan/GPU
GGEN → LAI → QNN/NPU
GGEN → LAI → remote model/server
GGEN → cloud provider
GGEN → custom endpoint
```

## 5. Canonical request envelope

A transport implementation may use JSON, HTTP, local IPC, Unix socket, Android Binder, or another mechanism. The logical envelope remains stable.

```json
{
  "protocol_version": "1.0",
  "request_id": "uuid",
  "capability": "text.generate",
  "operation": "generate",
  "source": {
    "application": "ggen",
    "application_version": "..."
  },
  "input": {},
  "context": {},
  "constraints": {
    "latency_class": "interactive",
    "privacy": "local_preferred",
    "max_cost": null
  },
  "stream": false,
  "metadata": {}
}
```

Requirements:

- `request_id` MUST be unique per request.
- `capability` MUST be explicit.
- Inputs MUST identify media/document references rather than relying on implicit shared filesystem paths.
- Constraints are advisory unless the provider explicitly declares support.
- Secrets MUST NOT be placed in ordinary metadata.

## 6. Canonical response envelope

```json
{
  "protocol_version": "1.0",
  "request_id": "uuid",
  "status": "success",
  "output": {},
  "provider": {
    "id": "lai",
    "execution": "local"
  },
  "usage": {},
  "provenance": {},
  "warnings": [],
  "error": null
}
```

`status` values:

- `success`
- `partial`
- `failed`
- `cancelled`
- `unsupported`
- `denied`
- `timeout`

A successful response MUST NOT imply that the result is authoritative or verified. Provenance and warnings should communicate model/provider limitations.

## 7. Error contract

Errors MUST be machine-readable and stable.

Recommended classes:

- `invalid_request`
- `unsupported_capability`
- `unsupported_version`
- `authentication_failed`
- `authorization_denied`
- `privacy_policy_denied`
- `provider_unavailable`
- `model_unavailable`
- `resource_exhausted`
- `input_invalid`
- `output_invalid`
- `tool_denied`
- `timeout`
- `cancelled`
- `internal_error`

Errors MUST NOT cause an automatic provider fallback when the operation has side effects unless the policy explicitly allows it.

## 8. Discovery and health

A provider SHOULD expose:

```text
GET/inspect → protocol version
              provider identity
              supported capabilities
              supported media
              streaming support
              cancellation support
              authentication mode
              execution locality
              health/readiness
```

Capability discovery MUST be explicit. GGEN MUST NOT infer support from a provider name.

## 9. Streaming and cancellation

Interactive generation SHOULD support streaming when available. Every streamed event carries `request_id` and a monotonic sequence number.

Cancellation is best-effort but MUST be explicit. A cancelled operation MUST eventually resolve to `cancelled` or a terminal provider error; it MUST NOT remain indefinitely ambiguous.

## 10. File and media boundary

Do not establish a hidden shared data directory between repositories.

Preferred mechanisms, in order of suitability:

1. bounded request payload for small content;
2. explicit file/blob reference with ownership and expiry metadata;
3. provider-managed upload/download channel;
4. future platform-specific transport adapter.

A file reference MUST specify enough information for the receiver to determine ownership, type, size and lifetime. Arbitrary filesystem paths MUST NOT cross the boundary.

## 11. Privacy and execution locality

GGEN SHOULD express user intent such as:

- `local_only`
- `local_preferred`
- `cloud_allowed`
- `remote_allowed`
- `network_required`

A provider MUST reject a request when its execution policy violates a `local_only` constraint.

GGEN remains usable if LAI is absent. LAI is a preferred provider, not a hidden runtime dependency.

## 12. Tool execution boundary

`tool.execute` and `agent.run` are higher-risk capabilities.

GGEN MUST NOT grant LAI unrestricted authority over the host application or user filesystem. Tool requests must be:

1. explicitly declared;
2. schema validated;
3. authorized according to policy;
4. bounded in scope;
5. auditable;
6. denied closed when validation/authorization is uncertain.

For Android automation, LAI remains responsible for its own Accessibility/Shizuku/runtime safety boundary. GGEN communicates intent, not raw privileged handles.

## 13. Agent boundary

GGEN may ask LAI to perform a bounded agent task, for example:

```text
"Improve the selected document's layout while preserving its content."
```

The request should carry:

- task objective;
- selected resource IDs;
- allowed capabilities/tools;
- constraints;
- confirmation policy;
- timeout;
- desired output type.

The agent MUST NOT silently expand authority from a document task into unrelated system operations.

## 14. Fallback policy

Provider fallback is a routing concern, not an implementation detail hidden inside every feature.

Example:

```text
preferred: LAI/local
       ↓ unavailable
allowed: OpenAI-compatible remote
       ↓ unavailable
allowed: another configured provider
       ↓ all unavailable
GGEN returns a truthful AI-unavailable state
```

Fallback MUST respect privacy, cost, capability and side-effect constraints. No fallback is allowed when doing so would violate `local_only` or execute a non-idempotent side effect twice.

## 15. Idempotency and side effects

Read/generation operations SHOULD support safe retries. Side-effecting operations MUST support an idempotency key or equivalent mechanism where practical.

The same request MUST NOT accidentally create duplicate files, duplicate edits, duplicate external actions, or duplicate charges after a timeout.

## 16. Authentication and trust

Authentication is transport-specific and MUST NOT be encoded into the capability semantics.

Examples include:

- local process trust;
- Android app identity/IPC authorization;
- API key/token for remote providers;
- mutual authentication in future deployments.

Credentials MUST be stored and handled by the provider/transport security layer, not persisted in ordinary GGEN project documents.

## 17. Versioning

Protocol and capability versions are independent.

- Protocol uses semantic compatibility rules.
- Capability schemas are versioned when their input/output semantics change.
- Additive optional fields SHOULD remain backward compatible.
- Breaking changes require a new version.
- Providers MUST advertise supported versions.

GGEN SHOULD retain a compatibility adapter rather than scattering version checks throughout UI code.

## 18. Observability and provenance

Every AI operation SHOULD produce a structured record containing:

- request ID;
- capability;
- provider;
- execution locality;
- model/runtime identity where available;
- duration;
- status;
- usage/cost where available;
- warnings;
- provenance/reference information.

This is diagnostic/provenance data, not permission to expose private prompts or document contents.

## 19. Contract ownership

GGEN owns:

- user experience;
- creative/document domain model;
- document selection/context assembly;
- provider selection policy from the user's perspective;
- presentation of AI results;
- offline non-AI functionality.

LAI owns:

- model/runtime execution;
- local inference backends;
- device-aware scheduling;
- agent runtime;
- privileged Android automation;
- model lifecycle;
- runtime security/audit;
- AI execution telemetry.

Neither repository owns the other's internals.

## 20. Initial implementation sequence

### P0 — Contract only

1. Freeze capability IDs.
2. Define request/response/error schemas.
3. Define discovery/health contract.
4. Define privacy/execution constraints.
5. Define file/media reference contract.
6. Define versioning rules.

### P1 — GGEN provider layer

1. Introduce provider/capability interfaces.
2. Add a mock provider.
3. Add a generic HTTP/OpenAI-compatible adapter where appropriate.
4. Ensure all AI features can operate without LAI.

### P2 — LAI gateway adapter

1. Implement the protocol endpoint in LAI.
2. Map capabilities to LAI services.
3. Return truthful unsupported/error states.
4. Preserve LAI's existing safety/audit boundaries.

### P3 — End-to-end validation

Test:

- text generation;
- OCR;
- vision;
- image generation/editing;
- embedding;
- bounded agent task;
- cancellation;
- unavailable provider;
- local-only policy;
- malformed request;
- unsupported capability;
- timeout/retry/idempotency;
- provenance.

## 21. Explicit non-goals

This specification does NOT authorize:

- moving LAI code into GGEN;
- moving GGEN's document model into LAI;
- embedding an LLM runtime in GGEN merely for convenience;
- giving an AI agent unrestricted filesystem/shell access;
- coupling GGEN UI directly to llama.cpp/Vulkan/QNN;
- replacing manual workflows with AI-only workflows;
- making LAI mandatory for GGEN startup or basic editing.

## 22. Agent instruction

Before implementing this contract, an agent MUST inspect the current repository architecture and existing documentation. It MUST preserve existing working behavior and tests unless a documented architectural change requires otherwise. Any deviation from this specification must be documented first and explicitly approved.

The next implementation task should be a contract review and repository-specific mapping, not an immediate large refactor.
