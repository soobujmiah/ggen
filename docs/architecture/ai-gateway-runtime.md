# AI Gateway Runtime — Architecture & Engineering Specification

**Status:** Architecture contract frozen; implementation pending
**Target:** Android-first, platform-neutral runtime
**Mode:** Cloud-first; local/custom inference is an optional adapter
**Release:** Not authorized until all release gates pass

## 1. Purpose

AI Gateway Runtime is a provider-neutral AI execution layer. Applications and Android tools use one normalized AI interface instead of depending directly on a specific cloud AI vendor.

The gateway must support multiple providers, capability-aware routing, bounded retry, automatic failover, health tracking, structured tool calling, Android permission boundaries, secure secret handling, and auditable execution.

## 2. Architectural invariants

1. Core code is provider-neutral.
2. Provider-specific request/response translation belongs only in provider adapters.
3. Failover is policy-driven and bounded; there is no infinite retry.
4. Invalid requests are not blindly replayed against every provider.
5. AI generation retry and tool execution retry are separate concerns.
6. AI never receives Android permissions directly.
7. Tool calls pass registry, schema, policy, and permission checks before execution.
8. High-risk tools are disabled by default and may require explicit user confirmation.
9. Tool output is untrusted data and cannot grant authority or permissions.
10. Provider credentials never enter model context or ordinary logs.
11. Important execution decisions are auditable without indiscriminately logging sensitive content.
12. Local inference is optional and must not contaminate the cloud-provider abstraction.
13. New providers must be addable without rewriting the core gateway.
14. Public release is blocked until implementation, tests, security validation, documentation, and reproducible build evidence are complete.

## 3. High-level flow

```text
Application / Android Client
            |
            v
       Unified AI API
            |
            v
         Gateway
            |
    +-------+--------+
    |       |        |
 Router  Failover  Health
    |       |        |
    +-------+--------+
            |
      Provider Layer
            |
    +-------+--------+---------+
    |       |        |         |
  OpenAI Anthropic Gemini  Custom
            |
            v
       Normalized Response
```

Tool execution:

```text
AI Provider
    |
    v
Normalized Tool Call
    |
    v
Tool Runtime
    |
    v
Tool Registry
    |
    v
Schema Validation
    |
    v
Policy / Permission
    |
    v
Android Adapter
    |
    v
Tool Result
    |
    v
AI Provider
```

## 4. Core domain contracts

### AIRequest

The normalized request contains, as applicable:

- messages
- system instruction
- model policy
- tools
- attachments
- generation configuration
- timeout
- metadata

### AIResponse

The normalized response contains, as applicable:

- content
- tool calls
- finish reason
- usage
- provider ID
- model ID
- request ID

Provider SDK objects must not leak into application or core domain code.

## 5. Provider contract

Conceptual interface:

```text
Provider
 ├── metadata()
 ├── capabilities()
 ├── healthCheck()
 ├── generate(AIRequest)
 └── stream(AIRequest)
```

Adapters are responsible for translating normalized requests and responses and normalizing provider failures. An adapter must not select another provider, bypass gateway policy, execute Android tools, or perform unbounded retries.

Supported provider categories include OpenAI, Anthropic, Gemini, OpenAI-compatible APIs, custom cloud endpoints, and future providers. Local inference may be implemented as another adapter later.

## 6. Capabilities

Provider/model metadata may declare:

- text
- vision
- tools
- streaming
- structured output
- maximum context size

The router must filter providers by required capabilities before execution.

## 7. Error model

Provider failures are normalized into categories such as:

- AUTHENTICATION
- RATE_LIMIT
- TIMEOUT
- UNAVAILABLE
- INVALID_REQUEST
- CAPABILITY_UNSUPPORTED
- SERVER_ERROR
- MALFORMED_RESPONSE
- NETWORK_ERROR
- UNKNOWN

The error class determines whether retry or failover is appropriate.

## 8. Routing

Initial deterministic ranking:

1. explicit user preference;
2. required capabilities;
3. enabled state;
4. health state;
5. configured priority.

Future ranking may add latency, cost, reliability, context capacity, model quality, and user policy.

## 9. Retry and failover

Retry is bounded and applies only to retryable failures. Provider `Retry-After` information must be respected when available.

Typical retryable conditions include transient timeout, transient network failure, temporary server failure, and rate limiting subject to provider policy. Invalid requests, invalid credentials, unsupported capabilities, and invalid configuration must not trigger blind repeated retries.

A typical failover path is:

```text
Provider A -> retryable failure -> bounded retry -> Provider B -> success
```

All providers failing must produce one normalized terminal failure; the system must never enter an infinite loop.

## 10. Health and circuit breaker

Provider runtime states:

- HEALTHY
- DEGRADED
- RATE_LIMITED
- UNAVAILABLE
- DISABLED

A circuit breaker may transition:

```text
HEALTHY -> DEGRADED -> OPEN -> HALF_OPEN -> HEALTHY
                                   \\-> OPEN
```

The purpose is to stop repeatedly sending traffic to a failing provider and to permit controlled recovery probes.

## 11. Request tracing

Every request receives an internal request ID. Attempts may record provider, model, timing, outcome, error class, and failover reason. Raw credentials and unnecessary sensitive prompt content must not be logged.

## 12. Tool Runtime

A tool has a stable ID and version and declares:

- name
- description
- input schema
- output schema
- risk level
- required permissions
- executor

Tool execution sequence:

```text
Tool Call -> known tool -> schema valid -> policy allowed -> confirmation if required -> execute -> normalized result
```

Unknown tools, malformed arguments, denied permissions, and expired confirmations must fail closed.

## 13. Tool risk levels

**LOW:** read-only or low-impact operations.

**MEDIUM:** bounded local state changes.

**HIGH:** external, destructive, privileged, or sensitive actions.

High-risk tools are disabled by default during MVP. Any future high-risk capability requires explicit policy, appropriate Android permissions, user confirmation where applicable, validation, and dedicated tests.

## 14. Android boundary

The core runtime remains platform-neutral. Android-specific execution belongs behind an adapter boundary:

```text
Core Tool Runtime
      |
      v
Tool Executor Interface
      |
      v
Android Adapter
   |    |    |
 Android Intent Accessibility other APIs
```

The first integration should use one low-risk, read-only capability such as `get_device_info()` so the complete tool chain can be validated without destructive side effects.

## 15. Tool-result security

Tool output is data, not authority. Text returned by a tool must not be interpreted as permission, policy, or system instruction. Prompt-injection-like output must remain untrusted.

## 16. Tool retries and idempotency

AI generation retry must not automatically imply tool retry. Side-effecting tools are not automatically retried because a timeout may occur after the external action succeeded. Where a side-effecting tool eventually permits retries, it must use an appropriate idempotency mechanism.

## 17. Secret management

Provider credentials must be kept in a secure secret facility appropriate to the platform. They must never be:

- hard-coded in source;
- committed to Git;
- inserted into prompts or model context;
- returned by tools;
- written to ordinary logs;
- included in diagnostics or documentation.

Credential attachment occurs inside the provider adapter after the normalized request has reached the gateway.

## 18. Audit

Auditable events include request creation, provider selection, provider attempts, retries, failovers, tool-call requests, validation, permission decisions, tool execution, and request completion. Audit records must be privacy-aware and secret-safe.

## 19. Threat model

The initial threat model covers prompt injection, malicious tool output, unauthorized tool execution, credential leakage, replayed calls, duplicate side effects, malformed provider responses, malicious tool schemas, excessive permissions, infinite retries, denial-of-service through repeated tool calls, and unsafe Android privileged operations.

## 20. Milestones

### M1 — Foundation
Project structure, core domain contracts, interfaces, tests, and documentation.

### M2 — Provider Layer
Provider contract, normalized request/response, capability model, error model, first real adapter, and mock provider.

### M3 — Routing and Failover
Router, health monitor, bounded retry, failover, circuit breaker, tracing, and failure simulation.

### M4 — Tool Runtime
Tool registry, schema validation, risk classification, permission engine, confirmation, executor, Android adapter boundary, and one safe Android tool.

### M5 — Security
Secret management, redaction, permission hardening, threat-model tests, and security regression checks.

### M6 — Multi-provider
Second real provider, interoperability tests, provider-specific edge cases, and streaming.

### M7 — Advanced routing
Capability-, latency-, cost-, and reliability-aware routing where evidence justifies it.

### M8 — Android tool expansion
Additional safe tools and controlled automation only after security gates pass.

### M9 — Agent runtime
Multi-step tasks, task state, cancellation, workflow orchestration, and long-running operations.

### M10 — Release candidate
Full integration, security, failure, performance, documentation, and reproducible-build validation.

## 21. Testing requirements

Provider tests must cover success, timeout, rate limit, authentication failure, server failure, network failure, malformed response, and unsupported capability.

Router tests must cover preference, unavailable providers, failover, all-provider failure, bounded retry, circuit opening, cooldown, and recovery.

Tool tests must cover registration, duplicate IDs, unknown tools, schema failure, permission denial, confirmation, timeout, execution failure, and result normalization.

Security tests must cover secret redaction, prompt injection, malicious tool output, unauthorized tool calls, high-risk tool blocking, and duplicate side-effect protection.

## 22. Definition of Done

A milestone is complete only when all applicable items are satisfied:

- implementation complete;
- unit tests complete;
- failure tests complete;
- integration tests complete;
- security validation complete where applicable;
- documentation updated;
- build succeeds;
- evidence is recorded;
- commit created;
- commit pushed to the designated GitHub branch;
- remote state verified.

## 23. Release policy

No public release is authorized merely because a demo works. Release requires architecture compliance, provider interoperability, failover validation, tool security validation, credential security, Android permission validation, failure testing, performance evidence, documentation review, and reproducible release-build evidence.

## 24. Non-goals for the initial implementation

The MVP does not attempt unrestricted shell execution, unrestricted filesystem access, silent Android control, immediate full autonomous-agent behavior, provider lock-in, or premature local-LLM integration.

## 25. Agent execution contract

The coding agent must implement milestones in order and must not silently change architectural invariants. It must finish and verify one milestone before starting the next.

At each milestone close, the agent must report:

```text
Milestone
Status
Implemented
Tests
Failure tests
Security checks
Build
Files changed
Known limitations
Architecture deviations
Commit SHA
Branch
Push status
Remote verification
Next milestone
```

GitHub push is mandatory after a completed milestone unless the repository protection policy blocks it. If blocked, the agent must report the exact blocking condition rather than claiming completion.

## 26. Current status

Architecture and engineering contract: **documented**.

Actual implementation of this runtime: **not yet claimed by this document**.

Public release: **not authorized**.
