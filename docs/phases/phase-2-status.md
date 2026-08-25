# Phase 2 — Responsive workspace foundation status

**Status:** Active; GitHub-validated foundation with Redmi Turbo 4 Pro evidence in progress.

## Implemented

- pinned GitHub Codespaces Flutter workspace;
- original Flutter studio shell;
- compact-phone, tablet and wide responsive layout contracts;
- compact bottom navigation and wide navigation rail;
- immersive canvas mode with explicit restore control;
- draggable compact workspace Settings sheet;
- hideable wide inspector;
- left/right inspector docking on wide layouts;
- persisted inspector visibility, Canvas-first preference and dock side;
- functional Reset workspace action;
- bounded named workspace profile model and storage;
- profile manager UI for save, apply and delete;
- bounded redacted diagnostics export;
- Flutter framework and uncaught-error capture;
- viewport, canvas geometry, safe-area and keyboard-inset diagnostics;
- app-layer `StudioController` wired to `ggen_core` (project lifecycle, tool sessions, bounded undo/redo, canonical project serialization), with the shell observing it;
- functional New project and Save (canonical JSON) actions, canvas undo/redo history bar, and live object count and revision status;
- in-memory persistence through the core storage contracts: transactional `MemoryProjectStore` with SHA-256 content receipts and a bounded `MemoryRecoveryJournal` with checkpoint cadence and ordered replay; Save now commits through a store transaction and `restore()` reloads a committed project;
- undo/redo journal records (forward deltas and state markers) and shell restore of the last saved project on startup via a persisted storage key; stale or malformed keys fail closed;
- file-backed storage (ADR-0004): `FileProjectStore` (atomic `.ggen` writes with SHA-256 receipts) and `FileRecoveryJournal` (bounded line-log with durable payloads) in the app documents directory, wired through `path_provider`; in-memory adapters remain the default/fallback;
- security and governance docs: `docs/security/threat-model.md` and ADR-0005 (plugin trust model) drafted; adaptive layout widget tests (compact/tablet/wide/zero-size);
- original compact-phone canvas prototype: `StudioCanvas` with pinch-zoom, pan and draw-tap input on an immutable `CanvasViewport`; the Draw tool commits shape nodes through core tool sessions (undoable, journaled), so undo/redo and live object count are exercisable on-device for the first time. Double-tap zoom is deliberately absent (the recognizer's 300ms arena hold delays single-tap resolution); real vector drawing, selection, layer list, zoom controls and stylus input are deferred;
- Text tool (tap prompts for text, commits an undoable text frame), volume-down/up undo/redo (consumed so the system volume is unchanged), two-finger tap undo and three-finger tap redo (raw pointer bursts, <300ms, <20px movement), history bar moved to the bottom-left so it no longer covers the project-name chip, and the chip scrolls horizontally for long names. A shell integration test pins the device-reported Draw flow (nav → canvas tap → node).
- **Select tool**: hit-testing on tap (reverse z-order, shape rect and approximate text rect), visual selection border (`#4E6BFF`), drag-to-move with live preview offset and clamped commit through one undoable tool session. Controller gains `selectedNodeId`, `selectNode()`, `deselectNode()`, `moveNode()` (clamped, finite-delta validated, no-op rejected). `hitTestNode()` is a public utility. Controller and canvas widget tests cover selection, deselection, move, undo/redo, clamping and the selection border visual.
- **Multi-select**: ordered selection (`selectedNodeIds`, primary = most recent), additive taps via the compact toolbar's multi-select toggle or Shift/Ctrl/Cmd on hardware keyboards (`selectNode(toggle:)`), group drag-to-move and Delete-key group delete as ONE undoable step each (`moveNodes`/`deleteNodes`), selection borders on every selected node, layer-list multi-highlight. Gesture targeting uses the touch-down position (ScaleGestureRecognizer's post-slop focal drifts, which made slow drags miss their target); group resize remains deferred.
- **Grid overlay toggle**: 8-unit minor grid with a 64-unit major line every 8th, drawn in artboard coordinates under the nodes (inside the viewport transform, so it scales with the artboard); stroke width divided by the viewport scale keeps lines ~1 screen pixel at any zoom, and minor lines are skipped when their screen spacing falls below ~4.5 px (fit zoom stays clean, no moiré wash). Toggle lives in the compact bottom toolbar (grid + multi-select group before undo/redo) and in the in-canvas zoom overlay on wide/immersive layouts (`grid_toggle` diagnostics event); state is shell-owned view state, default on because it pairs with Ctrl-snap.
- **Layer groups**: group nodes (`DocumentNodeKind.group`) carry a `children` list (member ids, artboard z-order) in extensions; members stay first-class nodes so geometry, z-order, canvas rendering and hit-testing are untouched. Core validates group payloads fail-closed at Artboard construction (non-empty, no duplicates, no missing references, single-level — no nesting, non-group nodes cannot carry `children`). Controller: `createGroup(ids, {name})` and `ungroup(id)` as single undoable steps; group visibility/lock toggles propagate to members in one step; deleting a group deletes its members, deleting a member prunes it from its group (a group that loses every member dissolves); moving a group moves its members; `isGroupNode()`/`groupChildIds()` helpers fail closed. Layer panel: Group selection / Ungroup header buttons (`group_create`/`group_ungroup` events via shell callbacks), group rows with expand/collapse chevron, members indented below, member-count badge; member rows are not draggable this milestone.
- **Layer list panel**: `LayerList`/`LayerPanel` widgets showing all nodes in reverse z-order with kind icon, visibility toggle, lock toggle, delete button, drag-to-reorder handle, selection highlight and z-index badge. Controller gains `toggleNodeVisibility()`, `toggleNodeLock()`, `reorderNodes()`, `deleteNode()` — all through undoable tool sessions. Shell integration: layers toggle button opens a bottom sheet on compact phones and a docked panel on wide layouts. Selection sync between layer list and canvas.
- **Overlay top action bar**: transparent, title-less, icon-only, rendered inside the canvas bounds at the status-bar boundary in contrast color (white icons + shadow over the dark canvas); no AppBar anywhere. Every project action (New, Save, Settings, Diagnostics, Immersive, Dock inspector) lives in a bottom-sheet **More menu** with per-action pin-to-bar (pinned icons render left of More, in user order) and up/down reorder; order + pins persist in `WorkspacePreferences` (sanitized, bounded, fail-closed); project-name chip moved below the bar. Events: `top_action_more`, `top_action_run`, `top_action_pin`/`unpin`, `top_action_reorder`.
- **Configurable secondary canvas toolbar**: three levels — full / mini (essentials strip) / hidden (no remnant; canvas takes the full height) — and three docks — bottom (floating strip above the nav bar) / left / right (vertical strip over the canvas edge below the top bar). Transparent strip (translucent circular button backgrounds); level and dock persist; More actions 'Canvas toolbar' (hidden ↔ full) and 'Dock canvas toolbar' (cycles bottom → left → right); events `canvas_toolbar_toggle` (mode+dock) and `canvas_toolbar_dock`.
- **Tools-only bottom navigation**: Select/Draw/Text; Settings moved into More (`CompactNavigationBar` no longer has a Settings tab).
- **Portrait default canvas**: controller default 1080x1920 (was landscape 1200x800); New project sizes the artboard to the device screen ratio (width 1080, height = width x ratio clamped 1:1..9:20).
- **Edge-to-edge fit-to-screen**: `CanvasViewport.fit` default margin 0 — the artboard spans the full viewport on its limiting axis.
- **Canvas never under the status bar in normal mode**: the body applies the top `SafeArea` in BOTH modes (in immersive the system bars are hidden so the inset is 0 and fullscreen is unaffected); the overlay top bar no longer carries its own inset (the canvas already starts below the status bar), and the project-name chip sits below the bar with clearance — device feedback: buttons overlapped the project name and the zoomed canvas slid under the status bar in normal mode.
- **Numeric text inspector (2026-08-23)**: the wide inspector's text-frame branch is now editable — Content (`1..256` chars, trimmed), numeric Size and X/Y fields with an explicit Apply, replacing the previous read-only X/Y display. `StudioController.updateTextNode(nodeId, {text, size, x, y})` commits all provided fields through ONE undoable tool session (one Apply = one history step; single undo restores the previous payload); `text`/`size` validation mirrors the Text tool (trim + `1..256` chars; finite positive size), position clamps into the artboard like `addTextNode`, malformed text payloads and no-op edits are rejected (false) rather than committing a revision. Invalid input shows a bounded SnackBar and commits nothing. Diagnostics event `inspector_text_edit` (text, size, x, y, revision) alongside the existing `inspector_resize`; not yet exercised on-device.

## App identity

- The device-facing Android app identity is exactly **ggen**: launcher label `ggen` and process name (`applicationId`) `com.example.ggen`, applied by `scripts/prepare_android_identity.py` in the manual APK workflow after the wrapper is generated. The tagline and the internal Dart package identifier (`ggen_app`) are unchanged. `com.example` is provisional until a real application domain is selected.

## Verification

GitHub Actions validates core contracts, governance and Flutter shell tests on code changes. Android debug APK generation is manual-only through `Android debug build (manual mobile test)`.

A manual Android debug build from commit `11ada607` completed successfully in GitHub Actions run `32287854429`. Physical-device behavior is recorded only from user-provided Redmi Turbo 4 Pro diagnostics; CI does not constitute device verification.

The supplied device diagnostics confirmed:

- compact viewport measurements of `471 x 1020` and `471 x 706`;
- canvas geometry of `471 x 353`;
- successful workspace restore;
- immersive enter/restore;
- tool navigation;
- profile application;
- reset requests;
- no Flutter or uncaught errors in the latest clean profile test.

Earlier diagnostics exposed profile-manager lifecycle defects. They were fixed in PR #24 and the subsequent manual retest showed no recurrence. Profile save and delete events were added in PR #25 for future evidence.

The persistence-milestone APK (2026-08-20 08:08:47Z export) confirmed the canvas-first switch fix on-device (`canvas_first` alternates enabled/disabled) and exercised `project_new`, `project_save` (idempotent re-save at the same key/revision/digest), profiles and immersive without crashes. It also exposed a **storage-init defect**: `LateInitializationError: Field '_studio' has already been initialized` — the shell's `_studio` was `late final` but `storage_init` reassigns it when swapping onto the file-backed store. The device run therefore fell back to in-memory storage (saves were not durable). Fixed by making the field reassignable, with a regression widget test using a fake `PathProviderPlatform` that exercises the swap and asserts a real `.ggen` file write on Save. A fresh APK is required to re-validate persistence on-device; the first launch after the fix may log a benign "no stored project" warning for the stale in-memory key from the affected build.

A canvas-shell run on 2026-08-20 (export `09:52Z`) confirmed on the Redmi Turbo 4 Pro: canvas bounds now `471 x 828` (the interactive canvas replaced the old static 4:3 box), tool names logged with selection, New project and Save clean, immersive `471 x 1020` with `safe_top 56`, no errors. It also exposed a diagnostics flood: the settings-sheet animation resized the canvas ~1px per frame and `canvas_geometry` logged ~50 entries in seconds, crowding the bounded log. Fixed by an 8px quantized dedupe key plus a 500ms cooldown, with a widget test asserting ≤8 entries for 60 one-pixel steps. `project_restore` and `history_undo`/`history_redo` remain to be exercised on-device (undo/redo enable only after a Draw-tap creates history).

A file-backed persistence run on 2026-08-20 (export `09:01:17Z`) confirmed on the Redmi Turbo 4 Pro:

- `storage_init` logged info "File-backed storage initialized" at `/data/user/0/com.example.ggen/app_flutter` — the storage-init crash from the previous build is fixed on-device, and the path confirms the `com.example.ggen` applicationId (app-identity milestone) in the live data directory;
- `project_new` and `project_save` exercised across three projects; idempotent re-saves produced identical keys, revisions and digests;
- `canvas_first` alternated correctly across six toggles (switch fix stable);
- profiles save/apply (`y7`, `8djgc`), workspace reset and immersive enter/restore all clean;
- no Flutter or uncaught errors.

No `project_restore` event appeared because the session started with empty preferences (clean install), so the last-project restore path still awaits an on-device restart test: save a project, fully close the app, reopen, and export diagnostics. `_restoreLastProject` now logs an info event for the clean-install case to make that distinction visible in exports. Undo/redo events are likewise still unexercised on-device because no editing tool creates history yet (the buttons are disabled until `commitSession` is wired to real edits).

The text-tool build (2026-08-20, export `12:07:38Z`) confirmed on the Redmi Turbo 4 Pro:

- **Text tool verified on-device**: two `node_add_text` events (`fyug` at 12:06:52Z, `dttd7` at 12:07:21Z), each at object count 1 / revision 1 — text frames are created through the shell dialog and committed as undoable sessions;
- **Persistence with content verified on-device**: `project_save` for `project-1787227624472526` at **revision 1, 432 bytes** (vs 242 bytes for empty projects) — a project containing a text frame was written to the file store;
- New project, profiles (save/apply), workspace reset, immersive enter/restore, canvas-first toggle and the canvas at `471 x 828` all clean; no Flutter or uncaught errors;
- **Draw tool remains unexercised, not disproven**: the run selected Draw (12:07:10Z) and immediately switched to Text (12:07:13Z) without tapping the canvas while Draw was active, so no `node_add` event was expected; the Draw flow is pinned by a passing shell integration test (bottom-bar Draw → canvas tap → node) and needs an on-device tap to confirm;
- **Undo/redo shortcuts unexercised on-device**: no `history_undo`, `history_redo`, `volume_undo`, `volume_redo`, `gesture_undo` or `gesture_redo` events in the export;
- **Restart-restore still unproven**: `project_restore` logged "No prior project stored" (fresh install of the new build again); save → force-close → reopen is still required;
- **Diagnostics noise reduced but not eliminated**: `canvas_geometry` still logged ~28 entries in ~90s while the settings sheet was actively dragged — the 8px quantum collapses smooth animation churn but fast manual sheet drags move the canvas height >8px per frame, so each quantized size is still distinct. Candidate tightening: suppress geometry logging while the settings sheet is open (its resize is expected, not evidence-worthy).

A further clean device run on 2026-08-20 (export `07:49:00Z`) re-confirmed on the Redmi Turbo 4 Pro:

- compact viewport `471 x 1020`, canvas geometry `471 x 353`, zero safe-area/keyboard insets at measurement time;
- workspace restore, tool navigation (Select/Draw/Text/Settings), settings sheet, immersive enter/restore, profile apply (`bb`, `cc`) and workspace reset all exercised;
- no Flutter or uncaught errors.

The same run exposed a **canvas-first switch defect**: six consecutive `canvas_first` "disabled" events showed the settings-sheet switch reporting the sheet-open snapshot instead of reacting to taps (a captured-value switch). Fixed by making the switch own its state (`_CanvasFirstSwitch`), with a widget regression test toggling it off and on. The run's build predates the persistence milestones, so `storage_init`, `project_new`, `project_save`, `history_undo`/`redo` and `project_restore` were not yet exercised on-device; a fresh APK from current `main` is required for that validation.

A device run on 2026-08-22 (export `04:13:30Z`) exercised the current controls on the Redmi Turbo 4 Pro: 26 `node_add` Draw-tool shapes (revisions 1–26), two-finger-tap undo twice (revisions back to 8 then 9), four Bangla text frames (`node_add_text` at revisions 30/31 and 5/11), toolbar zoom in/out/fit, layers sheet, profiles save/apply, workspace reset, immersive enter/restore, `project_new`/`project_save` (twice: `project-1787371120182905` r0/254B and r6/1405B, then `project-1787371850538968` r11/2296B with SHA-256 receipts), `diagnostics_export` — no Flutter or uncaught errors. The run also exposed four defects, all fixed on `main` 2026-08-22 with pinned tests:

- **Select tool added text**: the sequence `tool_select` Select → canvas tap → `node_add_text` showed the canvas routing a non-null text callback to any tool; taps now route by explicit flags (`drawEnabled`/`selectMode`/`textEnabled`).
- **Duplicated canvas controls**: the compact bottom toolbar already carries undo/redo, layers and zoom, so the floating layers button and in-canvas zoom overlay are now wide/immersive-only.
- **Fit-to-screen collapsed the artboard**: the artboard was laid out under the canvas's tight constraints, so the fit transform scaled a 471×803 box and the artboard landed small, left-aligned. The artboard now lays out unconstrained (`OverflowBox`, minima cleared); pinned test measures the centered 439×292.7 artboard at (16, 255).
- **Immersive overlapped the status bar**: immersive now hides system bars (`immersiveSticky`) and the body applies `SafeArea` when bars remain visible.

A follow-up device run on 2026-08-22 (export `05:51:44Z`, APK built from merged `main @ 0244290`, fresh install) validated the device-report fixes on the Redmi Turbo 4 Pro; no Flutter or uncaught errors:

- **Select tool no longer adds text — verified on-device**: the only `node_add_text` (rev 35) followed the Text-tool selection (`tool_select` Text → tap); every other tap ran under Draw (`node_add` revisions 1–34, 45, 1–5) or Select (`node_select`/`node_deselect` for `text-1`, `node-1`, `node-2`, `node-3`, `node-4`). Tapping the canvas in Select mode selected/deselected nodes and never opened the text dialog.
- **Toolbar-only controls on compact — consistent**: every layer and zoom event is toolbar-sourced (`layers_toggle` "Layers via toolbar", `toolbar_zoom_in`/`toolbar_zoom_out`/`toolbar_zoom_fit`); no in-canvas overlay or floating-panel events appeared.
- **Fit-to-screen**: 13 `toolbar_zoom_fit` presses with no errors; the centered fit is pinned by the widget test (artboard 439×292.7 at (16, 255) in 471×803) and confirmed visually.
- **Immersive no longer overlaps the status bar — verified via geometry**: immersive canvas geometry changed from `471×1020, safe_top 56` (old build, drew under the status bar) to `471×964, safe_top 0` — the outer `SafeArea` consumes the 56 px status-bar inset, so the canvas starts below the bar. Enter/restore exercised twice in the run.
- **Content save with a multi-step revision jump**: `project_save` for `project-1787377438114422` at **revision 50, 7121 bytes** (34 shapes + text + selection/moves before the first save — the store's any-advancing-revision policy accepted the jump from a fresh key) and `project-1787377848177373` at revision 7, 1159 bytes; both with SHA-256 receipts.
- **Toolbar undo/redo exercised on-device for the first time**: `history_undo`/`history_redo` ×2 each (rev 45–50) — the buttons enable once history exists and commit cleanly.
- **Previously pending, now exercised**: Draw tool on-device (40 taps), Select hit-testing on both shapes and text frames, profiles save, `canvas_first` toggle, workspace settings, `project_new`.
- **Still unexercised**: restart-restore (save → force-close → reopen; this export was same-session and the start was a clean install), volume-key undo/redo (`volume_undo`/`volume_redo`), two-/three-finger taps (`gesture_undo`/`gesture_redo`), canvas zoom overlay + presets on-device (compact uses the toolbar), and an idempotent re-save or rev-jump re-save at an *existing* key (both saves in this run were first writes to new keys).

A device run on 2026-08-22 (export `07:25:50Z`, APK from merged `main @ 4b72671` — multi-select + grid overlay build, fresh install) closed most of the remaining device gaps; no Flutter or uncaught errors:

- **Volume-key undo/redo verified on-device**: `volume_undo`/`volume_redo` sequences across rev 1–11 (three bursts: 10→6, 6→11, 11→0→5), consuming the key so the system volume is untouched — the first `volume_*` events in any export.
- **Two-finger tap undo verified on-device**: `gesture_undo` fired twice (rev 13→12, and again after re-adding) — first `gesture_*` event in any export.
- **Multi-select additive selection verified on-device**: with the compact toolbar toggle on, `node_select` counts climbed 1→2→3→4→5→6 via repeated taps; tapping an already-selected node toggled it *off* (node-15: 4→3 mid-sequence); with multi-select off, every tap replaced to count 1. `multi_select_toggle` enabled/disabled cleanly multiple times.
- **Select-fix stability**: Select taps produced only `node_select`/`node_deselect` (never a text dialog) across ~30 hits on shapes (`node-*`) and text frames (`text-1`, `text-2`).
- Draw (18 taps), Text (`node_add_text` ×2, rev 6–7), layers sheet + `layer_select`, profiles save ×2, workspace reset, immersive enter/restore (`471×964, safe_top 0` again), toolbar fit/zoom (10× fit, zoom in/out) all clean.
- **Saves with receipts**: `project-1787383226064377` rev 17 / 821 B; `project-1787383362353725` rev 0 / 245 B; `project-1787383547954370` rev 0 / 241 B.
- **Still unexercised**: restart-restore (three fresh-install starts in a row; no force-close → reopen cycle yet), three-finger redo (`gesture_redo`), the **grid-overlay toggle** (no `grid_toggle` event — the grid renders on by default, but the button itself needs one press) and in-canvas zoom overlay/presets (compact uses the toolbar).

## Evidence boundaries

- Responsive widget tests are not physical-device tests.
- Android debug APK success is build evidence, not release evidence.
- User-provided device diagnostics are evidence of the exercised flows only; unexercised flows remain unverified.
- No GPU/NPU, performance, persistence-across-reinstall, or production-release claim is made.

## Next

1. ~~Generate a manual APK only when another device validation cycle is needed~~ (canonical manual workflow; used for every device round).
2. ~~Exercise profile save, apply, delete and reset flows on the Redmi Turbo 4 Pro~~ (verified in the 08:08Z and 09:01Z exports).
3. ~~Exercise the Draw tool on the Redmi with the text-tool build: select Draw, tap the canvas several times, export diagnostics containing `node_add`~~ (verified on-device 2026-08-22, exports `04:13:30Z` and `05:51:44Z`).
4. ~~Exercise the undo/redo shortcuts on the Redmi~~: history-bar buttons **(done, export `05:51:44Z`)**, volume down/up and two-finger undo **(done, export `07:25:50Z`)**; three-finger redo (`gesture_redo`) still pending.
5. Exercise the restart-restore flow: save a project with content, fully close the app, reopen, export diagnostics containing `project_restore` (still unexercised on-device; every start so far logged the clean-install event).
5b. Press the grid-overlay toggle once on device (no `grid_toggle` event yet; the grid renders on by default).
6. SAF/MediaStore user-facing Import/Export (ADR-0004 defers this): share-sheet/SAF picker flow for exporting `.ggen` project files to user-chosen locations and importing them back; progress, cancellation and tests.
7. Creative surface next: Select-tool node selection and move **(done)**; layer list panel **(done)**; zoom controls overlay **(done)**; delete keyboard shortcut **(done)**; canvas-geometry log suppression **(done)**; keyboard zoom shortcuts **(done)**; node resize handles **(done)**; proportional resize (Shift) **(done 2026-08-22, `ResizeDrag` corner-anchored)**; snap-to-grid (Ctrl/Cmd) **(done 2026-08-22, 8-unit grid for move+resize)**; zoom presets & numeric input **(done 2026-08-22, 25-400% + Fit + `Ctrl+1/2/3` + custom % field, `CanvasZoomController.zoomTo`)**; multi-select **(done 2026-08-22, additive toggle + group move/delete as single steps)**; grid overlay toggle **(done 2026-08-22, 8/64-unit grid, scale-aware stroke, toolbar + overlay toggle)**; layer groups **(done 2026-08-22, group/ungroup + member propagation, layer-panel header actions)**; overlay top bar + More menu + collapsible canvas toolbar + portrait default canvas + edge fit **(done 2026-08-22, UI chrome rework per device feedback)**; numeric inspector (content/size editing for text frames) **(done 2026-08-23, `updateTextNode` + editable inspector text branch; CI-verified, on-device exercise pending)**; multi-column text frames with gutter **(done 2026-08-24, PR #51; CI-verified, on-device exercise pending)**; page geometry + linked text-frame chains + deterministic wrapping **(done 2026-08-24, CORE ONLY in `ggen_core` — page geometry, `nextFrame` link model with cycle/dangling/ambiguity validation, word-boundary wrapping policy; Stage 4 app integration pending)**.


## 2026-08-22 UI chrome rework (overlay top bar, More menu, collapsible toolbar, portrait canvas)

Per device feedback; widget tests updated/added; CI validates on GitHub; on-device re-validation pending.

- AppBar removed entirely (no background, no title). A transparent icon-only top bar is drawn inside the canvas bounds at the status-bar boundary, in contrast color; the project-name chip moved below it.
- All project actions in a More bottom sheet: per-action star pin/unpin (pinned icons render left of More in user order) and up/down reorder; order + pins persist in `WorkspacePreferences`.
- Settings removed from the bottom navigation (Select/Draw/Text only).
- Secondary canvas toolbar collapsible (`canvas_toolbar_toggle`; persisted collapsed state; 40 px expand handle).
- Default canvas portrait: controller default 1080x1920; new projects = 1080 x (1080 x screen ratio, clamped 1:1..9:20).
- Fit-to-screen margin 0 (edge-to-edge on the limiting axis).
- **Device-feedback follow-up (this turn):** normal mode canvas now starts BELOW the status bar (body `SafeArea` top always applied; in immersive bars are hidden so the canvas still reaches the screen top) — the zoomed canvas can no longer slide under the status bar, and the project-name chip has clearance below the top bar. Secondary canvas toolbar: full/mini/hidden levels (hidden = no remnant), bottom/left/right docks, transparent strip, persistent; More actions 'Canvas toolbar' + 'Dock canvas toolbar'; events `canvas_toolbar_toggle`, `canvas_toolbar_dock`. Bottom nav stays fixed in normal mode; fullscreen keeps only the top bar, whose actions are all hideable/rearrangeable via More.
- Note: canvas geometry evidence changes — without the AppBar the canvas previously started at the screen top (transparent bar over it); with the top inset always consumed the compact canvas now measures ~471x859 with `safe_top 56` again (status bar below), and fullscreen remains `471x964/safe_top 0`. A fresh device export will record the new geometry.

## 2026-08-24 Multi-column text frame layout & gutter geometry

Implements the multi-column milestone on top of a newly built, platform-neutral text-flow foundation (no such substrate existed at repository head). Core lives in `ggen_core`; the Flutter shell renders, edits and persists it. **Widget/unit verified in CI; not yet exercised on the Redmi Turbo 4 Pro.**

**What shipped**
- `ggen_core/src/text/frame_geometry.dart`, `column_layout.dart`, `text_flow_engine.dart`: `FrameRect`/`FrameGeometry` (padding-aware content rect), N equal-width columns with gutter (`availableWidth = W − (N−1)gutter`, `columnWidth = availableWidth/N`; fail closed when content is too small), and a greedy left→right/top→bottom flow engine with an exact-character conservation invariant (`consumes + overflow == length`). RTL and newspaper balancing are declared but rejected so they cannot be silently mis-ordered.
- Core tests: `column_layout_test.dart` (41 tests — geometry, gutter, clipping, hit testing, serialization round-trip, invalid/legacy decode) and `text_flow_engine_test.dart` (29 tests — wrapping, exact character conservation, overflow, explicit newlines, linked multi-frame LTR flow). `flutter analyze` clean; 70 core tests pass (28 baseline).
- `StudioController.configureTextColumns`/`resetTextColumns` flow through one `ProjectToolSession`/`ProjectTransaction` (one revision, undoable/redoable); invalid input throws before any revision. New text frames get a 480×360 default and are clamped to the artboard. 9 controller tests added (app: 198 total pass).
- Inspector: **Columns** section (count slider 1–24, gutter field, Reset, Apply) for wide layout; a compact **Columns** bottom sheet (`_ColumnsSheet`) for 471 px. Canvas renders per-column clipped `Text` widgets with column guides and a red overflow tab; shape resize remains shape-only.
- Serialization: columns/gutter stored as node extensions (`columns`, `gutter`, plus `w`/`h`); no schema bump; legacy single-line text nodes render unchanged until configured.

**Architectural record:** `docs/architecture/multi-column-text-layout.md`.

**Pending on-device:** build an APK and exercise on the Redmi Turbo 4 Pro (`25053RT47C`) — apply 2/3 columns, change gutter, undo/redo, save/reload persistence, overflow tab, compact Columns sheet. No device claim is made here.

## 2026-08-24 Page geometry & linked text-flow core (Stages 1–3)

Implements the page/link substrate for multi-frame text flow in `ggen_core` only (feature branch `feat/page-linked-text-flow` from `main` HEAD `97f8cef`, after PR #51). Pure Dart; no schema bump, no codec change, no Flutter shell change. **Core 141/141 verified locally on Dart 3.13.0 (exact CI SDK) and by GitHub Actions on the PR; not in the shell, not device-validated.**

**What shipped**
- `ggen_core/src/text/page_geometry.dart`: `PageGeometry`/`PageMargins`/`PageBleed` (fail-closed `create`/`decodeJson`, JSON round-trip, legacy defaults; margins consuming the page rejected) with deterministic `pageRect`/`contentBounds`/`bleedBounds`. `BleedBounds` may carry negative offsets (full-bleed crosses the page edge; `FrameRect`'s non-negative contract untouched); `bleedFitsPage` is the placement check for page-aware frame creation. `decodeJson(null) -> null` keeps page-less legacy documents valid.
- `ggen_core/src/text/text_links.dart`: LINKS-FIRST (no first-class `TextStory`; text stays `extensions['text']`). `TextFlowChain`/`TextFlowLinkSet`/`TextFlowLinkResolver` validate successor links and resolve deterministic chains — self-links, cycles of any length, dangling targets, missing sources and ambiguous two-predecessor references all fail closed. Links persist as a `nextFrame` successor key in text-frame node extensions (only text frames may carry it; target must be same-artboard). `terminalOverflowFrame(result)`: terminal overflow occurs exactly once, on the chain's last frame; per-frame `hasOverflow` on intermediate frames is a continuation indicator. The existing `TextFlowEngine` is reused (no second engine).
- `TextFlowEngine` wrapping policy: word-boundary wrapping (never mid-word when a boundary fits; whitespace = space/tab), whitespace never collapsed/dropped/reordered (conservation exact), trailing whitespace runs consumed in full at line ends, long unbreakable tokens character-split at the exact fit count, trailing/consecutive newlines render explicit empty lines, degenerate-width forced progress preserved. Bounded behavior change: whitespace-containing text only; all 72 pre-existing core tests unchanged.
- Core tests: `page_geometry_test.dart` (27), `text_links_test.dart` (26), `text_wrapping_test.dart` (16) → core suite 72 → 141; `dart analyze --fatal-infos` clean; `dart format` clean.

**Architectural record:** `docs/architecture/page-linked-text-flow.md`.

**Stage 4 (app integration) NOT started:** controller link/unlink (atomic, one undoable tool session), canvas linked-frame chain resolution/rendering, continuation/overflow indicators, `nextFrame` persistence round-trip, page-aware frame creation, legacy behavior preservation. App suite (198) is CI-verified on the PR; Stage 3 may surface widget tests pinning old mid-word splits (review, don't silently rewrite). No device claim is made here.

## 2026-08-24 Linked text-flow app integration (Stage 4)

Implements Stage 4 of the page-linked text-flow milestone on `feat/linked-text-flow-app` from the verified post-merge `main` (PR #52 / merge commit `7eacade`). The Stage-1–3 core substrate is reused unchanged; no second flow engine, no second link representation, no schema migration. **Core 143/143 (Dart 3.13.0) and app 237/237 (Flutter 3.47.0) verified locally with the exact CI toolchains; GitHub Actions re-runs the same gates on the PR. Not device-validated; a debug APK (the `android-build.yml` artifact) is the device-validation candidate.**

**What shipped**
- `StudioController.linkTextFrames`/`unlinkTextFrame`: one valid operation = exactly ONE undoable `ProjectToolSession`/`ProjectTransaction`; fail-closed (missing/wrong-kind/legacy-rect-less nodes and no-ops return false; self-links, cycles of any length, ambiguous two-predecessor targets throw before any mutation, validated through the core `TextFlowLinkResolver`); re-link replaces the successor; `deleteNodes` prunes dangling `nextFrame` references so the link graph stays well-formed.
- `src/text_flow/linked_text_flow.dart` + canvas: `computeLinkedTextFlow` flows each multi-frame chain as ONE story (concatenated `text` in flow order) through the existing `TextFlowEngine`; each frame renders ONLY its assigned slices (conservation exact, no duplication). New indicators: blue right-arrow continuation tab (frame full, story continues — not an overflow) and the red corner tab shown exactly once per chain on the terminal frame (`terminalOverflowFrame`). Malformed links or a chain member without geometry/text/size fall back to the legacy standalone rendering. Chain font size = head frame's size (documented limitation).
- Page-aware frame creation: the artboard is the page (`artboardAsPage`, zero-margin `PageGeometry`); `addTextNode` now places the frame entirely inside the page content bounds (`clampFrameIntoPage`), matching the shape placement contract (one pre-existing clamp test updated to the new contract).
- Persistence: `nextFrame` round-trips through the existing `ProjectCodec` (+2 core codec tests) and controller save/restore; legacy documents without link metadata decode and render unchanged.
- Minimal UI: wide inspector "Text flow" section (deterministic link candidates; "Flows into …" + Unlink; inspector content now scrollable) and the compact Columns sheet's live "Text flow" section. Invalid operations surface the fail-closed message in a SnackBar.
- Tests: +16 module, +17 controller, +3 canvas, +2 widget app tests and +2 core codec tests (app 198 → 237, core 141 → 143); `dart analyze --fatal-infos` clean on core; `flutter analyze` adds no new findings.

**Architectural record:** `docs/architecture/page-linked-text-flow.md` (Stage 4 section + limitations).

**Pending on-device:** install the repository-built debug APK on the Redmi Turbo 4 Pro (`25053RT47C`) and run the linked-flow checklist (link/unlink, indicators, 2/3 columns, gutter, undo/redo, save/reload, no duplicated/lost characters). No device claim is made here.

## 2026-08-24 Mobile workspace shell redesign + device bug fixes

Responds to the first Redmi Turbo 4 Pro diagnostics round for the Stage-4 APK: RenderFlex overflow (1.2px right), Text-tool RangeError (`0..2: 3`), and incoherent accumulated toolbar layout. Feature branch `feat/mobile-workspace-shell` from `main` `b926b28` (post-PR #53). **App 254/254 (Flutter 3.47.0) and core 143/143 (Dart 3.13.0) locally on the exact CI toolchains; analyzer adds no new findings. Not device-validated.**

**What shipped**
- `src/workspace/studio_tool.dart`: typed `StudioTool` enum as the single source of tool identity/order/icons for both the compact rail and wide `NavigationRail`; shell tool state is now `StudioTool`, structurally eliminating the out-of-range index behind the device RangeError (the old 4-destination compact `NavigationBar` forwarded destination index 3 — the contextual Columns entry — into a 3-entry tool list).
- `src/workspace/workspace_bars.dart`: canonical compact shell — stable left `MobileToolRail` (52px, primary tools only, never moves), single bottom `ContextualActionBar` (history | zoom | view groups; contextual multi-select/Columns rendered only in meaningful states), reusable `ToolButton` (40×40, 20px icon, obvious selected state). The dockable/collapsible `_SecondaryCanvasToolbar` and `CompactNavigationBar` are deleted; no competing surfaces remain.
- Top action bar: pinned region is now a bounded `Flexible` horizontal scroller — the reported RenderFlex overflow (all 8 actions pinned × 52px > 471px logical width) was reproduced in a widget test before the fix and is now impossible at any width; the More button keeps its fixed right-edge slot.
- Preferences: legacy `workspace.secondary_toolbar_mode`/`_dock` ignored on load, deleted on save/clear; removed top-action ids fail closed; reset returns to the canonical layout; project data untouched.
- Tests: +17 (`test/mobile_workspace_shell_test.dart`) covering the RangeError gesture cycle (tool switches, frame creation, edit, outside taps, keyboard insets, repeated taps), 471×1020 + 471.04×1020.46 overflow regression with the maximal pin set, action-bar states (no/one/multiple/text selection; per-tool), single-surface invariants, active-tool marking, reset, save/load and linked-flow sheet reachability; 5 legacy compact-layout tests updated to the canonical shell. App suite 237 → 254.

**Architectural record:** `docs/architecture/mobile-workspace-shell.md`.

**Pending on-device:** build a fresh `android-build.yml` debug APK and re-run the device round on the Redmi Turbo 4 Pro (`25053RT47C`): confirm the overflow banner and RangeError no longer appear, exercise the tool rail/action bar/contextual Columns, immersive mode, reset, save/reload and the linked-flow checklist. No device claim is made here.

## 2026-08-24 Vector Studio Milestone 1 — Rectangle + Ellipse primitives

First professional vector-editing slice: adds ellipse and style (fill + optional stroke) on top of the existing shape-node foundation. No second document model; no LAI/AI dependency; reuses selection, move, resize, multi-select, groups, history, persistence and canvas renderer. **Core 143/143 (Dart 3.13.0, exact CI pin), app 276/276 (Flutter 3.47.0, exact CI pin). CI GREEN on `main` @ `1d9b5c2` (formatting fix on top of `b548052`): governance ✅, core/test (format + `dart analyze --fatal-infos` + `dart test`) ✅, flutter-shell test ✅. `flutter analyze` has zero errors; 8 pre-existing info/warnings remain. Not device-validated; no APK built in this milestone.**

**What shipped**
- `src/geometry/shape_geometry.dart` (new): `ShapePrimitive` enum (`rectangle`/`ellipse`), `NodeShapeGeometry` value type (x/y/width/height/fill/stroke/strokeWidth/shapeType), `nodeShapeGeometry` fail-closed reader (returns null on malformed payload), `hitTestNode` (shape AABB + text-frame fallback), text-node aliases for legacy callers; backwards-compat `NodeGeometry`/`nodeGeometry`/`textNodeGeometry` typedefs.
- `ggen_core` Artboard: `_validateShapeGeometry` fail-closed validation for x/y/w/h/fill/stroke/stroke_width/shape_type when any geometry key is present; bare shape placeholders remain accepted.
- `StudioController`: `_addPrimitive` shared primitive creation, `addEllipseNode`, `updateShapeStyle` (one undoable step; clearStroke option; no-op detection). Writes canonical `fill` plus legacy `color` for backwards compatibility; `shape_type` persisted on every shape. Default insertion size kept at 64 px (legacy constant) to preserve on-device muscle memory and existing tests.
- `StudioCanvas`: `ellipseEnabled` tool flag; canvas painters refactored into `_ShapePainter`/`_SelectionPainter` CustomPainters rendering fill + stroke for both rectangles (drawRect) and ellipses (drawOval); selection outline distinguishes primitive. Ellipse taps route to `addEllipseNode`.
- Tool rail: `StudioTool.ellipse` added (enum member named `draw` retained for Rectangle wire-name stability); icon `Icons.circle_outlined`/`Icons.circle`; labels `Select`/`Rectangle`/`Ellipse`/`Text`. Both `MobileToolRail` and wide `NavigationRail` auto-derive destinations from `StudioTool.values` so no index-range regression is possible.
- Inspector shape panel: Fill swatch row, Stroke toggle with color swatches and ± stroke-width stepper (0.5–24); changes apply immediately as one undoable style step via `updateShapeStyle`. Geometry Apply button renamed to "Apply geometry"; style actions fire through the same session history.
- Tests: +22 in `test/vector_studio_m1_test.dart` — primitive creation (rect/ellipse geometry + shape_type), style independence (fill/stroke/width per shape), persistence round-trip for rect (fill+stroke) and ellipse, fail-closed validation (NaN x, non-positive w, non-int fill, negative stroke_width), bare-shape-placeholder compat, legacy `color`-only compat, runtime null-reader on malformed payload, undo/redo for add/style/resize, and wire ↔ enum mapping (unknown wire falls back to rectangle for forward compatibility). Existing 254 app + 143 core tests updated only where necessary (5 tooltip references migrated from "Draw"/brush to "Rectangle"/rectangle icon; node-name expectation preserved as "Shape N"); no test weakened.

**Key contracts**
- Extension keys: `x`/`y`/`w`/`h` (num, finite, positive), `fill` (int ARGB, canonical; legacy `color` also written), `shape_type` ("rectangle"|"ellipse"; absent → rectangle for legacy compat), `stroke` (int ARGB; absent/null → no stroke), `stroke_width` (num ≥ 0; required when stroke present).
- Fail-closed at three layers: core Artboard construction, app `nodeShapeGeometry` reader (null on malformed), and `updateShapeStyle` (ArgumentError + no-op detection).
- Unknown `shape_type` wires degrade to rectangle at render time (fail-safe, not crash).

**Non-goals honored**
- No Bezier, booleans, SVG path authoring, gradients, patterns, text-on-path, vectorization, AI runtime, or Illustrator parity. No parallel `VectorDocument`/`VectorEngine`/`ShapeManager`/`VectorStore` architecture introduced; all changes extend the existing `DocumentNodeKind.shape` + extensions model.

**Pending on-device:** build a fresh APK and exercise on the Redmi Turbo 4 Pro — select Rectangle/Ellipse, create primitives, fill/stroke edits via inspector, move/resize, undo/redo, save/reload persistence, both primitive shapes render distinctly, no RenderFlex or RangeError regressions with the 4th tool. No device claim is made here.

## 2026-08-25 Physical-device UX fixes — Open/Load project, true immersive, free-form fullscreen controls, hidden reorder

Responds to the 2026-08-24 Redmi Turbo 4 Pro physical-device validation round (diagnostics export `2026-08-24T23:14:38Z`, portrait 471×1020): the session was crash-free and exercised startup, compact workspace, immersive mode, layers, multi-select, rectangle/ellipse, text frames, undo/redo, grouping, fullscreen customization and movement, project save, new project and diagnostics export — so this milestone is a UX/behavior fix, not a crash fix. Feature branch from `main` `b061099d0c7f87d760cb123a701cf9fab6828863`. **Pending device validation: a fresh `android-build.yml` debug APK must be tested on the Redmi Turbo 4 Pro before any device claim.**

**What shipped**

- **Open/Load project**: `SavedProjectSummary` + `ProjectStoreListing` (`lib/src/storage/saved_project_summary.dart`); `FileProjectStore.listSavedProjects()` scans `<documents>/projects/*.ggen` (invalid keys and undecodable/corrupt files skipped, most-recent-first) and `MemoryProjectStore` mirrors the semantics; `StudioController.listSavedProjects()` delegates and fails closed. New `EditorTopAction.openProject` / `CanvasControl.openProject` → "Open project" bottom sheet (name, revision, key, save time) → restores through the existing `StudioController.restore(ProjectStorageKey)` (the same path startup restore uses — no second persistence system). Missing/corrupt/malformed keys fail safe (SnackBar + diagnostics; workspace untouched). SAF/MediaStore import/export remains a separate future milestone — the sheet exposes only what the current file-backed store holds. **Fix:** `lastProjectKey` is now shell state included in EVERY workspace save (`_persistWorkspace`); previously any unrelated preference change silently removed the startup-restore key, so the last project could "disappear" from restore.
- **True immersive canvas**: body `SafeArea(top: !_immersive)` — in immersive the canvas/background extends edge-to-edge underneath the hidden status-bar/cutout region (the device-reported unused status-bar-height strip is gone); normal mode still consumes the top inset (canvas never under the status bar). Interactive floating clusters clamp into `MediaQuery.viewPadding` (cutout + gesture safety) via the pure placement math. `immersive_mode` diagnostics now record `padding_*`/`view_padding_*`.
- **Free-form fullscreen controls** (`control_layout.dart` rework): `ControlRegion` and `nearestRegion` snap math REMOVED. `FullscreenControlCluster {id, controls, position}` with a normalized top-left anchor (x/y ∈ 0..1) → robust across device sizes/orientations. `estimatedClusterSize` shares rendering constants with `CanvasControlCluster`; `clusterPixelsForNormalized`/`normalizedForClusterPixels` clamp clusters fully inside the safe viewport. Clusters drag freely (long-press 300ms → 1:1 pointer delta, no snapping, no collision relocation); overlapping clusters ALL render (last-touched brought to front = receives gestures first); positions persist under `workspace.fullscreen_clusters` (legacy `workspace.fullscreen_regions` migrates on load, removed on next save). Immersive exit control: still guaranteed present by `resolve()`, but free-placed like any other cluster. Idle de-emphasis: `kFullscreenIdleTimeout` (6s) → 45% opacity in place; any interaction restores prominence; never relocates/hides.
- **More-menu reorder**: permanently-visible reorder arrows removed. Rows are a `ReorderableListView` (no default handles): tap = execute; long-press = reorder mode for that row (drag handle + up/down arrows appear); drag/arrow commits + persists; release or any outside tap exits reorder mode without executing.
- **Customizer**: per-control picker now targets floating groups (existing groups + Hidden + "New group…" = `groupN` ids, center default position); positions are edited by dragging in fullscreen (no modal position UI).
- **Tests**: `control_layout_test.dart` rewritten (cluster model, resolve/merge/cap/dedupe/exit-guarantee, prefs round-trip + legacy migration, pixel↔normalized math, clamping, move/bring-to-front/assign/remove/next-id); `fullscreen_landscape_shell_test.dart` extended (default clusters incl. Open project, customization persists, free drag persists with no region names, overlapping clusters both render and move independently, idle fade/restore without relocation); `workspace_preferences_test.dart` updated (clusters key round-trip/malformed/clear + legacy read/removal); NEW `more_menu_reorder_test.dart` (normal menu has no reorder affordances, tap executes, long-press enters reorder mode, arrow + drag reorder persist, release/outside interaction exits); NEW `project_open_test.dart` (list + open restores state and remembers the key, empty-store message, missing project fails safe, last-project key survives unrelated workspace changes); store listing tests for both adapters; controller `listSavedProjects` delegation test.
- **Docs**: `CURRENT_STATE.md`, `docs/architecture/fullscreen-control-and-landscape-plan.md` (supersession section), `CHANGELOG.md`, this record.

**Verification so far:** app suite 339/339 (Flutter 3.47.0 / Dart 3.13.0, exact CI pins) locally and GREEN on GitHub Actions for the feature branch (PR #61: `flutter-shell` ✅ 339 tests passed, `public-governance` ✅); `flutter analyze` adds no new findings (8 pre-existing baseline items); core 143/143 + `dart analyze --fatal-infos` clean. Debug APK built from the branch via `android-build.yml` (run `32793182007`, artifact `ggen-debug-apk`, SHA-256 `755e900f…`).

**Pending on-device:** install that APK and exercise on the Redmi Turbo 4 Pro: Open/Load project (save → list → open → restart restore), normal mode top area unchanged, immersive occupies the full display (no status-bar strip, system bars hidden, exit reachable), floating controls drag anywhere with no snapping, two overlapping clusters both visible and independently movable, positions persist across restart, idle de-emphasis + interaction restore, More menu normal/reorder states, then export fresh diagnostics. No device claim is made here.

## 2026-08-25 Physical-device fixes follow-up — duplicate-node-ID regression + free-form fullscreen control UX refinements

Follows the 2026-08-25 Redmi Turbo 4 Pro validation round (diagnostics export `2026-08-25T07:26:32Z`, portrait 471×1020) on the SAME feature branch as the entry above (PR #61). That round proved Open Project (`project_open` of "ছমছছয়"), true immersive fullscreen (canvas 419×912 → 471×1020), the editing core and cluster persistence (`fullscreen_clusters: 3`) on-device — and exposed two follow-up areas fixed here. **Pending device validation: a fresh `android-build.yml` debug APK from the new branch head must be tested on the Redmi Turbo 4 Pro before any device claim.**

**What shipped**

- **Duplicate-node-ID regression (P0)**: device evidence — after opening the existing project, 23 draw gestures each threw `Invalid argument(s): Duplicate node ID: node-N` (shapes silently lost) and the first text add threw an uncaught `Duplicate node ID: text-1`. Root cause: `StudioController` mints ids from per-kind counters (`node-$_shapeCount`, `text-$_textCount`, `group-$_groupCount`) that were never seeded from the loaded document, so the first new object after `restore()` collided with the project's existing `node-1`/`text-1` and `Artboard._requireUniqueIds` threw. Fix: `restore()` reseeds all three counters from the loaded project (max numeric suffix per id prefix); counters never decrease mid-session, so deletes, undo/redo and grouping/ungrouping cannot reintroduce collisions. The FIRST new object after opening any project succeeds immediately; no uniqueness validation weakened, no errors swallowed, no reliance on failed attempts advancing counters.
- **Fullscreen drag rework**: clusters now drag through an in-place long-press gesture (`GestureDetector` `onLongPressStart`/`MoveUpdate`/`End`, live 1:1 pointer tracking in the fullscreen Stack's coordinate space) instead of the `LongPressDraggable` feedback overlay. Cluster buttons use manual-trigger tooltips (semantics labels preserved) so the drag owns every long press deterministically — no gesture-arena fight on device. Clamped only into the safe viewport at the boundary; canceled gestures restore the drag-start position; new `fullscreen_control_drag_start`/`fullscreen_control_drag_cancel` diagnostics.
- **Orientation-aware defaults**: never-customized layouts derive per orientation — PORTRAIT keeps the corner arrangement; LANDSCAPE places one tool/navigation cluster on the LEFT side and one action cluster on the RIGHT side (both vertically centered), leaving the center maximum canvas. First customization materializes the rendered defaults into persisted user state; Reset returns to the orientation-aware defaults.
- **Idle de-emphasis**: fade floor raised 45% → `kFullscreenIdleOpacity` (0.6, public const) — subdued but clearly visible and usable; any interaction restores full prominence; a dragged cluster never fades mid-drag. Timeout (6s) unchanged.
- **Persistence**: normalized positions persist as before under `workspace.fullscreen_clusters`; on rotation/viewport change they re-clamp at render time (a portrait placement always recovers in landscape).

**Verification so far:** app suite **352/352** locally on the exact CI pins (Flutter 3.47.0 / Dart 3.13.0) — new `duplicate_id_regression_test.dart` (7 tests: shape/text/group after restore, delete/group/ungroup, non-contiguous high numeric suffixes, empty-project baseline, same-controller restore), `control_layout_test.dart` +2 (landscape left/right defaults, portrait unaffected), `fullscreen_landscape_shell_test.dart` +4 (landscape side placement with the center free, portrait corner arrangement pinned, rotation keeps a dragged cluster in-bounds, idle-drag restores prominence) plus updates to the new drag/tooltip structure; `flutter analyze` adds no new findings (8 pre-existing baseline items); core 143/143 unchanged. GitHub Actions re-run on the pushed branch (PR #61); a fresh debug APK must be built from the new head via the manual `android-build.yml` workflow.

**Pending on-device:** open an existing project → add rectangle/ellipse/text/group immediately with no duplicate-ID errors or uncaught exceptions; immersive fullscreen; drag clusters freely with no edge snapping; overlap two clusters without losing either; idle fade stays usable; landscape shows left/right clusters with the center free; positions persist across rotation/restart; More-menu reorder; export fresh diagnostics. No device claim is made here.

## 2026-08-25 Fullscreen drag handle + landscape side rails

Post-fix device round verified Duplicate-ID PASS (open existing project → 6 rectangles + 5 ellipses + `text-1`, zero duplicate-ID / uncaught errors). Remaining UX: faded/edge-stuck fullscreen clusters and a landscape bottom bar (1020×471 screen → 1020×367 canvas). Same PR #61 branch. **No device claim for this chrome change.**

- Dedicated cluster drag handle (immediate pan); long-press-on-body retained; buttons ignore presses during drag.
- Idle fade floor 0.6 → 0.82. Clamp only at the safe viewport (not snap).
- Diagnostics: `cluster_drag_start` / `cluster_drag_update` / `cluster_drag_end` / `cluster_position` / `cluster_clamp` / `cluster_idle_fade`.
- Compact landscape: LEFT `MobileToolRail` + RIGHT `LandscapeActionRail`; no bottom bar. Portrait unchanged.
- Duplicate-ID reseeding and More-menu reorder untouched.

**Device evidence (Redmi Turbo 4 Pro, export `2026-08-25T13:30:49.911483Z`, APK run `32848917825`):** zero Flutter/uncaught/duplicate-ID errors. Portrait `compact_bottom_navigation` 471×1020, canvas 419×912. Immersive canvas 471×1020. Cluster drags of `document` and `tools` through interior normalized positions (`clamped: false`); `cluster_clamp` only at safe y=0 / y=1. `cluster_idle_fade` opacity 0.82. Landscape `compact_landscape` 1020×471, canvas **916×415** (left+right 52px rails, no bottom bar); `landscape_history_undo` / `landscape_history_redo`. 10 rectangles + 5 ellipses + two text frames (`cuycj`, Bangla) + group of 3; save r24/4481 B; reopen same key; further adds after reopen. More pins recorded; no `top_action_reorder`. No columns/link/overflow events.
