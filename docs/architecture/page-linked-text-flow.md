# Page geometry & linked text flow (core foundation)

**Status:** implemented in `ggen_core` on 2026-08-24 (feature branch
`feat/page-linked-text-flow`, Stages 1–3 of the page-linked text-flow
milestone). Pure Dart; core suite 141/141 verified locally with the exact
CI toolchain (Dart 3.13.0) and by GitHub Actions on the PR. **Not yet
exercised in the Flutter shell (Stage 4) and not physical-device
validated.**

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

## Verification

- Core: `dart format` clean, `dart analyze --fatal-infos` clean,
  `dart test` **141/141** on Dart 3.13.0 (the exact CI SDK), run locally
  in the SKB brain VM (pure-Dart core only) and on GitHub Actions for
  the PR.
- App suite (Flutter, 198 tests) must be CI-verified on the PR: Stage 3
  changes wrapping semantics for whitespace-containing text; any app
  widget test pinning old mid-word splits must be reviewed, not
  silently rewritten.
- No device validation has been performed; none is claimed.

## Deliberately not done (next)

- **Stage 4 (app integration, not started):** controller link/unlink
  (atomic, one undoable `ProjectToolSession`/`ProjectTransaction` per
  operation, fail closed, no partial graph mutation), linked-frame chain
  resolution in the canvas, rendering slices across linked frames,
  continuation/overflow indicators (using
  `terminalOverflowFrame`), persistence round-trip of `nextFrame`,
  page-aware frame creation, legacy behavior preservation.
- Physical-device validation (2-/3-column layouts, gutter, undo/redo,
  save/reload, overflow, linked-frame rendering, interaction) — a
  separate milestone on the Redmi Turbo 4 Pro.
- `TextStory` first-class persistence — a separate schema/migration
  milestone.
- Page origin/placement on the artboard (Stage 4 concern).
