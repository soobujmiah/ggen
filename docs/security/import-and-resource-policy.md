# Import and resource security policy

## Default posture

All imported archives, documents, images, fonts, spreadsheets, models, plugins, workflows, and project packages are untrusted.

## Required pipeline

Picker/URI → read-only staged source → bounded type probe → canonical manifest validation → resource estimate → policy/admission → sandboxed parser/worker → validated domain object → transactional commit.

## Limits

Every format defines hard configurable maxima and lower preview limits for: source bytes, entries, total uncompressed bytes, compression ratio, nesting, pages/artboards/elements, image pixels/dimensions/frames, PDF objects/streams/decompression, font tables/glyphs/bytes, rows/columns/cell length/formulas, model tensors/operators/bytes, workflow nodes/fan-out, and generated outputs.

Exact numeric defaults require measurements during Phase 1 and become versioned policy. “Unlimited” is forbidden.

## Paths

Archive/manifest paths must be normalized relative names. Reject absolute paths, drive/UNC forms, empty/dot/dot-dot components, encoded traversal, NUL/control characters, symlinks/hardlinks, and canonical targets outside the staging root.

## Memory/disk

Admission reserves estimated peak memory and disk with safety margin. Streaming is preferred. Batch archives are written incrementally to disk. Disk-full/cancel/crash cleanup is idempotent; partial artifacts are marked and never presented as complete.

## Related

See also: `docs/security/threat-model.md` and ADR-0005 (plugin trust model).

## Android storage

Use SAF/MediaStore/app-private storage and persistable URI grants. Do not request `MANAGE_EXTERNAL_STORAGE` for normal operation. Cloud/endpoint content transfer requires policy and user-visible disclosure.
