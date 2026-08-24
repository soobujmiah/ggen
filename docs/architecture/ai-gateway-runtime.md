# AI Gateway Runtime — Integration Reference

**Status:** GGEN integration/reference document; canonical runtime ownership = LAI
**Target:** Android-first, platform-neutral capability contract
**Release:** This document does not authorize a GGEN runtime implementation or public release

## 1. Purpose

This document describes the AI gateway behavior GGEN expects to consume through the cross-repository capability contract. It is an integration/reference specification, not permission to create a second canonical AI runtime inside GGEN.

**Canonical ownership:** LAI owns provider adapters, provider routing/failover, provider credentials, model execution, local CPU/GPU/NPU runtime, device scheduling, Android tool authority, agent execution, runtime audit and execution evidence. GGEN owns user-facing creative/document UX, document/creative state, task intent, context assembly, presentation of AI results and non-AI workflows.

The canonical cross-repository contract is `docs/architecture/GGEN_LAI_INTEGRATION_SPEC.md` in GGEN and the matching LAI integration-boundary documentation. The SKB ownership matrix is the cross-project reference.

## 2. Architectural invariants

1. GGEN code remains provider-neutral.
2. Provider-specific translation and credentials belong to LAI.
3. GGEN does not implement a second retry/failover router.
4. GGEN does not own Android permissions or privileged tool execution.
5. AI tool calls requested by GGEN pass through LAI registry, schema, policy and permission boundaries.
6. GGEN receives normalized responses/errors and presents them to users.
7. GGEN remains functional without LAI for manual/non-AI workflows.
8. Local/cloud/hybrid execution is requested through capability constraints; LAI resolves the execution path.
9. No hidden shared filesystem paths or runtime internals cross the repository boundary.
10. Release claims must distinguish contract/documentation from validated implementation.

## 3. Expected flow

```text
GGEN creative/document UX
          |
          | versioned capability request
          v
     LAI Runtime
          |
    +-----+----------+
    |                |
 Local runtime   Cloud/custom providers
 CPU/GPU/NPU
          |
          v
 normalized response + provenance/evidence
          |
          v
         GGEN
```

Tool execution is LAI-owned:

```text
GGEN capability intent
        |
        v
LAI tool registry
        |
 schema / policy / permission / confirmation
        |
        v
Android/tool executor
        |
        v
normalized result
```

## 4. Normalized request/response expectations

GGEN may send a logical request containing:

- request ID
- capability
- operation
- document/media references
- context
- execution/privacy constraints
- streaming/cancellation preference
- metadata safe for the runtime boundary

GGEN must not send provider SDK objects, provider secrets, arbitrary Android framework objects, or implicit filesystem paths.

The normalized response may contain:

- request ID
- status
- output
- runtime/provider identity
- usage where available
- provenance/evidence
- warnings
- typed error

Stable statuses include `success`, `partial`, `failed`, `cancelled`, `unsupported`, `denied`, and `timeout`.

## 5. Provider behavior — LAI-owned

LAI's provider layer may expose normalized capabilities such as text, vision, tools, streaming and structured output. Provider adapters translate requests/responses and normalize failures.

GGEN must not implement provider-specific selection, credential attachment, retries or failover. GGEN may expose user-facing provider preferences and constraints; those become runtime policy inputs to LAI.

Provider/runtime failures should be returned as typed normalized errors. GGEN owns the user-facing recovery UX; LAI owns retry/failover and runtime recovery policy.

## 6. Routing, retry and health — LAI-owned

Capability filtering, provider health, bounded retry, failover and circuit breaking belong to LAI. GGEN must not independently reproduce these policies.

A typical runtime path is:

```text
preferred execution -> retryable failure -> bounded retry -> allowed fallback -> normalized terminal result
```

`local_only` must never silently leave the device. Non-idempotent side effects must not be blindly retried or failed over.

## 7. Tool runtime — LAI-owned

A tool has a stable ID/version, description, schemas, risk classification, required permissions and executor. Unknown tools, invalid arguments, denied permissions and expired confirmations fail closed.

Tool output is untrusted data and never grants authority.

GGEN may request a declared tool capability through the integration contract. It does not execute Accessibility, Shizuku or privileged Android operations itself through this gateway document.

## 8. Security and secrets — LAI-owned

Provider credentials belong in LAI's secure runtime secret facility. They must never be stored in GGEN project documents, source, ordinary logs or model context.

GGEN should receive only the minimum execution metadata needed for UX and provenance.

## 9. Evidence

Runtime evidence must distinguish availability from execution, for example:

`API_AVAILABLE → BACKEND_AVAILABLE → BACKEND_ACCEPTED → EXECUTION_COMPLETED → DEVICE_VALIDATED → PERFORMANCE_MEASURED`

GGEN must not upgrade LAI evidence. If LAI reports a backend as experimental or unvalidated, GGEN must preserve that status.

## 10. Implementation relationship

The previous GGEN-local milestone sequence (M1 gateway foundation, provider layer, router/failover, tool runtime, etc.) is **superseded as a GGEN runtime implementation plan**.

The correct implementation sequence is:

1. reconcile/freeze the cross-repository contract;
2. implement canonical runtime capabilities in LAI;
3. implement the smallest GGEN client/adapter required to consume them;
4. validate end-to-end;
5. expand capabilities only after evidence and security gates pass.

No GGEN-local provider/runtime implementation should be started from this document.

## 11. Current status

- GGEN gateway runtime: **NOT IMPLEMENTED / NOT A GGEN OWNERSHIP TARGET**
- Cross-repository contract: **DOCUMENTED**
- LAI canonical runtime: follow LAI repository implementation state and evidence
- Public release: **NOT AUTHORIZED until applicable release gates pass**

## 12. Required agent reading

Before changing AI integration code, an agent must read:

1. `docs/architecture/ggen-lai-boundary.md`
2. `docs/architecture/GGEN_LAI_INTEGRATION_SPEC.md`
3. this document
4. the corresponding LAI integration boundary/runtime documents
5. SKB `architecture/GGEN_LAI_CAPABILITY_OWNERSHIP_MATRIX.md`
6. SKB `research/ANDROID_BEST_IN_CLASS_RESEARCH_PROTOCOL.md`

If these sources disagree, inspect current source/tests/evidence in both repositories before implementing anything.