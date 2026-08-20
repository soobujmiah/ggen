# GGEN threat model

**Status:** Draft for owner review, 2026-08-20
**Scope:** GGEN Android-first app; core, workspace shell, storage, and the
plugin system (see ADR-0005). Protected-asset and reference-repository
boundaries are documented in `MASTER_SPEC.md` §2/§6 and
`config/protected-asset-registry.json`.

## Assets

| # | Asset | Sensitivity |
|---|-------|-------------|
| A1 | Project documents (`.ggen` canonical JSON), artboards, nodes | User content |
| A2 | Recovery journal (project states, payloads) | User content (crash copies) |
| A3 | Workspace preferences and profiles | Low; user layout |
| A4 | Credentials/API keys for AI providers (future) | High; never on disk in plaintext |
| A5 | Protected assets (private vault) | High; immutable, never in public repo |
| A6 | Signed APK/release identity | High; controls trust of installs |
| A7 | User-provided diagnostics export | Low; must be redacted |

## Trust boundaries

1. **Imported content → app.** All imports (PDF, image, font, spreadsheet,
   model, archive, template, project) are untrusted until validated
   (`docs/security/import-and-resource-policy.md`).
2. **Plugin → app.** Plugins are capability-scoped, versioned, validated,
   sandboxed where the platform permits (ADR-0005).
3. **Network/provider → app.** Provider responses and endpoints are
   untrusted; never auto-execute, auto-download restricted bytes
   (`MASTER_SPEC.md` §6, §18).
4. **Storage → app.** `.ggen` and journal files may be corrupted or tampered
   with on-disk; the codec and journal parsing must fail closed.
5. **OS/platform → app.** Platform storage, SAF grants, keystore.

## Threats (STRIDE-lite, prioritized)

### T1 — Malicious or corrupted `.ggen` project file (high)
A project file is parsed by `ProjectCodec` with conservative limits
(max JSON bytes, artboards, nodes, depth, string length) and a fail-closed
schema policy. Journal lines are likewise bounded and digest-verified.
- **Mitigations:** bounded parse; schema policy rejects unknown versions;
  corrupt files reported, never silently accepted; journal payloads decoded
  only through the codec.
- **Residual:** a valid-format project with hostile content (deeply nested
  nodes) is bounded by node/depth limits; a future UDM must keep
  per-format element limits (import policy already requires them).

### T2 — Journal replay divergence (medium)
Replay could reconstruct a stale or divergent state if append/payload
ordering is wrong, or if bounds eviction drops a checkpoint the replay
depends on.
- **Mitigations:** append-then-payload ordering chained in the controller;
  `flushJournal()` quiescence for tests; replay is idempotent by revision;
  replay markers are session-scoped (no backward moves).
- **Residual:** crash during journal rewrite (tmp+rename) could lose the
  tail; acceptable for autosave semantics, documented in ADR-0004.

### T3 — Credential leakage (high, future)
AI-provider API keys must never enter the project JSON, journals, logs, or
diagnostics export. `DebugLogStore` redacts `authorization|api[_-]?key|
token|password|secret` keys and message patterns; diagnostics export is
bounded (500 entries) and redacted.
- **Mitigations:** redaction in debug log; secrets policy in
  `docs/security/privacy-credentials.md`; never commit keys; platform
  secure storage for future provider keys.
- **Residual:** redaction is regex-based; new secret-shaped fields require
  review. Add fuzz tests for redaction coverage.

### T4 — Protected-asset boundary violation (high)
The public repo must never contain protected bytes. `public_safety_scan.py`
scans reachable history for restricted paths/binaries/secret patterns;
`verify_protected_pack.py` enforces exact registry size/SHA-256 and no
writes; governance runs in CI.
- **Residual:** relies on CI; a compromised runner could bypass. Add a
  release-time scan artifact to the release pipeline.

### T5 — Symlink/traversal via storage keys (medium)
Storage keys are validated stable identifiers (`[a-z][a-z0-9_.-]{0,127}`)
before use as file names, so they cannot traverse the projects/journal
directories.
- **Residual:** `_fileFor` builds paths from validated keys only; the
  documents directory itself is platform-controlled.

### T6 — Plugin abuse (medium, future)
Plugins could read/write arbitrary files, exfiltrate project data, or
abuse provider credentials. ADR-0005 defines capability scoping, an
explicit trust model, validation (hash, version), and sandboxing where the
platform permits. No plugin runtime exists yet; this is pre-implementation.

### T7 — Diagnostics export leakage (medium)
`DebugLogStore.exportJson()` includes event details. If a future caller logs
sensitive values, the export could leak them.
- **Mitigations:** redaction + 1000-char message cap; export is
  user-initiated.
- **Residual:** reviewed on each new logged detail key.

## Controls not yet implemented (owner decisions)

- Production signing/secret custody strategy (Phase 0 open item).
- Threat model for future network/provider layers (deferred until providers
  exist).
- Fuzz corpus for redaction and codec limits (test-layer item).
- SAF import pipeline (deferred to the Import/Export milestone).

## Review cadence

Revisit on: new import formats, the plugin runtime, provider credential
handling, release signing, or any change to storage/parse boundaries.
