# GGEN ↔ LAI Capability Contract

**Status:** Proposed cross-repository contract — documentation only
**Version:** 0.1
**Date:** 2026-08-24

## 1. Purpose

This document defines the semantic boundary between GGEN and LAI. It is intentionally provider- and transport-neutral. It does **not** make GGEN dependent on LAI internals, and it does not require LAI to become part of the GGEN repository.

- **GGEN** owns the Creative & Document Studio domain: projects, documents, canvas semantics, creative tools, templates, workflows, exports, and AI-assisted creative UX.
- **LAI** owns local-first AI intelligence/runtime concerns: inference, model lifecycle, backend execution, device-aware scheduling, agent policy, Android automation authority, OCR execution, audit and runtime evidence.
- Cloud providers and custom endpoints remain valid alternatives to LAI.

GGEN must remain useful for manual work without AI or network access.

## 2. Provider model

```text
                         GGEN
              Creative / Document domain
                         |
                 AI Capability API
                         |
          +--------------+--------------+
          |              |              |
         LAI          Cloud          Custom
          |           provider        endpoint
     local/remote
     AI runtime
          |
     CPU / GPU / NPU
```

LAI is the preferred local provider, not a hard dependency.

## 3. Capability namespace

Capability IDs are stable semantic identifiers, not implementation class names.

| Capability | Meaning | Initial priority |
|---|---|---:|
| `text.generate` | Generate text from a prompt/context | P0 |
| `ocr.extract` | Extract structured text from an image/document | P0 |
| `vision.analyze` | Analyze visual input | P1 |
| `structured.generate` | Generate schema-constrained structured output | P1 |
| `image.generate` | Generate an image from a request | P1 |
| `image.edit` | Transform/edit supplied image content | P1 |
| `embedding.create` | Produce embeddings for search/RAG | P2 |
| `workflow.plan` | Produce an executable workflow plan | P2 |
| `agent.run` | Run a policy-gated agent task | P2 |
| `tool.execute` | Request execution of an explicitly defined capability | P2 |

A provider may implement only a subset. Capability discovery is mandatory before assuming support.

## 4. Request envelope

Every operation should have a versioned envelope with these semantic fields:

```text
protocol_version
request_id
capability
input
constraints
privacy
routing
context
streaming
cancellation
```

### Privacy

Minimum privacy classes:

- `LOCAL_ONLY` — content must not leave the device.
- `USER_APPROVED_REMOTE` — remote execution is permitted only by explicit user policy/consent.
- `UNSPECIFIED` — provider selection follows the application's configured policy; it must never silently upgrade a local-only operation to remote execution.

### Constraints

Constraints may include quality, latency, token/output limits, model preference, structured-output schema, image dimensions, and deadline. Providers must reject unsupported constraints explicitly rather than silently ignoring safety-critical constraints.

## 5. Response envelope

Responses should contain:

```text
protocol_version
request_id
status
output
usage
provider
model
execution_evidence
warnings
error
```

`usage` and model metadata are optional where the provider cannot safely expose them.

## 6. Execution evidence

Evidence is monotonic and must describe what actually happened:

`API_AVAILABLE → BACKEND_AVAILABLE → BACKEND_ACCEPTED → OPERATIONS_DELEGATED → EXECUTION_COMPLETED → DEVICE_VALIDATED → PERFORMANCE_MEASURED`

A provider must not claim a later state without evidence for every required earlier state. Unknown values remain unknown. GGEN must display or preserve provider evidence without strengthening its certainty.

For LAI, this maps to its runtime/backend evidence model. In particular, the existence of a Vulkan/QNN backend must not be represented as proof of actual GPU/NPU execution.

## 7. Streaming and cancellation

Long-running operations should support incremental output where the capability permits it. Cancellation is cooperative and must produce a terminal `CANCELLED` result. A provider must not report `COMPLETED` after cancellation unless the documented protocol semantics explicitly distinguish an already-completed operation from a late cancellation request.

## 8. Error model

Errors are typed and actionable. Minimum semantic categories:

- `UNSUPPORTED_CAPABILITY`
- `INVALID_REQUEST`
- `INVALID_INPUT`
- `POLICY_DENIED`
- `AUTH_REQUIRED`
- `AUTH_FAILED`
- `MODEL_UNAVAILABLE`
- `BACKEND_UNAVAILABLE`
- `RESOURCE_LIMIT`
- `TIMEOUT`
- `CANCELLED`
- `NETWORK_UNAVAILABLE`
- `PROVIDER_UNAVAILABLE`
- `EXECUTION_FAILED`
- `PROTOCOL_MISMATCH`

Provider-specific diagnostic details may be attached, but GGEN must not depend on private LAI/Kotlin/JNI exception classes.

## 9. Tool and agent boundary

`agent.run` and `tool.execute` do not grant arbitrary authority merely because LAI is selected as a provider.

- Model output is untrusted data.
- Tool arguments must be validated against a declared schema.
- Consequential Android actions remain subject to LAI policy and user consent.
- GGEN can request a capability; LAI decides whether its runtime policy permits execution.
- No model-generated output can self-authorize privileged execution.

## 10. Transport neutrality

The semantic contract does not select a transport. Candidate implementations include:

1. loopback HTTP for a local provider service;
2. Android IPC where lifecycle/security characteristics justify it;
3. remote HTTPS for LAN/cloud/custom providers.

Transport authentication, authorization, replay protection and lifecycle semantics must be specified before production cross-process integration.

## 11. Failure and fallback

Provider failure must not destroy manual GGEN operation.

Fallback is policy-driven, never silent:

```text
LOCAL_ONLY + LAI unavailable
    → fail explicitly / allow manual operation

remote permitted + preferred provider unavailable
    → next configured provider may be selected

LOCAL_ONLY
    → never fall back to cloud/remote
```

A provider router should expose the reason for the selected provider so the UI can explain routing decisions without exposing secrets.

## 12. Credentials and data boundary

API keys, bearer tokens, keystore material and other credentials must never enter GGEN project files, ordinary logs, diagnostics exports, source control or the semantic capability envelope.

GGEN sends only the content and context necessary for the requested capability under the selected privacy policy. LAI enforces its local/runtime policy and must not create an undeclared egress path.

## 13. Contract versioning

The protocol uses semantic versioning at the contract level. Providers advertise supported protocol versions and capability versions during discovery.

Breaking changes require a new major protocol version. Additive capabilities and optional fields should remain backward-compatible. Unknown optional fields must be safely ignored; unknown required semantics must fail with `PROTOCOL_MISMATCH` rather than being guessed.

## 14. Initial implementation gate

No production GGEN ↔ LAI integration should begin until these documentation gates are accepted:

1. this contract is reviewed and approved;
2. GGEN has a mock provider and contract fixtures;
3. LAI has a provider adapter/capability-discovery implementation;
4. `text.generate` is validated end-to-end;
5. cancellation, privacy, error and evidence semantics are tested;
6. the Redmi Turbo 4 Pro path is physically validated where applicable;
7. only then should `ocr.extract` and later multimodal/agent/tool capabilities be exposed cross-repository.

## 15. Non-goals

This document does not:

- merge GGEN and LAI repositories;
- require llama.cpp, Vulkan, QNN or any model runtime inside GGEN;
- select a mandatory transport;
- claim that planned LAI gateway/remote capabilities already exist;
- authorize arbitrary Android automation from GGEN;
- replace either repository's internal architecture documentation.

## 16. Source alignment

This contract aligns with GGEN's existing provider/router/evidence direction and LAI's documented integration boundary and capability reference. Those documents remain implementation-specific references; this document is the GGEN-side cross-repository semantic contract.
