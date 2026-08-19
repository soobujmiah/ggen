# AI provider, router, and compute evidence

## Provider descriptor

- stable provider ID/version/type;
- capabilities with modality, limits, model IDs, streaming/structured/tool support;
- locality (`ON_DEVICE`, `LAN`, `REMOTE`);
- privacy/cost/retention metadata;
- health/auth state without secret values.

## Router input

Task capability, content sensitivity, quality/latency/cost bounds, offline state, user policy, model/backend compatibility, memory/battery/thermal, and explicit consent status.

## Router output

Ordered candidate plan with reason codes. Selection is deterministic for the same snapshot/policy. No feature may bypass the router to call a provider.

## Compute evidence states

`API_AVAILABLE` → `DELEGATE_ACCEPTED` → `OPERATIONS_DELEGATED` → `EXECUTION_COMPLETED` → `BACKEND_VERIFIED` → `PERFORMANCE_MEASURED`.

Evidence records backend/provider/model/artifact digest, device, operation, input shape/resolution, timestamps, actual phase durations, memory context, thermal/battery where available, fallback, and limitations. Missing values remain unknown—not zero.
