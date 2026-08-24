# GGEN ↔ LAI Integration Boundary

**Status:** Architecture decision baseline
**Date:** 2026-08-24

## Principle

GGEN and LAI remain separate repositories and products.

- **GGEN:** user-facing Creative & Document Studio.
- **LAI:** AI intelligence, inference, agent, automation and device-execution platform.

Neither repository becomes a submodule or hidden runtime dependency of the other.

## Contract

```text
                    GGEN
       Creative + Document Studio
                    |
          AI Capability Contract
                    |
        +-----------+-----------+
        |           |           |
       LAI       Cloud      Custom
        |          AI        endpoint
        |
 CPU / GPU / NPU
```

## GGEN owns

- Canvas and document UX.
- Creative tools.
- Artifact/document model.
- Editing semantics.
- Templates and workflow UX.
- Import/export orchestration.
- User-visible AI actions.
- AI provider abstraction.

## LAI owns

- Local inference.
- Model/runtime management.
- Provider routing.
- Agent execution.
- Tool execution policy.
- Device automation.
- Accessibility/Shizuku authority.
- RAG and memory infrastructure.
- Hardware-aware scheduling.
- Audit/security/recovery infrastructure.

## Capability examples

| GGEN request | LAI may implement | Other provider may implement |
|---|---:|---:|
| `text.generate` | yes | yes |
| `vision.analyze` | yes | yes |
| `ocr.extract` | yes | yes |
| `image.generate` | yes | yes |
| `image.edit` | yes | yes |
| `embedding.create` | yes | yes |
| `agent.run` | yes | yes |
| `tool.execute` | yes, policy-gated | yes, if contract permits |

GGEN must not know whether a request was served by llama.cpp, QNN, OpenAI, Gemini, Anthropic, another compatible endpoint, or a remote LAI instance.

## Failure rule

If LAI is unavailable, GGEN must remain functional. AI-dependent operations fail explicitly and safely; manual editing and document operations continue.

## Security rule

GGEN never receives LAI's privileged Android authority merely because it can request an AI capability. Device automation remains behind LAI's own consent, policy and audit boundary.

## Implementation rule

The first implementation milestone is the capability contract and provider lifecycle—not direct LAI embedding. Concrete transports (local IPC, HTTP, custom endpoint, etc.) are implementation details and must not leak into GGEN's core document model.
