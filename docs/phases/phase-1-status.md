# Phase 1 — Core Foundation Status

**Status:** Core foundation complete and green; the original Flutter canvas shell now consumes the core contracts (see Phase 2).

## Implemented contracts

- validated stable identifiers and immutable document/artboard/node values;
- bounded revision-based undo/redo transactions with stale-transaction rejection;
- professional tool descriptors, typed parameters, mandatory computer-quality gates and mobile-friendly input declarations;
- SPDX expression validation strategy, `LicenseDescriptor`, `SourceReceipt`, `AssetProvenance`, distribution eligibility and protected availability states;
- project schema/version envelope contracts;
- path-free transactional project storage interfaces and content-addressed store receipts;
- finite resource budgets, explicit bounded job states/transitions and progress/failure contracts;
- bounded autosave policy and append/replay recovery journal interfaces;
- reversible tool-session preview/commit/cancel semantics;
- adaptive touch, stylus, mouse and keyboard capability/event contracts that reject unsupported pressure or tilt claims;
- deterministic bounded JSON project serialization, canonical extension ordering and fail-closed schema migration policy.

This slice deliberately contains no copied reference UI, no protected-asset mutation or bytes, no AI/provider call, no platform path, no Flutter widget and no graphics implementation.

## Verification state

- Source implementation: pure Dart under `packages/ggen_core`.
- Local pinned-Dart verification on 2026-08-20: Dart SDK 3.13.0; format check passed, `dart analyze --fatal-infos` passed, and **27 unit tests passed** (grown from 22 on 2026-08-19 as tool-session and input contracts gained coverage).
- Dependency resolution: exact direct versions and generated `pubspec.lock` are committed; all 59 locked dependency receipts (48 core + 11 app plugin family) carry provenance with unresolved license status explicitly blocking distribution until review.
- Public governance: legal files, provenance, documentation, public/private boundary, absent-pack state, build-security, full reachable-history safety scan and source receipt all pass locally and in CI.
- GitHub Actions: governance, reusable core tests and Flutter shell tests are green on `main` (latest merged run set for commit `b1ff424`). Earlier billing failures remain historical operational evidence, not a current source-code result.
- Flutter application verification: the Phase 2 shell is the creative surface built on these contracts; widget tests and user-provided Redmi Turbo 4 Pro diagnostics are recorded in `docs/phases/phase-2-status.md`. No GPU/NPU, performance or release claims are made.

## Next after the green foundation

1. ~~Pin/provision the Codespaces Flutter/Android toolchain~~ (pinned in `config/toolchain.yaml`; CI uses the exact pin).
2. ~~Prototype an original compact-phone canvas shell using the same contracts~~ (initial prototype: `StudioCanvas` with pan/zoom and a Draw-tool session action; see `docs/phases/phase-2-status.md`).
3. ~~Add tablet/desktop adaptive tests before adding creative surface breadth~~ (adaptive layout widget tests added).
4. Define measured product limits and explicit migration fixtures before accepting another schema version.

Redmi Turbo 4 Pro physical testing becomes mandatory when Android builds, UI, storage, performance or backend claims begin. No physical-device claim is made by this package verification.
