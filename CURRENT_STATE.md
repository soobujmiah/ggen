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
- Phase 2 has responsive layouts, workspace settings/profiles, diagnostics, persistence adapters, canvas interaction, Select/Draw/Text, multi-select, grid, groups, layer-list, numeric-inspector, **multi-column text frame layout with gutter geometry** (N equal columns, exact-character text flow, overflow indication, inspector + mobile sheet, one-step undoable transactions, JSON round-trip; CI/widget verified) and the **page-linked text-flow milestone** — Stages 1–3 (page geometry, linked text-frame chains, deterministic wrapping) in `ggen_core` merged via PR #52 (merge commit `7eacadedc30ebda41315bc65813edc44a4d681bd`), and Stage 4 (app integration: controller link/unlink with fail-closed one-step undoable transactions, per-frame slice rendering of linked chains, blue continuation / red terminal-overflow indicators, page-aware frame creation, `nextFrame` persistence, minimal link UI) implemented on `feat/linked-text-flow-app` from that merge. Core 143/143 (Dart 3.13.0, exact CI SDK) and app 237/237 (Flutter 3.47.0, exact CI pin) verified locally with the exact toolchains; GitHub Actions re-runs the same gates on the PR. Not yet exercised on-device; a debug APK built from the repository's `android-build.yml` pipeline is the device-validation candidate.
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

## Latest working change (2026-08-24, after the first device round)

The first Redmi Turbo 4 Pro diagnostics round on the Stage-4 APK reported a RenderFlex overflow (1.2px right), a Text-tool RangeError (`Not in inclusive range 0..2: 3`) and an incoherent accumulated toolbar layout. Branch `feat/mobile-workspace-shell` (from `b926b28`) fixes both bugs at their root (typed `StudioTool` enum eliminates the out-of-range tool index; the top action bar's pinned region is now a bounded scroller) and replaces the compact shell's three competing toolbar surfaces with one canonical layout: stable left tool rail + single bottom contextual action bar; legacy toolbar dock/mode preferences retired fail-closed. App 254/254, core 143/143 on exact CI toolchains; not device-validated. See `docs/architecture/mobile-workspace-shell.md`.

## AI Gateway Runtime documentation

An architecture/engineering specification for a separate provider-agnostic AI Gateway Runtime has been added at `docs/architecture/ai-gateway-runtime.md`. It is documentation/architecture only at this stage and does **not** claim that the Gateway Runtime has been implemented in GGEN. The specification covers provider adapters, normalized AI contracts, capability-aware routing, bounded retry/failover, health/circuit-breaker behavior, structured tool runtime, Android permission boundaries, secret handling, audit, threat model, testing, milestone sequencing, and an agent execution contract. Public release of that runtime is not authorized until its implementation and release gates are independently verified.

The GitHub commit adding the specification is `251a022475c7a6cc61f32996ecae455037b2210e`.

## Next recommended milestone

**Physical-device validation of the linked text flow (separate milestone):** with the Stage-4 branch merged and CI-green on `main`, install the repository-built debug APK on the Redmi Turbo 4 Pro (`25053RT47C`) and exercise the checklist in `docs/architecture/page-linked-text-flow.md` / the device checklist of the current milestone: create two text frames, configure 2/3 columns + gutter, overflow the first frame, link A → B, confirm the story continues into B with the blue continuation indicator, verify the red terminal-overflow tab appears exactly once, test unlink/invalid-link/undo/redo, save/reload, and confirm no duplicated or lost characters. Do not claim device validation until actual on-device results are recorded.

Then continue Phase 2 from the exact current `main` HEAD: inspect the latest phase-2 status and recent commits, identify the smallest remaining evidence-backed creative-surface milestone, implement only that scope, run relevant CI checks, update phase/status documentation, and close the session with a commit SHA and handoff update.

**AI Gateway Runtime is not the next GGEN implementation milestone.** It remains a separately documented architecture track until an explicit implementation scope/repository boundary is established.

## Session handoff rule

A new AI must reconstruct state from this file plus repository evidence. Do not rely on a previous chat session's claims. Before risky/model-switch work, create a named snapshot branch from the known-good HEAD. At session close: review diff/status, run relevant checks, update docs/evidence, commit/push when authorized, record SHA, and leave no unexplained changes.
