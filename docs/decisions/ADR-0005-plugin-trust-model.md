# ADR-0005 — Plugin trust model

**Status:** Draft for owner review, 2026-08-20

## Context

GGEN will eventually support plugins (tools, panels, import/export
adapters, AI providers, templates, workflow nodes — `MASTER_SPEC.md` §17).
Plugins are third-party or user-supplied code that runs inside the app, so
a trust model must be decided before any plugin runtime is implemented.
No plugin runtime exists yet; this ADR records the model that a future
implementation must satisfy.

## Decision

Plugins are **capability-scoped, versioned, validated, and sandboxed where
the platform permits**:

1. **Capability scoping.** Every plugin declares an explicit capability set
   (e.g. `io:read:projects`, `io:write:exports`, `network:providers`,
   `ui:panel`, `data:no-access`). The app grants exactly the declared
   capabilities; anything undeclared is denied. Capabilities are enforced
   by the host (the app mediates all file, network, and storage access),
   not assumed from plugin intent.
2. **Versioning and validation.** Plugins carry a version, a content hash,
   and a manifest. The manifest is validated before load: bounded size,
   canonical fields, capability whitelist, no path traversal, no
   restricted/protected-asset references. Updates are immutable per
   version; rollback is supported.
3. **Trust tiers.** Plugins are classified on install/update:
   - **Trusted** (owner-signed or app-store distributed): full declared
     capabilities.
   - **Verified** (hash-pinned, capability-scoped, no sensitive caps):
     granted declared capabilities.
   - **Sandboxed** (everything else): run in a restricted environment;
     network, broad IO and provider credentials denied by default.
4. **Sandboxing.** Where the platform permits (Android's WebView/JS
   isolation for scripting, native process isolation for heavy work),
   plugins run isolated from the core process and from each other.
   Sandbox escape is treated as a high-severity security event.
5. **No silent execution.** Natural-language or workflow features that
   invoke plugin actions must present a reviewable step before executing
   risky operations (`MASTER_SPEC.md` §15).
6. **Protected assets.** Plugins can never modify, read the bytes of, or
   download protected assets; the registry boundary
   (`config/protected-asset-registry.json`) applies to plugins exactly as
   to the core.

## Consequences

- A plugin host/loader must implement manifest validation, capability
  enforcement and the tier classification before any third-party plugin
  can run.
- The threat model (`docs/security/threat-model.md` T6) tracks plugin
  abuse; T6 is closed only when the loader exists with tests.
- Plugins are out of scope for the current Phase 1/2 work; this ADR is the
  contract a future implementation must satisfy.
- The public repository continues to contain no plugin binaries; plugins
  arrive through an owner-approved distribution channel with provenance.
