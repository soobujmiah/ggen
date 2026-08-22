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
7. Creative surface next: Select-tool node selection and move **(done)**; layer list panel **(done)**; zoom controls overlay **(done)**; delete keyboard shortcut **(done)**; canvas-geometry log suppression **(done)**; keyboard zoom shortcuts **(done)**; node resize handles **(done)**; proportional resize (Shift) **(done 2026-08-22, `ResizeDrag` corner-anchored)**; snap-to-grid (Ctrl/Cmd) **(done 2026-08-22, 8-unit grid for move+resize)**; zoom presets & numeric input **(done 2026-08-22, 25-400% + Fit + `Ctrl+1/2/3` + custom % field, `CanvasZoomController.zoomTo`)**; multi-select **(done 2026-08-22, additive toggle + group move/delete as single steps)**; grid overlay toggle **(done 2026-08-22, 8/64-unit grid, scale-aware stroke, toolbar + overlay toggle)**; layer groups **(done 2026-08-22, group/ungroup + member propagation, layer-panel header actions)**; overlay top bar + More menu + collapsible canvas toolbar + portrait default canvas + edge fit **(done 2026-08-22, UI chrome rework per device feedback)**; then numeric inspector (content/size editing for text frames).


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
