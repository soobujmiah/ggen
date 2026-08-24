# Page geometry & linked text flow (core + app integration)

**Status:** implemented on 2026-08-24. Stages 1–3 (page geometry, linked
text-frame chains, deterministic wrapping) in `ggen_core`, merged via PR
#52 (merge commit `7eacadedc30ebda41315bc65813edc44a4d681bd`). Stage 4
(Flutter app integration: controller link/unlink, linked-frame slice
rendering, flow indicators, page-aware frame creation, minimal link UI)
is the Stage-4 feature branch built on that merge. Verification: core
143/143 with Dart 3.13.0 (exact CI SDK), app 237/237 with Flutter 3.47.0
(exact CI pin), both run locally with the exact toolchains; GitHub
Actions re-runs them on the PRs. **Not physical-device validated** — a
debug APK built from the repository's `android-build.yml` pipeline is
the device-validation candidate for the Redmi Turbo 4 Pro.

## Why this exists

The multi-column text milestone (PR #51) added a deterministic
text-flow engine that accepts an *ordered list* of frames, but the
repository had no model for *why* frames are ordered: no page geometry,
no link/chain model, no cycle or dangling-link validation, and wrapping
semantics were width-only (mid-word splits). This milestone adds that
substrate in the smallest platform-neutral form, without a schema bump
and without touching the existing engine's contract.

## Decisions

1. **LINKS-FIRST.** Linked frames are represented by a single successor
   pointer per text frame, persisted through the existing `DocumentNode`
   extensions mechanism (`nextFrame` = frame id string). A first-class
   persisted `TextStory` is deliberately NOT introduced: text remains
   `extensions['text']` per node. A future `TextStory` is a separate,
   deliberate schema/migration milestone and must not be mixed into this
   work.
2. **No codec change, no schema bump.** Node extensions are free-form
   canonical JSON (same mechanism the merged `columns`/`gutter` use), so
   link metadata persists unchanged and legacy nodes without it keep
   working (isolated single-frame chains).
3. **The existing `TextFlowEngine` is reused.** No second flow engine is
   created; the link model resolves an ordered chain and the engine flows
   it.
4. **Page margins are not frame padding.** `PageMargins` shape the page;
   `FrameGeometry.innerPadding` shapes a frame. They are separate value
   types and must not be conflated.

## Stage 1 — Page geometry (`src/text/page_geometry.dart`)

- `PageMargins`: immutable, fail-closed (`const` + validated `create`
  factory, same pattern as `ColumnLayout`), JSON round-trip, legacy zero
  default.
- `PageBleed`: uniform bleed (finite, >= 0); per-side bleed is
  deliberately unrepresented so it cannot be silently approximated.
- `PageGeometry`: `create`/`decodeJson` fail closed (invalid dimensions,
  margins consuming the page). Derived, deterministic rectangles:
  `pageRect`, `contentBounds` (page inset by margins), `bleedBounds`.
- `BleedBounds`: dedicated value for the full-bleed artwork region.
  Unlike `FrameRect` (non-negative artboard coordinates) it may carry
  negative `left`/`top`: full-bleed artwork legitimately crosses the page
  edge (trimmed at export). `PageGeometry.bleedFitsPage` reports whether
  the bleed region stays inside the page (the placement check for
  page-aware frame creation).
- `decodeJson(null) -> null`: legacy documents carry no page data and are
  treated as having no page.

## Stage 2 — Linked text frames (`src/text/text_links.dart`)

- `TextFlowChain`: immutable, ordered, validated chain; a frame cannot be
  visited twice. `terminalOverflowFrame(result)`: terminal overflow
  occurs exactly once — on the chain's last frame when
  `overflowLength > 0`; per-frame `hasOverflow` on intermediate frames is
  a *continuation* indicator, not an overflow.
- `TextFlowLinkSet`: resolved structure for a frame set; deterministic
  chain order (heads sorted lexicographically); successor map;
  `chainFrom` (StateError for mid-chain entries), `chainContaining`.
- `TextFlowLinkResolver.resolve(frameIds, links)`: fail-closed validation
  with precise errors — self-links, cycles of any length (white/gray/
  black over the functional graph), dangling targets, missing link
  sources, ambiguous references (two predecessors), invalid frame ids
  (same contract as `GgenId`).
- `fromArtboard` / `fromProject`: read `nextFrame` from text-frame node
  extensions. Only text-frame nodes may carry it (any other kind throws,
  mirroring the existing group-`children` rule); the target must be a
  text frame in the SAME artboard.

## Stage 3 — Wrapping policy (`src/text/text_flow_engine.dart`)

The flow layer owns a deterministic line-break policy; the measurement
provider remains a width/measurement oracle:

- Whitespace = space (U+0020) + tab (U+0009); `\n` is the only hard
  break; other characters (incl. `\r`) are ordinary.
- No whitespace is ever collapsed, dropped or reordered — every code
  unit is consumed into a line or left to overflow, so the conservation
  invariant (`rendered + overflow == story.length`) holds exactly.
- A wrapped line never starts with whitespace: a whitespace run at a
  line end is consumed in full (even when only part of the run fits the
  width).
- Words are never broken mid-word when a boundary fits (break at the
  last qualifying whitespace within the fit count).
- Long unbreakable tokens: character split at exactly the provider's fit
  count — the only mid-word break.
- A newline at the cursor consumes one line that renders empty (trailing
  or consecutive newlines are explicit empty lines, never dropped).
- Degenerate width (fit == 0) keeps the forced one-char progress
  guarantee.

## Stage 4 — App integration (`apps/ggen_app`)

The Stage-4 branch wires the verified core substrate into the Flutter
shell. No core flow/link code was changed and no second link
representation was introduced.

### 4.1 — Controller (`studio_controller.dart`)

- `linkTextFrames(source, target)`: persists `target` under the
  `nextFrame` extension of the SOURCE node (the Stage-2 contract) and
  commits ONE undoable `ProjectToolSession`/`ProjectTransaction`.
  Fail-closed: missing/wrong-kind nodes, frames without a rectangle
  (legacy labels) and no-ops return false without a revision;
  self-links, cycles of any length and ambiguous targets (two
  predecessors) throw `ArgumentError` after core
  `TextFlowLinkResolver.resolve` validation and before any mutation.
  Re-linking a source replaces its successor (one validated step).
- `unlinkTextFrame(source)`: removes the `nextFrame` key; one undoable
  step; no-op returns false.
- `deleteNodes` prunes `nextFrame` references that would dangle after a
  delete, so the link graph is well-formed after every deletion (one
  transaction, no partial graph mutation).

### 4.2 — Linked rendering (`src/text_flow/linked_text_flow.dart`,
`studio_canvas.dart`)

- `computeLinkedTextFlow(artboard)` resolves the artboard's chains and
  flows each multi-frame chain as ONE story (concatenated `text`
  extensions in flow order) through the existing `TextFlowEngine`.
  Each frame renders ONLY its assigned column slices — the story is
  never duplicated across frames (conservation holds exactly).
- The chain's font size is the FIRST frame's size (the engine takes one
  size per flow call; per-frame sizes are a documented limitation).
- Fail-closed fallbacks: malformed link structure (dangling target,
  non-string value, non-text node declaring the key) → every frame
  renders through the legacy standalone path; a chain containing a
  frame without geometry/text/size → that chain renders standalone.
- Indicators (`ColumnGuidesPainter`): a full frame whose story
  continues shows a BLUE right-pointing tab (continuation, not
  overflow); the RED corner tab is withheld from continuing frames and
  appears exactly once per chain, on the terminal frame, via
  `TextFlowChain.terminalOverflowFrame`. Isolated frames keep the
  exact previous behavior.
- Frames in a multi-frame chain always render their guide overlay so
  the indicators are visible without selection.

### 4.3 — Page-aware frame creation

The artboard is the page for this milestone: `artboardAsPage`
expresses it as a zero-margin, zero-bleed `PageGeometry`, and
`addTextNode` now places the frame so it fits ENTIRELY inside the page
content bounds (`clampFrameIntoPage`) — the same placement contract as
shape nodes. A dedicated page UI (margins/bleed) remains a later
milestone; the page contract stays in core.

### 4.4 — Persistence

`nextFrame` is a plain extension string, so the existing `ProjectCodec`
round-trips it unchanged (core codec tests) and `save`/`restore`
preserve links (app controller tests). Legacy documents without link
metadata decode and render exactly as before. No schema migration.

### 4.5 — Minimal UI

- Wide inspector: a "Text flow" section — link-candidate buttons
  (deterministic `linkCandidates`: other rect-carrying text frames with
  no predecessor and not upstream of the source) or, when linked,
  "Flows into: …" + Unlink. The inspector content is scrollable so the
  text-frame panel cannot overflow compact windows.
- Compact mobile Columns sheet: the same section, live-updating (the
  sheet listens to the controller), so link/unlink state reflects the
  project without reopening.
- Invalid operations surface the fail-closed `ArgumentError` message in
  a SnackBar; nothing is mutated.

## Verification

- Core: `dart format` clean, `dart analyze --fatal-infos` clean,
  `dart test` **143/143** on Dart 3.13.0 (the exact CI SDK), run locally
  in the SKB brain VM (pure-Dart core only) and on GitHub Actions for
  the PRs.
- App: `flutter analyze` (no new findings beyond pre-existing ones) and
  `flutter test` **237/237** on Flutter 3.47.0 (the exact CI pin), run
  locally with the same toolchain CI installs; GitHub Actions re-runs
  the suite on the PRs.
- No device validation has been performed; none is claimed. A debug
  APK (the only artifact `android-build.yml` produces) is built as a
  device-validation candidate for the Redmi Turbo 4 Pro.

## Deliberately not done (next)

- Physical-device validation of the linked flow (link/unlink,
  continuation/overflow indicators, 2-/3-column layouts, gutter,
  undo/redo, save/reload, interaction) — a separate milestone on the
  Redmi Turbo 4 Pro with the built APK.
- `TextStory` first-class persistence — a separate schema/migration
  milestone.
- Per-frame font sizes within a chain (the chain flows at the head
  frame's size until the engine supports per-frame sizing).
- A dedicated page UI (margins/bleed controls, page origin/placement) —
  the core `PageGeometry` contract is in place; the app treats the
  artboard as a zero-margin page.
