# Project persistence, jobs and recovery contracts

Phase 1 keeps persistence and heavy work behind platform-neutral contracts.

## Project and storage

`ProjectSchemaVersion` bounds and identifies the serialized schema. `ProjectEnvelope` pairs that version with an immutable `DocumentProject` and rejects mismatches. `ProjectStorageKey` is an opaque stable identifier; no domain type accepts a filesystem path.

`TransactionalProjectStore` exposes read and begin-transaction operations. `ProjectStoreTransaction` stages an envelope, commits atomically, or cancels. `ProjectStoreReceipt` records the project ID, committed revision, byte count and content SHA-256. Android SAF, app-private files, cloud sync or another adapter may implement the interface without changing the domain model.

## Resource-bounded jobs

Every `JobSnapshot` carries a finite `ResourceBudget`, bounded progress phase and explicit state transition. Queued, admitted, running, pausing, paused, cancelling, terminal and recovery-required states are distinct. Progress cannot move backwards, completed jobs must reach one hundred percent, and failure/recovery states require a bounded non-secret failure code. `ResourceBoundedJobRuntime` is an adapter boundary; it does not imply a worker or backend exists.

## Autosave and recovery

`AutosavePolicy` bounds journal entries, bytes and checkpoint frequency. `RecoveryJournalRecord` records project/revision range, sequence, payload digest and size. `AutosaveRecoveryJournal` appends, streams and marks replayed records; an implementation must make append/replay idempotent and must not overwrite the last known-good project on a partial write.

These contracts do not perform I/O, spawn workers or claim crash recovery until a platform adapter and its tests provide evidence.
