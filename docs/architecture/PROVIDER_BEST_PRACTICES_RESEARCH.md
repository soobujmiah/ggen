# Provider & Tool Architecture Research

**Date:** 2026-08-24
**Purpose:** Quality reference for GGEN↔LAI contracts; no implementation is copied from external projects.

## External reference findings

### OpenAI

The current OpenAI API model is capability/tool oriented: responses can expose structured outputs, tool calls and streaming events. Architectural lesson: keep provider-specific event formats behind an adapter and normalize tool/event semantics in the product contract.

Reference: https://platform.openai.com/docs

### Anthropic

Anthropic's tool-use model separates tool definitions, model-issued tool calls and application-side tool results. Architectural lesson: a model response must not itself confer authority; the host application validates the call and executes it according to policy.

Reference: https://docs.anthropic.com/en/docs/build-with-claude/tool-use

### Google Gemini

Gemini function calling similarly represents callable functions through declared schemas and model-generated function calls. Architectural lesson: capability schemas belong to the host/provider contract, while execution remains outside the model.

Reference: https://ai.google.dev/gemini-api/docs/function-calling

### Model Context Protocol

MCP provides a general protocol vocabulary for servers exposing tools/resources/prompts. Architectural lesson: capability discovery and typed schemas are valuable, but GGEN should not make MCP mandatory; MCP can be an adapter/plugin transport when useful.

Reference: https://modelcontextprotocol.io/specification

## Quality requirements derived for GGEN/LAI

1. **Capability-first:** route by stable capability IDs, not vendor SDK types.
2. **Typed schemas:** every callable capability declares machine-readable input/output constraints.
3. **Authority separation:** model output is untrusted data; execution requires host-side policy.
4. **Normalized events:** streaming/tool events are translated into provider-neutral events.
5. **Discovery:** providers advertise capabilities, limits and readiness before execution.
6. **Explicit errors:** unsupported, policy, authentication, rate-limit, timeout, transport and execution failures remain distinguishable.
7. **Cancellation:** cancellation is an explicit protocol operation; timeout does not falsely imply remote cancellation.
8. **Evidence:** runtime/backend/device claims are separately represented and never inferred from provider names.
9. **Privacy routing:** local-only content cannot silently reach a cloud provider.
10. **Versioning:** protocol and operation/capability versions evolve independently.
11. **Secrets:** credentials stay outside project files, logs and diagnostic exports.
12. **Contract tests:** every provider must pass the same behavioral fixtures.

## What GGEN should NOT copy

- vendor-specific request/response objects into the GGEN core
- provider-specific tool execution semantics
- vendor UI or interaction patterns
- assumptions that every provider supports identical modalities, context sizes or streaming behavior
- assumptions that an API's tool call is already authorized

## Position on MCP

MCP is a useful interoperability adapter, not the GGEN↔LAI core contract. The core contract should remain small, versioned and product-controlled. An MCP adapter may translate GGEN capabilities to/from MCP where a plugin or external tool ecosystem benefits from it.

## Position on provider breadth

GGEN's provider architecture should support OpenAI, Gemini, Anthropic, OpenAI-compatible and Custom REST providers, while LAI remains the preferred local runtime provider. Provider breadth must not expand the core domain model.
