# GGEN ↔ LAI Contract Fixtures and Mock Provider

**Status:** Documentation/specification
**Contract:** v0.1
**Date:** 2026-08-24

## Purpose

This document defines the conformance fixtures and mock-provider behavior required before the first production GGEN↔LAI integration. It is intentionally implementation-neutral. The fixture suite is the executable-contract target for future agents; it does not introduce a runtime dependency between the repositories.

## 1. Fixture principles

Every fixture MUST be:

- deterministic;
- versioned with the capability contract;
- independent of a real model or accelerator;
- validatable without network access;
- explicit about privacy, streaming, cancellation and evidence;
- safe to replay in tests;
- free of credentials and personal content.

A fixture MUST NOT imply that a mock execution occurred on CPU/GPU/NPU. Mock evidence is explicitly marked `SIMULATED`.

## 2. Canonical envelope

Requests use this conceptual envelope:

```text
protocol_version
request_id
capability
provider_id
provider_version
input
options
privacy_class
streaming
limits
metadata
```

Responses use:

```text
protocol_version
request_id
capability
provider_id
status
output
usage
execution_evidence
error
metadata
```

Provider-specific fields remain behind the adapter boundary.

## 3. v0.1 capability fixtures

### `text.generate`

Minimum cases:

1. deterministic successful generation;
2. structured/JSON-constrained generation;
3. streaming token sequence;
4. non-streaming result;
5. timeout;
6. cancellation;
7. provider unavailable;
8. unsupported capability;
9. privacy rejection for `LOCAL_ONLY` against a cloud-only mock;
10. malformed request.

### `ocr.extract`

Minimum cases:

1. deterministic text extraction from a fixture image descriptor;
2. empty/no-text result;
3. confidence metadata;
4. unsupported modality;
5. timeout/cancellation;
6. model unavailable.

The OCR fixture must validate the contract, not OCR model quality. Real OCR accuracy is a separate LAI/device qualification gate.

## 4. Evidence fixture

Execution evidence MUST use distinct states rather than a single `accelerated=true` flag:

```text
api_available
backend_available
backend_accepted
delegated
completed
device_validated
performance_measured
source
confidence
```

For the mock provider:

```text
source = "mock"
confidence = "SIMULATED"
```

The mock MUST never report `device_validated=true` or `performance_measured=true`.

## 5. Error taxonomy

The mock provider MUST be able to deterministically emit:

- `UNAVAILABLE_PROVIDER`
- `UNSUPPORTED_CAPABILITY`
- `POLICY_DENIED`
- `INVALID_REQUEST`
- `AUTHENTICATION_FAILED`
- `RATE_LIMITED`
- `TIMEOUT`
- `TRANSPORT_FAILURE`
- `MODEL_FAILURE`
- `EXECUTION_EVIDENCE_FAILURE`
- `CANCELLED`

GGEN tests should assert stable error categories, not provider-specific messages.

## 6. Streaming contract

Streaming events are normalized:

```text
STARTED
DELTA
PROGRESS
COMPLETED
FAILED
CANCELLED
```

A provider may use any wire-level streaming mechanism. GGEN consumes only the normalized event vocabulary.

Required invariants:

- one request has one terminal event;
- terminal events are mutually exclusive;
- cancellation is terminal;
- sequence numbers are monotonic when supplied;
- duplicate terminal events are rejected;
- a late event after cancellation is ignored/rejected according to the adapter policy.

## 7. Privacy fixtures

At minimum test:

| Request policy | Mock provider | Expected |
|---|---|---|
| `LOCAL_ONLY` | local | allow |
| `LOCAL_ONLY` | cloud | reject |
| `CLOUD_ALLOWED` | local | allow |
| `CLOUD_ALLOWED` | cloud | allow |
| `ASK_FIRST` | any | require explicit policy decision |
| `SENSITIVE_LOCAL_ONLY` | cloud | reject |

Privacy enforcement belongs at the routing/policy boundary; the model output cannot override it.

## 8. Cancellation and timeout

The contract MUST distinguish:

- caller cancellation;
- provider timeout;
- transport timeout;
- model execution failure.

A cancelled request MUST NOT later become a successful request merely because a late provider response arrives.

## 9. Mock provider behavior

The mock provider is a test double, not a fallback production AI provider.

It should expose configurable scenarios:

```text
success
stream
slow
cancel
unsupported
policy-denied
unavailable
malformed
error
```

It MUST be deterministic for a given fixture ID and request.

It MUST NOT contact the network, access device files, execute tools, or claim real model execution.

## 10. Contract conformance matrix

| Rule | Fixture required | Owner of enforcement |
|---|---|---|
| capability ID is stable | yes | GGEN adapter/contract tests |
| provider neutrality | yes | GGEN core boundary |
| typed input/output | yes | both adapters |
| normalized errors | yes | provider adapter |
| normalized streaming | yes | provider adapter |
| privacy policy | yes | router/policy layer |
| cancellation | yes | transport/provider layer |
| timeout | yes | transport/provider layer |
| evidence distinction | yes | provider + renderer |
| secrets excluded | yes | configuration/storage layer |
| manual mode unaffected | yes | GGEN application |
| no cross-repo source import | static check | both repositories |

## 11. First production gate

Do not implement `agent.run` or `tool.execute` as the first integration.

The first production path should be:

```text
GGEN
  -> provider abstraction
  -> capability request: text.generate
  -> LAI adapter
  -> transport
  -> LAI capability endpoint
  -> local inference/runtime
  -> normalized response + evidence
  -> GGEN
```

The integration is accepted only when the same GGEN contract tests pass against both the mock provider and the real LAI adapter.

## 12. Promotion rule

A capability may move from `planned` to `integrated` only when:

1. contract fixture exists;
2. mock provider passes;
3. provider adapter passes;
4. privacy tests pass;
5. timeout/cancellation tests pass;
6. error normalization passes;
7. evidence semantics pass;
8. manual GGEN operation remains functional;
9. documentation and ownership inventory are updated;
10. CI and device validation requirements for that capability are recorded.

This document is the specification for that gate. It is not itself evidence that a real LAI integration exists.
