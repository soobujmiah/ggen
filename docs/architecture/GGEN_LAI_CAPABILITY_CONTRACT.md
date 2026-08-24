# GGEN ↔ LAI Capability Contract v0.1

**Status:** Proposed contract — documentation only
**Date:** 2026-08-24

## 1. Contract principle

The protocol is capability-first and provider-neutral. A GGEN request names a capability, not a vendor or backend. LAI, cloud providers, and custom endpoints may implement the same capability.

The transport is replaceable. The contract must work over loopback HTTP, Android IPC where justified, or remote HTTPS without changing the semantic envelope.

## 2. Request envelope

```json
{
  "protocol_version": "0.1",
  "request_id": "uuid",
  "provider_id": "lai",
  "capability": "text.generate",
  "operation_version": "1",
  "input": {},
  "options": {
    "stream": true,
    "timeout_ms": 30000,
    "max_output_tokens": 1024
  },
  "privacy": {
    "class": "LOCAL_ONLY",
    "consent": "pre_authorized"
  },
  "client": {
    "product": "ggen",
    "version": "..."
  }
}
```

`provider_id` is routing metadata and must never change the meaning of a capability.

## 3. Capability discovery

A provider exposes a discovery document containing:

- protocol versions
- provider identity/version
- capability IDs and operation versions
- input/output schema identifiers
- modalities
- streaming support
- cancellation support
- limits
- privacy classes
- model/runtime information where disclosure is permitted
- execution-evidence level
- health/readiness

Discovery must be safe to call without executing a model or privileged tool.

## 4. Initial capability IDs

| ID | Purpose | Minimum input | Result |
|---|---|---|---|
| `text.generate` | text generation | messages/instructions | text + usage/evidence |
| `vision.analyze` | image understanding | image + prompt | structured/text result |
| `ocr.extract` | OCR | image/document | text blocks + geometry + confidence |
| `image.generate` | image synthesis | prompt/reference | image artifact metadata |
| `image.edit` | image transformation | source + operation | image artifact metadata |
| `embedding.create` | embeddings | text/chunks | vectors + model metadata |
| `structured.generate` | schema-constrained generation | input + schema | validated structured value |
| `workflow.plan` | create/revise workflow plan | task/context | reviewable workflow plan |
| `agent.run` | policy-gated agent task | task/context | events/result |
| `tool.execute` | explicit tool execution | typed tool request | typed tool result |

Capabilities may be implemented incrementally. Unsupported capabilities must return `UNSUPPORTED_CAPABILITY`; they must not be silently emulated.

## 5. Response envelope

```json
{
  "protocol_version": "0.1",
  "request_id": "uuid",
  "status": "completed",
  "result": {},
  "usage": {},
  "evidence": {
    "api_available": true,
    "backend_available": true,
    "backend_accepted": true,
    "operations_delegated": true,
    "execution_completed": true,
    "device_validated": true,
    "performance_measured": false
  },
  "provider": {
    "id": "lai",
    "version": "...",
    "model_id": "..."
  }
}
```

Evidence fields are independent. `backend_available=true` does not imply delegation or execution. `device_validated=true` must refer to a documented device/backend evidence record, not merely a provider declaration.

## 6. Streaming

For streaming capabilities, the provider emits ordered events keyed by `request_id`:

- `started`
- `delta`
- `progress`
- `tool_call`
- `tool_result`
- `completed`
- `failed`
- `cancelled`

Events are transport-neutral. GGEN must tolerate missing optional progress events and must terminate a stream on terminal status.

## 7. Cancellation and timeout

Cancellation is explicit and idempotent. A provider that cannot cancel underlying execution must report that fact rather than claim cancellation succeeded. Timeouts produce a structured terminal error and do not imply that remote work has stopped unless the provider confirms it.

## 8. Errors

Stable error codes:

`INVALID_REQUEST`, `UNSUPPORTED_CAPABILITY`, `POLICY_DENIED`, `AUTHENTICATION_FAILED`, `NOT_READY`, `RATE_LIMITED`, `TIMEOUT`, `CANCELLED`, `TRANSPORT_ERROR`, `MODEL_ERROR`, `TOOL_DENIED`, `EXECUTION_ERROR`, `EVIDENCE_UNAVAILABLE`, `INTERNAL_ERROR`.

Each error may include non-authoritative provider diagnostics, but GGEN routing and UI behavior use the stable code.

## 9. Privacy

Minimum privacy classes:

- `LOCAL_ONLY`
- `LOCAL_PREFERRED`
- `CLOUD_ALLOWED`
- `ASK_FIRST`
- `SENSITIVE_LOCAL_ONLY`

The provider must reject a request whose privacy policy it cannot satisfy. No provider may silently redirect a `LOCAL_ONLY` request to cloud execution.

## 10. Security and authority

`tool.execute` and `agent.run` are privileged capability classes. They require risk metadata, explicit policy evaluation, and provider-side authority controls. Installing or selecting a provider never grants arbitrary Android/device authority to GGEN.

Secrets are referenced through secure credential identifiers. API keys, access tokens and private headers never enter project files, diagnostics exports or ordinary request logs.

## 11. Compatibility

A provider may add optional fields, but it must preserve the semantics of a supported operation version. Breaking schema changes require a new operation version. Protocol version and operation version are independent so transport/protocol evolution does not force capability rewrites.

## 12. Contract-test requirements

Every provider adapter must pass fixtures for:

1. discovery
2. supported capability
3. unsupported capability
4. malformed request
5. normal response
6. streaming response
7. cancellation
8. timeout
9. authentication failure
10. policy denial
11. provider unavailable
12. evidence fields
13. secret redaction
14. deterministic error mapping

## 13. First implementation boundary

The first production contract should be limited to `text.generate` and `ocr.extract`. This deliberately avoids prematurely coupling image generation, agents, device tools or workflow execution to the first protocol version.

The mock provider must be implemented and contract-tested before the LAI adapter. The LAI adapter must then expose real capability discovery and honest evidence without changing GGEN's document/canvas domain.
