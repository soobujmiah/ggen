# Tool sessions and adaptive input

## Tool sessions

`ProjectToolSession` captures an immutable project snapshot and keeps edits in preview state. Preview updates must preserve the project ID and input revision. `commit()` converts the final preview into exactly one `ProjectTransaction` with the next revision. `cancel()` restores the exact input snapshot and does not create history. A committed session cannot be edited or cancelled; cancellation is idempotent.

This contract lets a phone gesture, stylus stroke, mouse drag, keyboard command, command palette action, workflow node or future plugin use the same reversible semantics. It is not a graphics implementation and does not run work on the UI thread.

## Adaptive input

`AdaptiveInputContract` declares available touch, stylus, mouse and keyboard capabilities, axes actually reported by the platform, numeric-inspector availability, command-palette availability and discoverable command alternatives. Pressure and tilt axes require a reported stylus capability; a tool may not synthesize them.

`NormalizedInputEvent` carries finite coordinates, timestamp, buttons and optional reported axes. Supplying pressure, tilt, azimuth, rotation or velocity that the capability contract does not report fails closed. This preserves the distinction between a real device signal and a guessed default while keeping the domain independent of Android pointer APIs.

Every gesture still has an accessible command alternative. The same precision data model is therefore reachable from compact touch UI, tablet panels, mouse/keyboard, command palette and plugins.
