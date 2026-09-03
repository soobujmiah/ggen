# AI assistant working agreement

This file is mandatory reading for every AI assistant before it changes GGEN. GitHub is the canonical memory and source of truth; a local workspace is disposable. Model chat history is not authoritative project memory.

## Local vs. cloud execution

Only the build/compile step (Flutter/Gradle/native builds, CI) belongs on GitHub Actions by default — that is a **device-health policy choice** (avoiding sustained CPU/thermal/battery/storage load on Sobuj's phone), not a missing local toolchain: his Termux/PRoot environment has a real local ARM64 native Android toolchain (see `soobujmiah/adt`), so a local build is technically possible when specifically needed. Everything else in the loop is local, on the phone/PRoot + ADB setup: downloading a CI artifact, installing it, launching/running it, using the feature under test, reading logs (logcat/stdout/stderr/crash traces), debugging an observed failure, and fixing the source. That local setup is also Sobuj's actual repo workstation — clone/edit/branch/commit happen there directly. Full policy: `soobujmiah/skb` → `engineering/HEAVY_BUILD_AND_ARTIFACT_WORKFLOW.md`.

## Android device testing

ADB-first is the default methodology for any real-device interaction — see
`docs/ADB_FIRST_TESTING.md` and `soobujmiah/skb` → `standards/agent-device-testing.md` for the
full priority order (app-native intents/interfaces → ADB → instrumentation → UIAutomator →
coordinate taps, last resort) and `soobujmiah/lai`'s `scripts/device/lai_adb.sh` for the
reusable helper shape. Never poll with an arbitrary sleep; wait on an observable condition
(process state, activity draw completion, a specific logcat pattern) instead, and read logs
through a tag/regex filter, not a raw dump.

## SKB knowledge continuity

This repository is connected to Sobuj's canonical knowledge base: `soobujmiah/skb`.

Before any non-trivial decision, follow: repository instructions → `soobujmiah/skb` → `AGENT_NAVIGATION.md` → minimum relevant context → live repository evidence.

A user does not need to repeat “read SKB” on later sessions for this repository. If SKB is unavailable, do not invent missing context; continue only from verified local evidence when safe.

At session close, perform a Knowledge Return Review: identify durable project facts, decisions, architecture changes, capabilities, failures, constraints, or evidence that may need to be recorded/updated in SKB. Never return secrets, private payloads, routine noise, or unsupported claims. SKB recommendations never override repository evidence or human authority.

See `SKB_KNOWLEDGE_CONTINUITY.md` for the project-local contract.

## Session continuity and handoff

AI assistants are interchangeable implementers. A new model MUST be able to continue from repository evidence without relying on previous conversation context.

### Start every engineering session

1. Read this file and `SKB_KNOWLEDGE_CONTINUITY.md`.
2. Inspect the current `main` HEAD and recent commits.
3. Read the current phase/status and relevant architecture/source/test files.
4. Read the latest current handoff/status document when one exists.
5. Verify previous-agent claims against direct evidence.
6. Before implementation, state the exact milestone, current HEAD, evidence, files/docs expected to change, tests/checks, physical-device validation if relevant, and deliberately deferred work.

### End every engineering session or completed milestone

1. Inspect `git status` and `git diff`; review every changed file.
2. Run relevant tests/checks and record actual output.
3. Update relevant documentation and phase/status files.
4. Record evidence, failures, known defects, deferred work, and reproduction/verification steps.
5. Perform the SKB Knowledge Return Review.
6. Commit and push only when authorized by the applicable workflow — once authorized and the change is validated, push it right away rather than leaving it staged/unpushed on the single working copy where it could be lost.
7. Record the resulting SHA and verification status for substantial milestones.
8. Leave no unexplained dirty changes.

## Adaptive engineering rule

Do not use a fixed technology or documentation template merely because another project used it. Select the appropriate language, framework, architecture, repository structure, documentation, dependencies, testing strategy, and validation method from the actual task and constraints. Reuse proven conventions where applicable, but justify material choices.

## Existing GGEN rules

Preserve all existing GGEN source, security, protected-asset, evidence, licensing, and repository-boundary rules. Do not copy BG, RGEN, protected assets, credentials, private bytes, or proprietary material. Keep claims tied to direct evidence.
