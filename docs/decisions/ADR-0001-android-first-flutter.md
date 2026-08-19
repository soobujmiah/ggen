# ADR-0001 — Android-first Flutter shell

**Status:** Accepted by owner, 2026-08-19

## Decision

Phase 1 targets Android first using Flutter for the application shell and adaptive UI. Core domain contracts must remain platform-neutral Dart where practical. Native Android plugins/adapters own low-level graphics, codecs, secure storage, WorkManager, NNAPI/QNN, and other platform APIs.

## Consequences

- Original UI can support phone/tablet and later desktop shells.
- Native compute must never leak directly into features.
- Canvas architecture requires early frame-budget prototypes; Flutter suitability for every graphics operation is not assumed.
- Plugin architecture has two levels: safe in-process Dart extensions and reviewed native extensions.
- Desktop support is an expansion path, not a Phase 1 promise.
