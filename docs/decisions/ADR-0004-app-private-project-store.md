# ADR-0004 — App-private project store with deferred SAF export

**Status:** Accepted by owner, 2026-08-20

## Context

Phase 0 left the platform storage approach open. GGEN must persist projects
(transactional store, recovery journal, autosave, last-project restore)
without broad all-files permission. The core `TransactionalProjectStore` and
`AutosaveRecoveryJournal` contracts are platform-neutral; the app layer needs
a concrete platform storage decision to implement the durable adapters.

## Decision

- The **internal project store and recovery journal live in the app-private
  documents directory** (resolved with `path_provider`), with the canonical
  `ggen.project` JSON written per project as `<key>.ggen` files.
- Writes are atomic (temp file + rename) and keyed by validated stable
  identifiers; no platform paths ever enter the domain layer.
- The **recovery journal is a line-oriented JSON log** per project under a
  journal subdirectory, bounded by the journal policy (entry count and byte
  budget), with the canonical payload durably associated to each record so
  replay can reconstruct projects.
- The in-memory adapters remain the default for tests and as a fully
  functional fallback when the platform plugin is unavailable.
- **SAF/MediaStore is explicitly deferred** to the user-facing Import/Export
  milestone. The internal store is not user-browsable; user-visible file
  operations (export a `.ggen` project, import from Downloads) will use the
  Storage Access Framework so the user always chooses the destination, and
  the app never requests broad storage permissions.

## Consequences

- No storage permission is required for normal operation.
- `path_provider` (and its platform plugins) becomes a direct app dependency;
  provenance receipts were added to `config/provenance/dependencies.json`
  and remain subject to independent license review like all other packages.
- The `.ggen` extension is the canonical project file format (the existing
  `ggen.project` JSON codec), reused by the future SAF export.
- Restore on startup, autosave, journal replay and undo/redo journaling all
  work against the private store without user interaction.
- SAF export requires its own milestone: share-sheet/SAF picker flow,
  progress/cancellation, and tests; it is not part of this decision's
  implementation.
