# AI Gateway Runtime — Agent Implementation Handoff

## Objective

Implement the AI Gateway Runtime described in `docs/architecture/ai-gateway-runtime.md`.

The product goal is a cloud-first, provider-agnostic AI runtime for Android where an application can use OpenAI, Anthropic, Gemini, OpenAI-compatible APIs, and future custom endpoints through one normalized interface. If one eligible provider fails, the runtime must automatically retry/fail over according to bounded policy. AI models may request registered Android tools, but tools execute only through the runtime's schema, policy, permission, and Android adapter boundaries.

## Important repository boundary

This is a separate architecture track from GGEN's existing Phase 2 creative-surface implementation. Do not rewrite or destabilize the existing GGEN editor/canvas architecture to implement this runtime. Before adding implementation packages, inspect the repository's current module/build structure and choose the smallest isolated location consistent with existing conventions. If the current repository structure cannot safely host the runtime without architectural coupling, document the proposed boundary before implementing it.

## Required reading

1. `AI_ASSISTANT.md`
2. `CURRENT_STATE.md`
3. `MASTER_SPEC.md`
4. `docs/architecture/ai-gateway-runtime.md`
5. Relevant current architecture/ADR documents

## Frozen invariants

- Core must remain provider-neutral.
- Provider-specific API types belong only in adapters.
- Requests and responses use normalized core contracts.
- Retry is bounded; infinite retry is forbidden.
- Invalid requests are not blindly replayed across providers.
- Provider failover is policy-driven and capability-aware.
- Health state and circuit breaking must prevent repeated traffic to failed providers.
- AI cannot grant itself Android permissions.
- Tool calls require registry lookup, schema validation, policy/permission evaluation, and confirmation where required.
- High-risk tools are disabled by default during MVP.
- Tool output is untrusted data.
- Tool execution retry is separate from AI generation retry.
- Secrets never enter model context, source control, or ordinary logs.
- Public release is forbidden until release gates are explicitly passed.

## Execution order

### M1 — Foundation

Implement only the minimum domain contracts and test infrastructure:

- AIRequest
- AIResponse
- Provider
- ProviderCapabilities
- ProviderHealth
- ProviderError
- RoutingPolicy
- Tool
- ToolResult
- package/module boundaries
- unit-test scaffolding

Do not implement Android automation or a large UI in M1.

### M1 acceptance

All of the following must pass:

- project builds;
- core contracts compile;
- provider abstraction exists;
- normalized request/response exist;
- capability model exists;
- router policy contract exists;
- tool contract exists;
- security boundary is represented;
- unit tests execute;
- architecture documentation remains consistent.

### M2 — Provider Layer

After M1 is green:

- implement provider adapter boundary;
- implement normalized translation;
- implement one real cloud provider adapter;
- implement mock provider;
- normalize provider errors;
- add capability checks;
- add provider adapter tests.

### M3 — Router / Failover

Only after M2 is green:

- provider selection;
- health monitor;
- bounded retry;
- failover;
- circuit breaker;
- request/attempt tracing;
- failure simulation.

### M4 — Tool Runtime

Only after M3 is green:

- registry;
- schema validation;
- risk levels;
- permission policy;
- user confirmation;
- executor boundary;
- one low-risk Android read-only tool;
- tool timeout;
- normalized results;
- audit events.

### M5+ — Security and expansion

Follow the architecture document exactly for M5–M10. Do not skip security gates to reach feature parity.

## Git workflow — mandatory

For every completed milestone:

1. inspect `git status` and diff;
2. run relevant unit/integration tests;
3. run the repository's exact pinned build/CI-equivalent checks where available;
4. update implementation/status documentation;
5. commit the milestone;
6. push the commit to the designated GitHub branch;
7. verify the remote branch contains the commit;
8. record commit SHA and verification evidence in the handoff/status documentation.

Do not claim a milestone complete without a commit SHA and remote verification.

## Scope discipline

Do not add speculative providers, unnecessary dependencies, autonomous agent behavior, unrestricted shell execution, unrestricted filesystem access, privileged Android actions, or UI polish merely because they might be useful later.

When a requirement is ambiguous, prefer the smallest implementation that satisfies the frozen contract and document the decision.

## Milestone report format

```text
Milestone:
Status:

Implemented:
- ...

Tests:
- ...

Failure tests:
- ...

Security checks:
- ...

Build:
- ...

Files changed:
- ...

Known limitations:
- ...

Architecture deviations:
- NONE / DETAILS

Commit SHA:
Remote branch:
Push status:
Remote verification:

Next milestone:
```

## First action

Start with M1 only. Inspect the existing repository/module structure first, choose an isolated implementation boundary, implement the minimum contracts, run the full applicable M1 test/build gates, update documentation, commit, push, and verify the remote SHA. Stop after M1 and report evidence before beginning M2.
