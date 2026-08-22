# GGEN

**AI Creative & Document Studio — public documentation-first foundation**

GGEN is an Android-first, platform-neutral creative and document foundation intended to grow into a professional manual vector, raster, painting, font, 3D, document and PDF environment with optional local/cloud/custom AI. The public source is independently designed and does not copy BG, RGEN or competitor UI, UX, branding or visual identity.

## Repository boundary

- **Public source:** [`soobujmiah/ggen`](https://github.com/soobujmiah/ggen), fresh Git history, Apache-2.0 for GGEN-owned source and documentation.
- **Private vault:** [`soobujmiah/ggen-protected-assets`](https://github.com/soobujmiah/ggen-protected-assets), private owner-controlled history and restricted RGEN asset bytes.
- **Read-only references:** [`bg`](https://github.com/soobujmiah/bg) and [`rgen`](https://github.com/soobujmiah/rgen). They must not be modified or treated as GGEN dependencies.

The public repository contains no Lucida or other protected font binaries, signatures, institutional/government marks, protected production templates, OCR/model binaries, APK/AAB files, credentials or private user data. [`config/protected-asset-registry.json`](config/protected-asset-registry.json) contains metadata and SHA-256 receipts only; it is not a license or an asset download.

Protected features report `UNAVAILABLE_NO_PACK` until an owner-supplied pack is explicitly installed and passes exact path, size and SHA-256 verification. The public build and tests remain useful without that pack, and the application never downloads restricted bytes automatically.

## Current status

**Phase 1 core foundation:** implemented in pure Dart under [`packages/ggen_core`](packages/ggen_core). It currently contains validated stable IDs, immutable document values, bounded revision history, professional tool descriptors, typed parameters, quality gates, licensing/provenance, project schema/storage, bounded jobs and recovery-journal contracts, tool sessions, adaptive input and deterministic bounded JSON serialization. It intentionally contains no Flutter UI, protected bytes, provider calls or graphics engine.

**Phase 2 workspace foundation:** the original Flutter shell ([`apps/ggen_app`](apps/ggen_app)) consumes the core through a widget-free app-layer controller (`apps/ggen_app/lib/src/controller/studio_controller.dart`) for project lifecycle, bounded undo/redo, tool sessions, canonical project serialization and transactional persistence with SHA-256 receipts, a bounded recovery journal with undo/redo records and last-project restore on startup. Storage is file-backed in the app documents directory (ADR-0004, atomic `.ggen` writes); SAF/MediaStore import/export is the next storage milestone.

**Phase 2 creative surface:** an original compact-phone canvas shell (`lib/src/canvas/`) with pinch-zoom, pan, a functional Draw tool (tap to place a shape through an undoable core tool session) and live undo/redo + object count; responsive layouts, immersive canvas, persistent workspace settings, dockable inspector, named profiles and bounded diagnostics. See [`docs/phases/phase-2-status.md`](docs/phases/phase-2-status.md) for scope and evidence boundaries.

**Verification:** the app builds as a manual Android debug APK (`ggen-debug-apk`, Android debug build workflow); behavior is validated by widget tests in CI and by user-provided Redmi Turbo 4 Pro diagnostics recorded in `docs/phases/phase-2-status.md`. No production release, GPU/NPU execution, performance or persistence-across-reinstall claim is made. The Redmi Turbo 4 Pro is the authoritative device for Android evidence.

## Read first

1. [`AI_ASSISTANT.md`](AI_ASSISTANT.md) — the AI working agreement (session start/close contract, evidence rules)
2. [`CURRENT_STATE.md`](CURRENT_STATE.md) — the canonical current-state record and session handoff (current phase, verified baseline, evidence boundary, required reading for the next AI)
3. [`MASTER_SPEC.md`](MASTER_SPEC.md)
4. [`docs/product/computer-quality-tool-standard.md`](docs/product/computer-quality-tool-standard.md)
5. [`docs/design/mobile-first-professional-ui.md`](docs/design/mobile-first-professional-ui.md)
6. [`config/development-environments.yaml`](config/development-environments.yaml)
7. [`config/tool-quality-standard.yaml`](config/tool-quality-standard.yaml)
8. [`config/toolchain.yaml`](config/toolchain.yaml)
9. [`docs/legal/licensing-policy.md`](docs/legal/licensing-policy.md)
10. [`docs/security/import-and-resource-policy.md`](docs/security/import-and-resource-policy.md)
11. [`docs/phases/phase-0-status.md`](docs/phases/phase-0-status.md)
12. [`docs/phases/phase-1-status.md`](docs/phases/phase-1-status.md)
13. Relevant architecture, interface, source and test files

> Session continuity: `CURRENT_STATE.md` is the authoritative, up-to-date snapshot; phase/status docs carry the deeper detail and dated evidence. Reconstruct state from these plus repository evidence — never from a previous chat session's claims.

## Non-negotiable boundaries

- Computer-quality capability and mobile-friendly interaction are both mandatory.
- Important operations remain manually usable without AI or network access.
- BG and RGEN are read-only references; their UI, UX, design and branding are not copied.
- Imported files are hostile until bounded, canonicalized and validated.
- Credentials use secure references and never enter projects, settings, logs or documentation.
- Performance, backend, build and device claims require scoped evidence; they are never estimated or fabricated.
- Apache-2.0 does not license third-party dependencies or the private protected asset pack.

## Local checks

Dependency-free governance checks are under [`scripts/`](scripts/). The pinned Dart/Flutter toolchain is described in [`config/toolchain.yaml`](config/toolchain.yaml). If GitHub Actions is blocked by account billing or spending limits, record that as an infrastructure status and do not call the source code failed or green without the relevant output.

- **Governance gate (dependency-free, requires only PyYAML):** `scripts/check_legal_files.py`, `scripts/validate_provenance.py`, `scripts/check_docs.py` (link + secret-pattern check), `scripts/validate_environment_contract.py`, `scripts/verify_protected_pack.py`, `scripts/public_safety_scan.py`, `scripts/check_build_security.py`, `scripts/source_receipt.py`. Run them from the repo root on any documentation/state change.
- **Source receipt:** `scripts/source_receipt.py` prints a reproducible SHA-256 receipt for the current commit (`repository`, `source_commit`, `tree`, `clean_worktree`, `tracked_file_count`, `tracked_path_list_sha256`). It returns non-zero when the worktree is dirty, so a receipt describes a clean, verifiable state. `CURRENT_STATE.md` is the place to note the live HEAD a state snapshot corresponds to; the receipt itself is generated at run time rather than pinned here, so it never ages silently.
- **Auth/secret rule:** never place a personal access token, key, or credential in any URL, commit, doc, issue, log, or documentation. `check_docs.py` and `check_build_security.py` scan for these.
