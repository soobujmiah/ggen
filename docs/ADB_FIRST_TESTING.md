# Device testing — human-operated interaction, agent observation (supersedes "ADB-first device testing")

> **SUPERSEDED — HISTORICAL ONLY.** The section that used to sit here restated a four-tier
> autonomous control hierarchy (ADB-first → application-native control → raw `adb shell input` →
> UIAutomator) from `soobujmiah/skb` → `standards/agent-device-testing.md` and presented it as
> current. **All four tiers are superseded.** See `soobujmiah/skb` →
> `operations/decisions/2026-09-21--skb--human-operated-testing-model.md`
> (`DEC-2026-09-21-001`, 2026-09-21). No agent may treat any of them as standing authorization,
> and no differently-named mechanism may accomplish the same prohibited interaction.

## Current model

**The owner performs application interaction. The Supervisor observes, records scoped evidence,
analyzes, diagnoses, and fixes.**

The Supervisor may: launch the application (where the testing standard permits), observe, collect
scoped logs, use `logcat`/`dumpsys`, run permitted diagnostics, verify package/activity/foreground
identity, collect permitted evidence, take gated screenshots, analyze, diagnose, modify project
code, fix, and send builds through GitHub CI.

The Supervisor must **not** autonomously interact with the application UI by any mechanism —
taps, swipes, button presses, key events, text injection, IME/test-IME, ADB keyboard bridges,
UIAutomator, accessibility-driven actions, application-native deterministic controls (intent
extras, debug/test Activities, broadcast or service control surfaces, debug channels),
Intent-driven input, or any equivalent mechanism. The only operative input path is **owner human
interaction** (touch, gestures, buttons, text entry, keyboard).

## Observation and diagnostic practice (retained)

Batch independent ADB commands, wait on an observable readiness condition (`pidof`,
`am start -W`, a specific logcat pattern, a `dumpsys` state) instead of an arbitrary `sleep`,
filter logs to this application's own tags, and prefer programmatic state checks over screenshots
wherever the same fact is available without one. These are observation techniques and remain in
force.

## Reference tooling

`soobujmiah/lai`'s `scripts/device/lai_adb.sh` remains a valid reference for the **observation**
half of device work (install/reset/launch/wait-process/wait-log/logs/state checks). The
app-native qualification path (intent extras on an exported launcher Activity) that
`soobujmiah/lai`'s `docs/TESTING.md` once documented is **superseded** and is not an authorized
agent input path.

## Relationship to `docs/testing/strategy.md`

That document defines this repository's 8 abstract testing layers (unit/golden/contract/
security/job-recovery/Flutter-interaction/Android-instrumentation/physical-device). The
"Android-instrumentation" layer stays valid as **CI automation** (§13 of the governing task: CI
and UI tests are unaffected). The "physical-device" layer now runs on owner interaction: the owner
performs the interaction, the Supervisor observes and collects evidence. Confirm
`apps/ggen_app/android/` produces a real APK and, for observation and identity checks only, what
exported-component surface exists — not as an agent input path.
