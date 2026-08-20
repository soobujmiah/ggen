import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ggen_core/ggen_core.dart';

/// In-memory [TransactionalProjectStore] used until a platform storage
/// decision is accepted.
///
/// Semantics match the core contract: writes are staged and committed
/// atomically, receipts carry the canonical content digest and byte size,
/// and a transaction opened with a stale expected revision is rejected.
/// Envelopes are retained for the lifetime of the store (single process).
final class MemoryProjectStore implements TransactionalProjectStore {
  final Map<ProjectStorageKey, ProjectEnvelope> _data =
      <ProjectStorageKey, ProjectEnvelope>{};
  final ProjectCodec _codec = ProjectCodec(
    limits: ProjectCodecLimits.conservative(),
  );
  ProjectStorageKey? _lastCommittedKey;

  /// Stored revision, or -1 when nothing has been committed for [key].
  int _storedRevision(ProjectStorageKey key) =>
      _data[key]?.project.revision ?? -1;

  /// Most recently committed envelope across all keys, used to restore the
  /// last session in this process.
  ProjectEnvelope? latest() {
    final key = _lastCommittedKey;
    return key == null ? null : _data[key];
  }

  @override
  Future<ProjectEnvelope?> read(ProjectStorageKey key) async => _data[key];

  @override
  Future<ProjectStoreTransaction> begin(
    ProjectStorageKey key, {
    int? expectedRevision,
  }) async {
    final stored = _storedRevision(key);
    if (expectedRevision != null && expectedRevision != stored) {
      throw StateError(
        'Stale storage transaction: key "$key" is at revision $stored, '
        'expected $expectedRevision.',
      );
    }
    return _MemoryStoreTransaction(this, key, storedRevision: stored);
  }

  void _commitEnvelope(ProjectStorageKey key, ProjectEnvelope envelope) {
    _data[key] = envelope;
    _lastCommittedKey = key;
  }
}

final class _MemoryStoreTransaction implements ProjectStoreTransaction {
  _MemoryStoreTransaction(
    this._store,
    this.key, {
    required this.storedRevision,
  });

  final MemoryProjectStore _store;
  @override
  final ProjectStorageKey key;
  final int storedRevision;
  ProjectEnvelope? _staged;
  bool _finished = false;

  @override
  Future<void> stage(ProjectEnvelope envelope) async {
    _ensureActive();
    _staged = envelope;
  }

  @override
  Future<ProjectStoreReceipt> commit() async {
    _ensureActive();
    final envelope = _staged;
    if (envelope == null) {
      throw StateError('Nothing staged for "${key.value}".');
    }
    final revision = envelope.project.revision;
    if (revision != storedRevision && revision != storedRevision + 1) {
      throw StateError(
        'Staged revision $revision does not advance stored revision '
        '$storedRevision for "${key.value}".',
      );
    }
    final json = _store._codec.encode(envelope);
    final bytes = utf8.encode(json);
    final digest = sha256.convert(bytes).toString();
    _store._commitEnvelope(key, envelope);
    _finished = true;
    return ProjectStoreReceipt(
      key: key,
      projectId: envelope.project.id,
      committedRevision: revision,
      contentSha256: digest,
      byteSize: bytes.length,
    );
  }

  @override
  Future<void> cancel() async {
    _finished = true;
  }

  void _ensureActive() {
    if (_finished) {
      throw StateError('Storage transaction for "${key.value}" is finished.');
    }
  }
}
