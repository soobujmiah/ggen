# AI assistant working agreement

This file is mandatory reading for every AI assistant before it changes GGEN. GitHub is the canonical memory and source of truth; a local workspace is disposable. Model chat history is not authoritative project memory.

## Session continuity and handoff

AI assistants are interchangeable implementers. A new model MUST be able to continue from repository evidence without relying on the previous model's hidden or conversational context.

### Start every engineering session

1. Read this file first, then the required reading order below.
2. Inspect the current `main` HEAD and recent commits.
3. Read the current phase/status and relevant architecture/source/test files.
4. Read the latest current handoff/status document when one exists.
5. Treat repository state, tests, CI evidence, device evidence and documented handoff as the source of truth. Verify previous-agent claims instead of inheriting them blindly.
6. Before implementation, state a session contract: exact milestone, current HEAD, direct evidence, files/docs expected to change, tests/checks required, physical-device validation required, and deliberately deferred work.

### End every engineering session or completed milestone

Perform a **session close** before handing work to another model:

1. Inspect `git status` and `git diff`; review every changed file.
2. Run all relevant available tests/checks. Never claim green without actual output.
3. Update relevant documentation and phase/status files.
4. Record important evidence, failures, fixes, known defects, deferred work, and exact reproduction/verification steps.
5. Maintain/update a concise current handoff containing: current HEAD, completed work, known defects, latest verified evidence, tests and results, pending device validation, next recommended milestone, and deliberately deferred scope.
6. Commit completed work with a clear conventional message and push when authorized by the workflow.
7. Record the resulting commit SHA and verification status for substantial milestones.
8. Leave no unexplained dirty changes. If work is intentionally uncommitted, document exactly why and what remains.

### Model-switch / risky-change recovery

Before a risky, large, or model-switching operation, create a named Git snapshot branch from the exact known-good HEAD, for example `snapshot/YYYY-MM-DD-pre-model-switch`. Do not rewrite or force-push history merely to create a snapshot. A snapshot is a recovery point, not permission to skip tests or documentation.

When switching models, the new model MUST first read the current HEAD, relevant handoff, this AI agreement, the specification, phase status and latest evidence before implementing anything. It must not continue from conversational memory alone.

## Required reading order

1. `AI_ASSISTANT.md`
2. `MASTER_SPEC.md`
3. `README.md`
4. `docs/product/computer-quality-tool-standard.md`
5. `docs/design/mobile-first-professional-ui.md`
6. `config/development-environments.yaml`
7. `config/tool-quality-standard.yaml`
8. `config/toolchain.yaml`
9. `docs/legal/licensing-policy.md` and `docs/audit/licensing-register.md`
10. `docs/security/import-and-resource-policy.md`
11. `docs/phases/phase-0-status.md` and `docs/phases/phase-1-status.md`
12. The relevant architecture documents
13. The existing source and tests for the requested package

Read BG and RGEN only as read-only capability, security, provenance and testing references. Never modify, commit to, push to, or open a pull request against them.

## Repository boundary

- `soobujmiah/ggen` is the public Apache-2.0 source repository.
- `soobujmiah/ggen-protected-assets` is the private asset vault. Its history and restricted bytes must remain private.
- The public repository contains registry metadata and abstract asset IDs only. It must not contain protected font, signature, logo, seal, template, OCR/model, APK/AAB or credential bytes.
- Protected features remain unavailable until an owner-supplied pack passes the exact public registry size and SHA-256 checks. The public build must work without that pack and must never download it automatically.

## Before implementation, state

- the exact requested milestone;
- current implementation status and direct evidence;
- documentation that needs updating;
- tests to add or update;
- work deliberately deferred;
- whether Redmi Turbo 4 Pro physical testing is required.

Prefer a small, complete, testable platform-neutral contract over demo buttons. Manual operation is mandatory; AI is optional. Computer-quality semantics and mobile-friendly interaction are both mandatory. Do not copy BG, RGEN, Blender, FontForge, Photoshop, PicsArt, Illustrator, Infinite Design or Infinite Painter UI, branding, colors, typography identity, icons, layout or navigation.

## Secure GitHub workflow

Use the authenticated GitHub CLI, a secure credential helper, or an authorized SSH key. Never put a PAT in a URL, shell history, commit, Git configuration, issue, log or documentation. Never echo credentials. Keep BG and RGEN read-only. After a completed unit, run its checks, commit with a clear conventional message, push, and record the exact verification result. The public split is the one exception: local fresh public history must be scanned completely before the first public repository is created or pushed.

## Claims and evidence

Build, test, emulator, physical completion, backend verified and benchmarked are separate states. Never infer GPU/NPU execution from API availability or delegate construction. A Redmi claim requires the exact artifact, device/build identity and raw output/log evidence. GitHub Actions billing or spending-limit failures are account failures, not source-code failures.

## After implementation

Run all available dependency-free checks and the pinned package checks when the toolchain is present. Update relevant documentation and phase status. Commit and push. Provide exact Redmi commands for any device-required validation, record unknowns honestly, and never claim device verification without device output.
