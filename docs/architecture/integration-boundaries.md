# BG/RGEN integration and migration boundaries

## BG

Phase 3 adapter may reimplement/adapt image algorithms against GGEN interfaces after model provenance and tests are established. No source is copied automatically. Existing BG settings, delegate helper, performance logger, storage, navigation, and UI are explicitly excluded.

## RGEN

Phase 4 has two paths:

1. `RgenProtectedAdapter`: reads verified immutable production assets and maps fixed document contracts into UDM/render jobs.
2. `RgenCompatibilityImporter`: bounded parser for approved package/schema versions with canonical paths and migration preview.

RGEN UI/editor/storage/archive code is not imported. Layout values may be recorded as versioned document contracts where needed to reproduce owner-approved production documents. Any code reuse requires explicit license/provenance review and targeted port justification.

## No silent migration

Original protected bytes remain intact. Derived previews, indexes, or converted working copies live outside `protected/` with source digest and derivation recipe. Users see fidelity differences before accepting format conversion.
