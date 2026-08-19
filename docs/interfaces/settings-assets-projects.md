# Settings, assets, projects, history

- Settings are typed, versioned, validated, scoped (global/workspace/project/tool/provider/model), migratable, exportable with secrets excluded, and atomically persisted.
- Credentials are referenced by opaque secure-store IDs; never serialized in project/settings export.
- Asset records contain digest, MIME/format, dimensions/contract, tags/folders/favorites, provenance/license, versions, duplicates, preview derivation, and protected state.
- Native project package separates canonical model, content-addressed assets, previews/caches, history/checkpoints, plugin requirements, and provenance.
- Undo/redo uses reversible commands or snapshots with memory/disk budgets; autosave journal is crash-recoverable and never overwrites the last known-good project.
