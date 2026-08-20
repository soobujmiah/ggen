# Phase 0 status

## Completed

- [x] Public GGEN source repository and separate private protected-asset vault staged.
- [x] Master specification recorded.
- [x] BG deep audit/capability inventory and unsafe lessons recorded.
- [x] RGEN deep audit/capability inventory and unsafe lessons recorded.
- [x] All 30 owner-selected current RGEN assets preserved only in the private protected-asset vault; the public repository contains registry metadata without bytes.
- [x] Exact size/SHA-256/source-commit manifests generated.
- [x] Protected-pack mutation verifier defined; public checks verify the registry boundary without requiring private bytes.
- [x] Licensing/provenance register created with unresolved assets blocked from public distribution.
- [x] Android-first Flutter ADR recorded.
- [x] High-level modular architecture/dependency rules created.
- [x] UDM, image, import/export, protected assets, AI router/evidence, jobs/workflows/plugins/settings contracts sketched.
- [x] Import/resource/privacy policy defined.
- [x] Testing and physical-device evidence strategy defined.
- [x] BG/RGEN integration boundaries defined.
- [x] Original UI/UX non-copy boundary defined.
- [x] GitHub-centric hybrid brain accepted and recorded in ADR-0002.
- [x] Current Arena orchestration machine inspected and recorded in environment YAML.
- [x] Full font-creation/typography studio scope and architecture documented.
- [x] Full professional 3D DCC roadmap and native-engine boundary documented.

## Open Phase 0 decisions before application implementation

- [ ] Owner approves final product subtitle/brand direction/logo process; GGEN name is repository/product working name.
- [ ] Resolve whether desktop is a later Flutter target or a separate shell.
- [ ] Approve numerical default resource limits after test corpus measurements.
- [ ] Complete licenses/provenance for Lucida, Noto, tessdata, templates, emblems/seals, signatures.
- [ ] Decide the owner-approved private-pack build profile; public artifacts must always omit blocked bytes.
- [ ] Select production signing/secret custody strategy.
- [ ] Define initial Phase 1 vertical slice and explicit non-goals.
- [x] Create threat model and plugin trust model ADR.
- [ ] Define UDM schema v1 in sufficient detail for implementation.
- [x] Establish Flutter/Dart/Android SDK exact pins and provision Codespaces (pins in `config/toolchain.yaml`; `.devcontainer` present; CI uses the exact Flutter 3.47.0 / Dart 3.13.0 pin).
- [ ] Select the native 3D engine language/render abstraction after a measured feasibility spike; do not lock from marketing claims.
- [ ] Select and pin the typography/font shaping/compiler stack and independent validators.
- [ ] Define GitHub issue/project/release templates and offline repository continuity backup.

## CI operational status

The Phase 0 governance checks passed at the private-vault head; the fresh public repository adds independent licensing and public-safety checks. Historical GitHub run `32250437292` did not start because the account reported failed payments or an insufficient spending limit; that was an account/billing failure, not a protected-asset or documentation test failure. Public governance run `32258736289` for commit `1760880d8b65f93b8d677645e5619b35d074a0bc` completed successfully, including the reusable core test. Continue recording any future billing interruption separately from source results.

## Gate decision

**Accepted for Phase 1 foundation work by owner directive on 2026-08-19.** Computer-quality capability and mobile-friendly UI are mandatory. Acceptance authorizes core contracts, project/history/job/tool foundations and original adaptive shell work; it does not waive unresolved license, security, signing, resource-limit, 3D-engine or distribution decisions.

Protected assets remain immutable. Public distribution remains blocked by the licensing register. Major feature studios must still follow their documented phase gates.
