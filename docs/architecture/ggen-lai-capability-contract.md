# GGEN ↔ LAI Capability Contract

**Status:** Authoritative GGEN-side semantic contract, v0.1
**Date:** 2026-08-24

## Purpose

GGEN is the user-facing AI Creative & Document Studio. LAI is an optional AI provider/runtime. The repositories remain independent; neither is a source dependency or submodule of the other.

This document defines the semantic boundary. Transport, authentication and concrete adapter implementations are separate concerns.

## Ownership

| Concern | GGEN | LAI |
|---|---|---|
| Creative/document UX | **Owner** | Consumer context only |
| Project/artifact semantics | **Owner** | No ownership |
| AI provider selection intent | **Owner** | Enforces runtime/policy constraints |
| Local inference/runtime | Provider consumer | **Owner** |
| Model lifecycle/runtime backends | Provider metadata consumer | **Owner** |
| Device scheduling/thermal admission | No | **Owner** |
| Android automation authority | No arbitrary authority | **Owner** |
| AI execution evidence | Displays/propagates | **Owner of runtime evidence** |
| Manual operation | **Must remain complete** | Not required |

## Capability vocabulary

Initial stable semantic IDs:

- `text.generate`
- `vision.analyze`
- `ocr.extract`
- `image.generate`
- `image.edit`
- `embedding.create`
- `structured.generate`
- `workflow.plan`
- `agent.run`
- `tool.execute`

The protocol is capability-oriented rather than provider-oriented. A provider may implement only a subset.

## Request envelope

A provider request shall carry, at minimum:

- `protocol_version`
- `request_id`
- `operation`
- `input` / typed payload
- `privacy_class`
- `routing_intent`
- `streaming` and cancellation semantics
- optional model/quality/latency/cost constraints
- optional correlation metadata that contains no secret

Recommended privacy classes:

- `LOCAL_ONLY`
- `LOCAL_PREFERRED`
- `CLOUD_ALLOWED`
- `ASK_BEFORE_REMOTE`

A `LOCAL_ONLY` request is a hard boundary. Providers must not silently route it to cloud/remote execution.

## Response envelope

A provider response shall carry:

- `protocol_version`
- `request_id`
- operation result or typed error
- provider identity/version
- model/runtime metadata when permitted
- execution evidence
- cancellation/completion state
- limitations/fallback information

Streaming responses use ordered events and must support cancellation without leaving an ambiguous completion state.

## Execution evidence

Evidence is monotonic and must never be inferred from a weaker state:

`API_AVAILABLE → BACKEND_AVAILABLE → BACKEND_ACCEPTED → OPERATIONS_DELEGATED → EXECUTION_COMPLETED → DEVICE_VALIDATED → PERFORMANCE_MEASURED`

The GGEN UI may display evidence but must not upgrade it. Missing values remain `UNKNOWN`.

`DEVICE_VALIDATED` means physical evidence exists for the specific device/backend/build/workload. `PERFORMANCE_MEASURED` means a measured value exists with sufficient scope to interpret it.

## Errors

Errors shall be typed and actionable. Minimum semantic classes:

- `UNSUPPORTED_CAPABILITY`
- `INVALID_REQUEST`
- `AUTH_REQUIRED`
- `POLICY_DENIED`
- `PRIVACY_DENIED`
- `MODEL_UNAVAILABLE`
- `BACKEND_UNAVAILABLE`
- `RESOURCE_LIMIT`
- `CANCELLED`
- `TIMEOUT`
- `EXECUTION_FAILED`
- `PROVIDER_UNAVAILABLE`
- `INTERNAL_ERROR`

Provider-specific detail may be included as non-authoritative diagnostic metadata.

## Tool and agent boundary

`agent.run` and `tool.execute` are privileged capabilities, not ordinary model-generation calls. LAI remains the authority for Android/system tools, permission, confirmation, audit and execution policy. Model-generated arguments are untrusted and cannot self-authorize execution.

GGEN may request a plan or an explicitly defined capability, but selecting LAI must never grant arbitrary LAI authority.

## Provider neutrality

The same semantic contract may be implemented by:

- LAI
- OpenAI-compatible services
- Gemini/Anthropic or other cloud adapters
- self-hosted/LAN services
- custom REST endpoints
- GGEN plugins

GGEN must remain useful in `MANUAL` mode without any AI provider.

## Initial implementation gate

Do not begin production cross-repository runtime integration until these artifacts exist:

1. this semantic contract;
2. GGEN mock provider + contract fixtures;
3. LAI capability discovery/adapter mapping;
4. streaming/cancellation tests;
5. typed error mapping;
6. evidence fixtures;
7. privacy routing tests;
8. Redmi Turbo 4 Pro end-to-end validation;
9. documentation of measured behavior.

Initial production capability scope should be deliberately small: `text.generate` first, then `ocr.extract` only after a real OCR model is available. Image, embedding, workflow, agent and tool exposure follow the same contract but are not implicitly implemented by this document.
