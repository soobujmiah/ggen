# GGEN ↔ LAI Architecture

**Status:** Proposed authoritative cross-repository architecture
**Date:** 2026-08-24
**Repositories:** `soobujmiah/ggen` and `soobujmiah/lai`

## 1. Purpose

GGEN and LAI remain separate products and repositories. This document defines the boundary so future implementation agents do not accidentally merge responsibilities, duplicate runtimes, or create hidden coupling.

## 2. Product ownership

### GGEN — AI Creative & Document Studio

GGEN owns the user-facing creative/document workspace and the project domain:

- vector, raster, painting and typography workflows
- document/PDF/template creation and reconstruction
- canvas, layers, selection, text layout and professional editing tools
- assets, projects, export/import and workflow authoring
- manual operation without AI or network
- AI-assisted creative/document operations through provider abstractions
- plugin-facing creative capabilities

The current GGEN master specification explicitly requires manual, local-AI, cloud-AI, custom-endpoint and hybrid modes and a capability-driven provider abstraction. See `MASTER_SPEC.md`.

### LAI — Local-first AI intelligence/runtime platform

LAI owns intelligence and execution infrastructure:

- inference engines and model/runtime lifecycle
- CPU/GPU/NPU backend adapters and accelerator evidence
- AI routing/scheduling and device-aware execution
- agent runtime and policy-gated tool execution
- Android Accessibility/Shizuku automation
- OCR runtime seam and multimodal AI infrastructure
- RAG/memory and AI gateway capabilities
- remote/custom AI endpoint infrastructure where appropriate
- developer-AI execution infrastructure
- audit, diagnostics and security controls around AI/tool execution

LAI's current project state already separates inference contracts, scheduler/backend evidence, agent/tool policy, accessibility and diagnostics into explicit modules.

## 3. Non-goals

- Do not merge the repositories.
- Do not make GGEN depend exclusively on LAI.
- Do not embed llama.cpp, Vulkan, QNN or model-runtime implementation into GGEN merely to obtain local AI.
- Do not move GGEN creative-domain logic into LAI.
- Do not make LAI a UI/plugin dependency of GGEN.
- Do not treat an API-compatible provider as proof of accelerator execution.

## 4. Target topology

```text
                         USER
                           |
                           v
                 +-------------------+
                 |       GGEN        |
                 | Creative + Docs   |
                 +---------+---------+
                           |
                 AI Capability Contract
                           |
          +----------------+----------------+
          |                |                |
          v                v                v
         LAI           Cloud provider   Custom endpoint
          |
   AI / Agent / Runtime
          |
   CPU / GPU / NPU / Models
```

GGEN is therefore a **consumer of AI capabilities**, not an inference-runtime owner.

## 5. Capability contract

The integration must be capability-driven rather than provider-name-driven. Initial capability vocabulary:

| Capability | Example operation | Preferred local implementation |
|---|---|---|
| Text generation | `text.generate` | LAI inference |
| Vision analysis | `vision.analyze` | LAI multimodal runtime |
| OCR | `ocr.extract` | LAI OCR |
| Image generation | `image.generate` | provider-dependent |
| Image editing | `image.edit` | provider-dependent |
| Embeddings | `embedding.create` | LAI/local or cloud |
| Tool execution | `tool.execute` | LAI agent/tool gateway |
| Agent execution | `agent.run` | LAI |
| Structured output | `structured.generate` | provider-dependent |
| Workflow assistance | `workflow.plan` | LAI or cloud |

Capabilities must advertise their input/output contract, streaming support, limits, privacy classification, cost class and evidence state.

## 6. Provider model

GGEN should expose a provider abstraction with adapters for:

- LAI
- OpenAI
- Gemini
- Anthropic
- OpenAI-compatible endpoints
- Custom REST endpoints
- Plugins

LAI is the preferred local/on-device provider, not a mandatory dependency.

A provider adapter must not leak provider-specific objects into GGEN's core domain model. Provider-specific request/response mapping belongs behind the adapter.

## 7. Transport

The first integration should use a versioned capability API over a replaceable transport. Candidate transports are local HTTP/loopback, Android IPC/binder where justified, and remote HTTP(S). The contract must remain transport-neutral.

Minimum metadata:

```text
protocol_version
provider_id
provider_version
capability
request_id
streaming
privacy_class
model_id
limits
execution_evidence
```

## 8. Execution evidence

Every provider response that can claim hardware/runtime execution must distinguish:

1. API available
2. backend available
3. delegate/backend accepted
4. operations actually delegated
5. execution completed
6. device/backend validated
7. performance measured

GGEN may display evidence but must never infer GPU/NPU use from a provider label alone.

## 9. Privacy boundary

GGEN owns the user's content-routing intent. LAI owns local execution and its runtime/security enforcement. A cloud provider may receive content only when GGEN's policy permits it and the provider adapter can report the destination and relevant privacy classification.

No API keys are stored in source. Secrets use platform secure storage or the provider's secure credential mechanism.

## 10. Tool boundary

GGEN tools operate primarily on GGEN project content: canvas, layers, objects, documents, templates, assets, exports and workflows.

LAI tools operate on intelligence/runtime/device authority: inference, OCR runtime, application launching, accessibility actions, shell/elevated operations and agent orchestration.

Cross-boundary operations require explicit capability contracts and policy checks.

## 11. Failure semantics

The integration must fail closed and preserve manual operation.

If LAI is unavailable:

- GGEN remains fully usable manually.
- GGEN may route to another configured provider if policy permits.
- No silent data transfer occurs.
- Provider failure is surfaced as structured, actionable error information.

## 12. Versioning

The contract is versioned independently from either application. Backward compatibility must be explicit. Unsupported capabilities must be reported rather than emulated deceptively.

## 13. Decision record

This document supersedes the earlier idea that GGEN should embed its own local LLM runtime. Local inference remains an important product capability, but its preferred implementation boundary is LAI or another provider implementing the same contract.

## 14. Implementation order

1. Freeze this boundary in documentation.
2. Inventory existing GGEN and LAI tools/capabilities.
3. Assign canonical ownership.
4. Define the provider/capability schema.
5. Implement a minimal mock provider and contract tests.
6. Implement the LAI provider adapter.
7. Add cloud/custom adapters without changing GGEN core.
8. Validate privacy, failure, streaming and evidence semantics on device.

No large integration implementation should begin before steps 1–4 are documented and reviewed.
