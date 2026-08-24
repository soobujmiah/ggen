# GGEN Current State

Snapshot date: 2026-08-24
Repository: `soobujmiah/ggen`
Default branch: `main`
Source of truth: GitHub repository state, tests/CI evidence, and documented physical-device evidence.

## Current phase

**Phase 2 — Responsive workspace and creative-surface foundation: active.** Phase 1 core foundation is complete and green. Phase 2 has a substantial original Flutter workspace/canvas foundation and ongoing Redmi Turbo 4 Pro validation.

## Verified baseline

- Pure-Dart core contracts are implemented and have pinned local verification documented as 27 unit tests passing on 2026-08-20.
- GitHub Actions governance, reusable core tests and Flutter shell tests are documented green on `main` for the Phase 1 verification set.
- Phase 2 has responsive layouts, workspace settings/profiles, diagnostics, persistence adapters, canvas interaction, Select/Draw/Text, multi-select, grid, groups, layer-list, numeric-inspector, **multi-column text frame layout with gutter geometry** (N equal columns, exact-character text flow, overflow indication, inspector + mobile sheet, one-step undoable transactions, JSON round-trip; CI/widget verified) and — in `ggen_core` only, on `feat/page-linked-text-flow` from `main` HEAD `97f8cef` — **page geometry, linked text-frame chains and a deterministic wrapping policy** (Stages 1–3 of the page-linked text-flow milestone; core 141/141 on Dart 3.13.0; app 198 tests green on `main`) documented as implemented — CI verified but not yet exercised on-device and not yet wired into the Flutter shell (Stage 4).
- Redmi Turbo 4 Pro evidence exists for current controls and several editing/persistence flows. Device evidence remains scoped to the exact exported diagnostics and does not imply release, GPU/NPU or benchmark validation.

## Evidence boundary

**Verified:** source implementation and the specific CI/device checks recorded in `docs/phases/phase-1-status.md` and `docs/phases/phase-2-status.md`.

**Not automatically verified:** production release readiness, GPU/NPU execution, performance benchmarks, persistence across reinstall, or any device behavior not represented by current device diagnostics.

## Known / pending validation

- Continue the Phase 2 creative-surface milestone using the documented device evidence boundary.
- Exercise any remaining device-only flows explicitly called out by `docs/phases/phase-2-status.md`, rather than treating implementation or widget tests as device proof.
- Keep measured product limits and migration fixtures explicit before accepting another schema version.
- Keep SAF/MediaStore import/export as a separate storage milestone rather than implying it is complete from file-backed persistence.

## Required reading for the next AI

1. `AI_ASSISTANT.md`
2. `MASTER_SPEC.md`
3. `README.md`
4. `docs/phases/phase-1-status.md`
5. `docs/phases/phase-2-status.md`
6. Relevant architecture/ADR documents
7. Relevant source and tests

## Next recommended milestone

**Stage 4 — app integration of the page/link core (explicitly instructed, not yet started):** on `feat/page-linked-text-flow` (or its successor after merge), wire the verified `ggen_core` substrate into the Flutter shell: controller link/unlink (atomic, one undoable `ProjectToolSession`/`ProjectTransaction`, fail closed, no partial graph mutation), canvas linked-frame chain resolution and per-frame slice rendering, continuation/overflow indicators via `TextFlowChain.terminalOverflowFrame`, `nextFrame` persistence round-trip, page-aware frame creation, legacy behavior preservation. Start from the verified base (`main` HEAD `97f8cef` + stages 1–3 commits) and `docs/architecture/page-linked-text-flow.md`; do not begin unless the core foundation is merged and CI-green on `main`.

Then continue Phase 2 from the exact current `main` HEAD: inspect the latest phase-2 status and recent commits, identify the smallest remaining evidence-backed creative-surface milestone, implement only that scope, run relevant CI checks, update phase/status documentation, and close the session with a commit SHA and handoff update.

## Session handoff rule

A new AI must reconstruct state from this file plus repository evidence. Do not rely on a previous chat session's claims. Before risky/model-switch work, create a named snapshot branch from the known-good HEAD. At session close: review diff/status, run relevant checks, update docs/evidence, commit/push when authorized, record SHA, and leave no unexplained changes.
