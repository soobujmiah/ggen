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

## Latest working change (2026-08-25 — Fullscreen cluster drag handle + landscape side rails)

Continues PR #61 (`feat/device-ux-freeform-fullscreen-project-open`) after the post-fix Redmi Turbo 4 Pro round: Duplicate-ID is device-PASS (open existing project → 6 rectangles + 5 ellipses + `text-1`, zero duplicate-ID / uncaught errors; selection/multi-select/group/layers/profile/More-open all worked). Remaining complaints: fullscreen clusters still felt faded/edge-stuck, and compact landscape still used a bottom bar (`compact_landscape`, screen 1020×471, canvas 1020×367).

**Changes (this commit):**

- Dedicated cluster drag handle with immediate pan; long-press-on-body retained; buttons ignore presses during drag.
- Idle fade floor 0.6 → 0.82. No edge snap (clamp only at the safe viewport).
- Diagnostics: `cluster_drag_start` / `cluster_drag_update` / `cluster_drag_end` / `cluster_position` / `cluster_clamp` / `cluster_idle_fade`.
- Compact landscape: LEFT tool rail + RIGHT action rail, no bottom bar.
- Duplicate-ID reseeding and More-menu reorder left untouched.

**Status:** CI GREEN at `2beacc48ab64eecdc8f813dfc58a64ed9a5d29f9` — core **143/143**, app **353/353**, governance green. Debug APK: workflow run `32848917825`, artifact `ggen-debug-apk` (74,695,255 bytes). Device validation of this chrome change is NOT claimed. The 27-item linked-flow checklist remains NOT TESTED on this APK. PR #61 left open (not merged): chrome/layout still needs Redmi evidence.

## Previous working change (2026-08-25 — Physical-device fixes follow-up: duplicate-node-ID regression + free-form fullscreen control UX refinements)

Follows the 2026-08-25 Redmi Turbo 4 Pro validation round (diagnostics `2026-08-25T07:26:32Z`) on the SAME feature branch as the previous entry (PR #61, branch `feat/device-ux-freeform-fullscreen-project-open` from `main` `b061099d0c7f87d760cb123a701cf9fab6828863`). That round proved Open Project, true immersive fullscreen and the editing core on-device, and exposed two follow-up areas: a duplicate-node-ID regression that made the FIRST shape after Open Project silently fail and text-add crash, and fullscreen control clusters that still felt stuck at the screen edges, faded too faint, and had no landscape placement.

**Changes:**

- **Duplicate-node-ID regression (P0)**: root cause — `StudioController` mints node ids from per-kind counters (`node-$_shapeCount`, `text-$_textCount`, `group-$_groupCount`) that were never seeded from a loaded document, so the first new object after `restore()` collided with the project's existing `node-1`/`text-1`/`group-1` and `Artboard._requireUniqueIds` threw (on-device: 23 shapes silently lost, text add crashed with an uncaught error). Fix: `restore()` now reseeds all three counters from the loaded project (max numeric suffix per id prefix); counters never decrease mid-session, so deletes, undo/redo and grouping/ungrouping cannot reintroduce collisions. The FIRST new object after opening any project succeeds immediately. No uniqueness validation weakened; no errors swallowed; no reliance on failed attempts advancing counters.
- **Free-form fullscreen control UX (P1)**:
  - **Drag rework**: clusters now drag through an in-place long-press gesture (`GestureDetector` `onLongPressStart`/`onLongPressMoveUpdate`/`onLongPressEnd`) instead of the `LongPressDraggable` feedback overlay. The cluster follows the pointer 1:1 live (no snapping, no collision relocation), clamped only into the safe viewport at the boundary; a canceled gesture restores the drag-start position. Cluster buttons use manual-trigger tooltips (semantics labels preserved) so the drag owns EVERY long press deterministically — no gesture-arena fight with tooltips on device.
  - **Orientation-aware defaults**: never-customized layouts now derive per orientation — PORTRAIT keeps the familiar corner arrangement (document top-right, history bottom-right, tools bottom-left); LANDSCAPE places ONE tool/navigation cluster on the LEFT side and ONE action cluster on the RIGHT side (both vertically centered), leaving the center maximum canvas. The first customization (drag or customizer) materializes the rendered defaults into persisted user state; Reset returns to the orientation-aware defaults.
  - **Idle de-emphasis**: fade floor raised 45% → `kFullscreenIdleOpacity` (0.6, public const) — subdued but clearly visible and usable; any interaction restores full prominence; a cluster being dragged never fades mid-drag. `kFullscreenIdleTimeout` (6 s) unchanged.
  - **Persistence**: normalized positions persist as before under `workspace.fullscreen_clusters`; on rotation/viewport change they re-clamp at render time so a portrait placement always recovers in landscape.
- **Tests**: +13 → app suite **352/352** locally on the exact CI pins (Flutter 3.47.0 / Dart 3.13.0): new `duplicate_id_regression_test.dart` (7 tests — shape/text/group after restore, delete/group/ungroup, non-contiguous high numeric suffixes, empty-project baseline, same-controller restore); `control_layout_test.dart` +2 (landscape left/right defaults, portrait unaffected by the parameter); `fullscreen_landscape_shell_test.dart` +4 (landscape side placement with the center free, portrait corner arrangement pinned, rotation keeps a dragged cluster in-bounds, idle-drag restores prominence) plus updates to the new drag/tooltip structure. `flutter analyze`: no new findings (8 pre-existing baseline items). Core remains 143/143 with `dart analyze` clean. CI re-runs on the pushed branch (PR #61).
- **Diagnostics**: new `fullscreen_control_drag_start` / `fullscreen_control_drag_cancel` events so the next device round records exactly when a drag starts, ends or is canceled.
- **Docs**: this entry, `CHANGELOG.md`, `docs/phases/phase-2-status.md` dated record.

**Status:** fresh debug APK must be built through the manual `android-build.yml` workflow from the new branch head, then validated on the Redmi Turbo 4 Pro — **no device claim is made until the new APK is tested on-device** (checklist: open an existing project → add rectangle/ellipse/text/group immediately with no duplicate-ID errors; immersive fullscreen; drag clusters freely with no edge snapping; overlap two clusters without losing either; idle fade stays usable; landscape shows left/right clusters with the center free; positions persist across rotation/restart; More-menu reorder; export fresh diagnostics).

**Previous entry (2026-08-25 — Physical-device UX fixes: open/load project, true immersive, free-form fullscreen controls, hidden reorder):** superseded for the fullscreen-control interaction details by this follow-up (drag mechanism, orientation-aware defaults and the idle fade floor changed as recorded above; the Open/Load project flow, true immersive edge-to-edge canvas, overlap rendering rules and the More-menu long-press reorder model are unchanged). See the `CHANGELOG.md` entry for the full record.

## Next recommended milestone

**Physical-device validation of the follow-up build:** build a fresh debug APK through the manual `android-build.yml` workflow from the new branch head and validate on the Redmi Turbo 4 Pro (`25053RT47C`): open an existing project → add rectangle/ellipse/text/group immediately (no duplicate-ID errors, no uncaught exceptions), normal-mode system area unchanged, immersive mode actually uses the full display area with reachable exit, free-form floating controls (drag anywhere with no edge snapping, overlap keeps both, positions persist, idle de-emphasis stays usable, interaction restores prominence, landscape places clusters on the left/right sides with the center free), More-menu reorder (hidden normally, long-press reveals, reorder persists), then export fresh diagnostics. Do not claim device validation until actual on-device results are recorded.

Then continue Phase 2 from the exact current `main` HEAD: inspect the latest phase-2 status and recent commits, identify the smallest remaining evidence-backed creative-surface milestone, implement only that scope, run relevant CI checks, update phase/status documentation, and close the session with a commit SHA and handoff update.

**AI Gateway Runtime is not the next GGEN implementation milestone.** It remains a separately documented architecture track until an explicit implementation scope/repository boundary is established.

## Session handoff rule

A new AI must reconstruct state from this file plus repository evidence. Do not rely on a previous chat session's claims. Before risky/model-switch work, create a named snapshot branch from the known-good HEAD. At session close: review diff/status, run relevant checks, update docs/evidence, commit/push when authorized, record SHA, and leave no unexplained changes.
