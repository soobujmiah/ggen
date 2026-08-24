# GGEN ↔ LAI AI Capability Contract

**Status:** Proposed architecture contract — documentation only
**Date:** 2026-08-24
**Scope:** GGEN ↔ LAI integration boundary

## 1. Purpose

GGEN and LAI remain separate products and repositories.

- **GGEN** is the user-facing AI Creative & Document Studio.
- **LAI** is an AI intelligence, inference, agent, Android automation, and execution platform.

GGEN shall consume AI capabilities through a provider abstraction. LAI may implement that provider, but GGEN shall not require LAI to operate.

This document defines the boundary before implementation. It does not authorize code changes.

## 2. Architectural boundary

```text
+---------------------------+
| GGEN                      |
| Creative + Document       |
| Studio                    |
|                           |
| AI Capability Interface   |
+-------------+-------------+
              |
              | provider contract
              v
+---------------------------+
| Provider implementations  |
|                           |
| LAI | Cloud | Custom      |
+-------------+-------------+
              |
              v
+---------------------------+
| LAI (when selected)       |
| AI Gateway / Agent        |
| Runtime / Tools           |
| CPU / GPU / NPU / Models  |
+---------------------------+
```

Neither repository becomes a submodule of the other. Neither product owns the other's internal implementation details.

## 3. GGEN responsibilities

GGEN owns:

- creative and document user experience;
- project/document state;
- canvas, vector, raster, painting, typography, PDF and document workflows;
- user-visible AI intent and capability selection;
- provider selection policy at the application level;
- request construction using the capability contract;
- rendering and application of AI results;
- manual workflows that do not require AI or network access;
- user consent for GGEN-visible consequential operations.

GGEN shall not directly depend on:

- llama.cpp internals;
- Vulkan inference implementation;
- Qualcomm QNN/QAIRT implementation;
- LAI Android automation internals;
- LAI model registry internals;
- LAI scheduler internals;
- LAI private audit implementation.

## 4. LAI responsibilities

When LAI is selected as a provider, LAI owns:

- model/runtime selection;
- local inference;
- CPU/GPU/NPU routing;
- device-aware scheduling;
- thermal, memory and battery constraints;
- agent execution;
- Android Accessibility and Shizuku operations;
- tool policy and execution authorization;
- local model lifecycle;
- inference telemetry and diagnostics within LAI's privacy policy;
- provider-specific failures and capability availability.

LAI shall not require GGEN's internal document or canvas model.

## 5. Capability vocabulary

The initial provider-neutral capability vocabulary is:

| Capability | Meaning | Typical output |
|---|---|---|
| `text.generate` | Generate or transform text | text / structured text |
| `vision.analyze` | Analyze supplied visual input | structured/text result |
| `ocr.extract` | Extract text from raster/document input | OCR blocks + text |
| `image.generate` | Generate an image from a prompt/specification | image artifact |
| `image.edit` | Transform an existing image | image artifact |
| `embedding.create` | Produce embeddings | vector(s) |
| `tool.execute` | Execute an explicitly authorized tool operation | structured tool result |
| `agent.run` | Execute a bounded agent task | task/result stream |

The vocabulary is extensible. Adding a capability requires a documented contract and compatibility policy; it does not imply every provider supports it.

## 6. Provider model

A provider advertises capabilities and constraints before use.

Conceptually:

```text
ProviderDescriptor
  id
  displayName
  protocolVersion
  capabilities[]
  modalities[]
  streaming
  cancellation
  authentication
  privacyClass
  localOrRemote
  limits
```

GGEN shall treat capability availability as runtime data. Unsupported capabilities must fail clearly and without pretending to have executed.

## 7. Request envelope

The implementation contract should use a provider-neutral request envelope containing at minimum:

```text
requestId
protocolVersion
capability
inputs[]
options
context
privacyPolicy
requestedOutput
cancellation
```

Inputs are typed artifacts or values rather than provider-specific objects. Examples include text, image references, document fragments, structured JSON, and file/resource references.

Provider-specific fields must be isolated under an explicitly namespaced extension mechanism. They must not leak into the core GGEN document model.

## 8. Response envelope

The provider-neutral response should contain:

```text
requestId
status
outputs[]
usage?
providerMetadata?
error?
```

Outputs are typed artifacts/results. GGEN decides how an output is previewed, inserted, transformed, persisted, or rejected.

Partial/streaming results must be explicitly marked and must not be mistaken for final artifacts.

## 9. Error contract

Errors are structured and provider-neutral at the outer layer.

Minimum categories:

- `unsupported_capability`
- `invalid_request`
- `authentication_required`
- `permission_denied`
- `resource_unavailable`
- `timeout`
- `cancelled`
- `quota_exceeded`
- `policy_blocked`
- `provider_unavailable`
- `execution_failed`
- `invalid_output`

Provider-specific diagnostic detail may be retained as metadata, but application behavior must be driven by stable outer categories.

## 10. Streaming and cancellation

Long-running capabilities may stream progress/results.

Requirements:

- every stream is associated with one `requestId`;
- events are ordered or explicitly sequenced;
- cancellation is idempotent;
- a cancelled operation cannot be presented as completed;
- finalization is explicit;
- partial output must be distinguishable from committed GGEN project state.

## 11. Privacy and data flow

GGEN shall expose enough provider metadata for the user/application to understand whether an operation is:

- local;
- remote;
- cloud;
- custom endpoint.

GGEN shall not silently route a local-intended operation to a remote provider.

LAI remains responsible for its local-first and zero-egress guarantees. Cloud providers remain responsible for their own service policies. GGEN must not represent another provider's privacy guarantees as its own.

## 12. Authentication

Authentication references are provider configuration, not project content.

Credentials, access tokens and secrets must never be embedded in:

- GGEN project files;
- AI request logs;
- diagnostics exports;
- documentation;
- URLs committed to source.

## 13. Tool and agent boundary

`tool.execute` and `agent.run` are higher-risk than ordinary generation capabilities.

GGEN may request them, but authorization and execution policy remain provider-owned when the provider is LAI.

GGEN must not assume that an agent is allowed to perform an operation merely because the provider advertises `agent.run`.

A provider must communicate whether an operation is:

- unavailable;
- requires user approval;
- prepared but not executed;
- executing;
- completed;
- denied;
- failed;
- cancelled.

## 14. Artifact ownership

GGEN owns artifacts once they are accepted into a GGEN project.

Provider runtime state remains provider-owned.

Examples:

- generated image accepted into a GGEN canvas → GGEN artifact;
- LAI model cache → LAI artifact/state;
- LAI tool audit record → LAI audit state;
- cloud provider request ID → provider metadata, not GGEN project identity.

## 15. Compatibility/versioning

The capability protocol must have an explicit version.

Compatibility rules:

- additive capability fields should be backward-compatible;
- removal or semantic change requires a major protocol revision;
- providers advertise the protocol versions they support;
- GGEN must fail closed when it cannot interpret a required contract element;
- capability identifiers are stable and case-sensitive.

## 16. Initial provider set

The architecture permits:

1. LAI provider;
2. OpenAI provider;
3. Gemini provider;
4. Anthropic provider;
5. OpenAI-compatible provider;
6. custom REST provider;
7. remote/self-hosted provider.

The list is descriptive, not an implementation commitment.

## 17. Explicit non-goals

This contract does not:

- merge repositories;
- prescribe a single transport protocol yet;
- embed LAI code into GGEN;
- embed GGEN UI/document code into LAI;
- require local LLM execution inside GGEN;
- define a commercial entitlement model;
- authorize autonomous consequential actions;
- replace either repository's security or licensing policy.

## 18. Implementation gate

No implementation should begin until the following are separately documented and accepted:

1. protocol transport decision;
2. canonical request/response schemas;
3. capability registry/versioning policy;
4. provider discovery/registration mechanism;
5. authentication configuration model;
6. streaming/cancellation semantics;
7. artifact transfer/reference policy;
8. tool/agent authorization semantics;
9. privacy classification model;
10. compatibility and migration tests.

This document is the architecture boundary. Implementation plans must reference it rather than reconstructing the boundary from chat history.
