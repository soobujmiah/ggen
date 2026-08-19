# ggen_core

Platform-neutral Phase 1 domain contracts for GGEN.

Current implementation includes:

- validated stable IDs;
- immutable minimal document project/artboard/node model;
- bounded revision-based undo/redo transactions;
- professional tool descriptors that reject non-manual, non-mobile-friendly or incomplete quality gates;
- SPDX/license review, source receipts, asset provenance, distribution eligibility and protected-pack availability states;
- project schema/version, path-free transactional storage, resource-bounded jobs and autosave/recovery journal contracts;
- reversible preview/commit/cancel tool sessions and adaptive touch/stylus/mouse/keyboard input events;
- deterministic bounded JSON project serialization and fail-closed schema migration policy;
- pure Dart unit tests.

This package intentionally imports no Flutter, Android, filesystem, network, AI provider, BG/RGEN implementation or protected asset. It is not yet a graphics engine or application.

## Verification

```bash
dart pub get
dart analyze
dart test
```

Pinned environment: Dart 3.13.0 from Flutter 3.47.0. Arena does not include Dart, so verification must use the pinned temporary SDK, Codespaces or GitHub Actions. Do not claim build verification until a completed run is recorded.
