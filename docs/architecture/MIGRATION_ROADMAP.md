# GGEN ↔ LAI Integration Roadmap

## Phase A — Documentation freeze

- [x] Define product boundary
- [x] Define capability ownership
- [x] Define provider architecture
- [x] Define tool inventory schema
- [x] Define ownership migration rules
- [x] Record architecture decisions

## Phase B — Contract design

- Define versioned capability envelope.
- Define capability discovery.
- Define normalized request/response schemas.
- Define streaming events.
- Define structured errors.
- Define privacy and consent metadata.
- Define execution-evidence schema.
- Define cancellation and timeout semantics.

## Phase C — Test-only integration

- Implement a mock provider in GGEN.
- Implement contract fixtures independent of network/model execution.
- Test unsupported capabilities, timeouts, cancellation, malformed responses and provider failure.
- Verify manual GGEN workflows remain unaffected.

## Phase D — LAI adapter

- Expose a minimal LAI capability endpoint/service.
- Start with text generation and OCR.
- Add health/capability discovery.
- Add streaming and cancellation.
- Return honest runtime/evidence metadata.
- Validate on Redmi Turbo 4 Pro.

## Phase E — Creative AI capabilities

Add image generation/editing, embeddings, vision and structured generation only after the base contract is stable.

## Phase F — Agents and automation

Expose `agent.run` and `tool.execute` only through explicit consent, risk metadata and LAI policy gates. GGEN must not gain arbitrary device authority by merely installing a provider.

## Phase G — Provider ecosystem

Add OpenAI, Gemini, Anthropic, OpenAI-compatible and Custom REST adapters. Each adapter receives contract tests and privacy/error verification.

## Phase H — Optimization

Measure latency, throughput, memory and thermal behavior. Optimize only after evidence exists. Provider selection may then use measured capability profiles.

## Migration rules

- No repository merge.
- No direct source dependency from GGEN to LAI internals.
- No model files in GGEN solely for provider support.
- No API secrets in project files.
- No removal of a current implementation until an equivalent contract path is tested.
- Every migration has a rollback path.
