# GGEN ↔ LAI Research & Quality References

**Date:** 2026-08-24

## Purpose

This is a research index, not an implementation dependency list. References establish quality and protocol expectations. GGEN and LAI must retain independent architecture and identity.

## Creative/document quality references

- Vector: Adobe Illustrator / Infinite Design class
- Raster/photo: Photoshop / PicsArt class
- Painting: Infinite Painter class
- 3D DCC: Blender class
- Font engineering: FontForge/pro font-editor class
- Documents/PDF: professional page-layout/PDF editor class

GGEN already records these as capability benchmarks rather than implementation claims. fileciteturn78file0

## AI provider/tool protocol references

- OpenAI platform documentation: https://platform.openai.com/docs
- Anthropic tool-use documentation: https://docs.anthropic.com/en/docs/build-with-claude/tool-use
- Google Gemini function calling: https://ai.google.dev/gemini-api/docs/function-calling
- Model Context Protocol specification: https://modelcontextprotocol.io/specification

## Architectural lessons

1. Provider APIs expose different object/event models; normalize them behind adapters.
2. Tool schemas should be explicit and machine-readable.
3. Model-generated tool calls are requests, not authorization.
4. Host-side policy must validate and execute tools.
5. Streaming must be represented as normalized events.
6. Cancellation and timeout must have explicit semantics.
7. Capability discovery should precede execution.
8. Unsupported capabilities must fail explicitly.
9. Provider-specific objects must not leak into GGEN's core domain.
10. MCP is useful as an interoperability adapter but is not mandatory as the GGEN↔LAI core protocol.

## Repository-grounded references

GGEN already defines provider/router descriptors, deterministic routing inputs, and a staged compute-evidence chain in `docs/interfaces/ai-provider-router.md`. fileciteturn77file0

LAI's current architecture separates core contracts, Android platform authority, runtime adapters, orchestration and plugins; its current AI architecture explicitly distinguishes the implemented `InferenceEngine` from the future `AiGateway`. fileciteturn60file0 fileciteturn61file0

## Quality gate

No reference is permission to copy UI, branding, proprietary code, assets or undocumented behavior. A reference becomes an accepted GGEN quality target only after its required semantics are documented, scoped, tested and evidenced.
