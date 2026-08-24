# GGEN AI Provider Architecture

## Objective

GGEN treats AI as a capability service. The application owns creative/document semantics; providers own model-specific execution.

## Provider interface

Conceptual interface:

```text
ProviderDescriptor
  id
  display_name
  version
  transport
  capabilities
  privacy
  limits

CapabilityDescriptor
  id
  input_schema
  output_schema
  streaming
  modalities
  max_context
  evidence_level

Provider.execute(capability, request) -> ProviderResponse
```

## Required provider classes

- `LaiProvider`
- `OpenAiProvider`
- `GeminiProvider`
- `AnthropicProvider`
- `OpenAiCompatibleProvider`
- `CustomRestProvider`
- `PluginProvider`

The concrete names are implementation details; the stable abstraction is the capability contract.

## Request lifecycle

```text
GGEN operation
  -> capability request
  -> policy check
  -> provider selection
  -> provider adapter
  -> transport
  -> execution
  -> evidence validation
  -> normalized result
  -> creative/document operation
```

## Routing policy

Selection considers:

- required capability
- input modality
- privacy policy
- user preference
- model availability
- quality requirement
- latency target
- cost limit
- device/runtime state
- provider health
- evidence requirements

Routing must not be hard-coded to a single vendor.

## Privacy classes

At minimum:

- `LOCAL_ONLY`
- `CLOUD_ALLOWED`
- `ASK_FIRST`
- `LOCAL_PREFERRED`
- `SENSITIVE_LOCAL_ONLY`

The router must reject providers that cannot satisfy the request's privacy policy.

## Streaming

Streaming is capability metadata, not assumed behavior. Providers advertise whether token/event streaming is supported. GGEN consumes normalized events and does not depend on provider-specific streaming formats.

## Errors

Normalize failures into stable categories such as:

- unavailable provider
- unsupported capability
- authentication failure
- policy denied
- invalid request
- rate limited
- timeout
- transport failure
- model failure
- execution/evidence failure
- cancelled

Provider-specific diagnostics may be attached as non-authoritative details.

## Credentials

API keys and secrets never enter project files, logs, diagnostics exports or source control. Provider configuration stores a secure credential reference rather than the secret itself.

## LAI-specific notes

LAI may expose local inference, OCR, embeddings, tools and agents through the same capability vocabulary. GGEN must not assume that a LAI response means GPU/NPU execution. LAI supplies execution evidence; GGEN only renders or records it.

## Compatibility rule

Adding a provider must not require changes to GGEN's core document/canvas model. Adding a new LAI backend must not require changes to the GGEN provider interface unless the capability contract itself evolves.
