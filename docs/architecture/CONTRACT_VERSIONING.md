# GGEN ↔ LAI Capability Contract Versioning

**Status:** Documentation/specification
**Current contract:** v0.1
**Date:** 2026-08-24

## Version format

The capability contract uses semantic major/minor versions:

- **MAJOR** — incompatible envelope, capability semantics, security/privacy behavior, or error/event contract change.
- **MINOR** — backward-compatible capability addition, optional field, or new provider capability.
- Patch-level documentation corrections do not change the protocol version but MUST be recorded in changelog/commit history.

## Compatibility rules

A v0.1 consumer MUST reject a request/response as incompatible when a required semantic field is removed or its meaning changes.

Optional fields may be added without breaking an older consumer, provided their absence preserves the previous behavior.

New capability IDs are additive. A provider that does not implement a capability MUST return `UNSUPPORTED_CAPABILITY`; it must not silently substitute another capability.

## Provider negotiation

A provider advertises:

```text
protocol_versions
capabilities
streaming_modes
privacy_classes
limits
provider_version
```

The consumer selects a mutually supported contract version. Provider version numbers never replace protocol versioning.

## Fixture rule

Every contract version has its own fixture namespace:

```text
fixtures/v0.1/<capability>/<case>
```

A fixture may not silently change meaning. Breaking changes require a new fixture namespace and contract version.

## Deprecation

A capability or field may be deprecated only after:

1. replacement semantics are documented;
2. migration guidance exists;
3. fixture coverage exists for old and new behavior;
4. both repositories record the deprecation;
5. a removal version/date is explicitly chosen.

## Source-of-truth rule

The cross-repository contract documentation is authoritative for interoperability. Individual implementation code may add provider-specific behavior, but it cannot redefine shared semantics without a contract change.
