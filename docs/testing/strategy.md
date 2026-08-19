# Testing strategy

## Layers

1. Pure domain/property tests: geometry, commands, UDM round-trip, settings, schemas, router, workflow.
2. Golden tests: raster/vector/PDF/SVG and fidelity reports with controlled renderer versions.
3. Contract suites: every importer/exporter/provider/backend/plugin runs the same boundary cases.
4. Security corpus: traversal, zip bombs, malformed PDFs/images/fonts/models/spreadsheets, schema/version abuse.
5. Job/recovery tests: cancel at every phase, disk full, process death, partial commit, resume, duplicate execution.
6. Flutter interaction/accessibility/golden tests with original design.
7. Android instrumentation: SAF, Keystore, WorkManager, memory pressure, rotation, background restrictions.
8. Physical device: backend verification, thermals, memory, latency, canvas frame budget, stylus/touch.

## Claims

Implementation, build, emulator, physical completion, backend verified, and benchmarked are separate states. A release claim links to exact commit, artifact hash, device/build, raw evidence, and limitation.

## Reference regression migration

Recreate functional contracts from BG/RGEN knowledge; do not copy UI tests. Protected RGEN templates receive byte-hash tests and output-layout tests without altering originals.
