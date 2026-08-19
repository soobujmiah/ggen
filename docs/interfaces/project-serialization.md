# Project serialization and schema migration

Phase 1 uses a deterministic JSON envelope for the platform-neutral project model. The codec is an adapter around immutable domain values; it does not access files, URIs, Android storage or network services.

## Envelope

The current format identifier is `ggen.project`. A serialized envelope contains:

- `format`;
- `schemaVersion` at the envelope and project level;
- project ID, name, revision and ordered artboards;
- artboard ID/name/dimensions and ordered nodes;
- node ID, stable kind name, visibility/lock/opacity and JSON-safe extension data;
- envelope extension data.

Node kinds use explicit stable wire names rather than Dart enum names. Extension maps are recursively canonicalized with lexicographically sorted string keys. The same project and extension values therefore produce the same compact JSON bytes independent of map insertion order.

## Bounds and failure behavior

`ProjectCodecLimits` requires finite limits for JSON bytes, artboards, nodes, collections, nesting depth and string length. The codec rejects non-finite numbers, non-string map keys, unsupported values, oversized collections/strings, unknown fields, unknown node kinds, mismatched schema versions and malformed JSON. It rejects a write unless the envelope is on the current schema.

The initial conservative limits are policy defaults for contract testing, not performance claims. Phase 1 measurements must establish product defaults before a release profile is published.

## Migration policy

`ProjectSchemaReadPolicy` distinguishes `current`, `migrationRequired` and `unsupported`. Old or future versions are never silently interpreted as the current model. A version marked for migration fails with an explicit migration-required state until a tested, versioned migration is registered. A version outside the policy fails as unsupported. No migration code is currently admitted, so schema v1 is the only readable/writable format at this milestone.

Round-trip tests, canonical-order tests, malformed-input tests and bounded-resource tests are part of `ggen_core`. Serialization success is not a Flutter, Android, storage, crash-recovery or device-verification claim.
