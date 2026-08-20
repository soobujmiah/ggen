import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ggen_core/ggen_core.dart';

/// File-backed [TransactionalProjectStore].
///
/// Layout under [root]:
///   `<root>/projects/<key>.ggen`
///
/// Keys are validated stable identifiers (`[a-z][a-z0-9_.-]{0,127}`), so the
/// file name cannot escape the projects directory. Writes are atomic: the
/// canonical JSON is written to a sibling temp file and renamed over the
/// target, so a crash never leaves a partially written project file.
///
/// This adapter is pure Dart and takes the root directory explicitly; the
/// shell resolves the platform directory (path_provider) and passes it in,
/// which keeps the adapter fully unit-testable without plugins.
final class FileProjectStore implements TransactionalProjectStore {
  FileProjectStore(Directory root) : projectsDir = _ensureDir(root, 'projects');

  static const String fileExtension = '.ggen';

  final Directory projectsDir;
  final ProjectCodec _codec = ProjectCodec(
    limits: ProjectCodecLimits.conservative(),
  );
  ProjectStorageKey? _lastCommittedKey;

  File _fileFor(ProjectStorageKey key) => File(
    '${projectsDir.path}${Platform.pathSeparator}${key.value}$fileExtension',
  );

  ProjectEnvelope? _read(ProjectStorageKey key) {
    final file = _fileFor(key);
    if (!file.existsSync()) return null;
    final text = file.readAsStringSync();
    try {
      return _codec.decode(text);
    } on FormatException catch (error) {
      throw FormatException(
        'Stored project "${key.value}" is corrupt: ${error.message}',
      );
    }
  }

  int _storedRevision(ProjectStorageKey key) =>
      _read(key)?.project.revision ?? -1;

  /// Most recently committed envelope across all keys.
  ProjectEnvelope? latest() {
    final key = _lastCommittedKey;
    return key == null ? null : _read(key);
  }

  @override
  Future<ProjectEnvelope?> read(ProjectStorageKey key) async => _read(key);

  @override
  Future<ProjectStoreTransaction> begin(
    ProjectStorageKey key, {
    int? expectedRevision,
  }) async {
    final stored = _storedRevision(key);
    if (expectedRevision != null && expectedRevision != stored) {
      throw StateError(
        'Stale storage transaction: key "${key.value}" is at revision '
        '$stored, expected $expectedRevision.',
      );
    }
    return _FileStoreTransaction(this, key, storedRevision: stored);
  }

  void _commitEnvelope(ProjectStorageKey key, ProjectEnvelope envelope) {
    _lastCommittedKey = key;
  }

  static Directory _ensureDir(Directory root, String name) {
    final dir = Directory('${root.path}${Platform.pathSeparator}$name')
      ..createSync(recursive: true);
    return dir;
  }
}

final class _FileStoreTransaction implements ProjectStoreTransaction {
  _FileStoreTransaction(this._store, this.key, {required this.storedRevision});

  final FileProjectStore _store;
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
    // First write to a key accepts any valid revision; later writes may
    // only re-save the stored revision or advance it by exactly one.
    if (storedRevision >= 0 &&
        revision != storedRevision &&
        revision != storedRevision + 1) {
      throw StateError(
        'Staged revision $revision does not advance stored revision '
        '$storedRevision for "${key.value}".',
      );
    }
    final json = _store._codec.encode(envelope);
    final bytes = utf8.encode(json);

    final target = _store._fileFor(key);
    final tmpPath = '${target.path}.tmp';
    await File(tmpPath).writeAsBytes(bytes, flush: true);
    await File(tmpPath).rename(target.path);

    _store._commitEnvelope(key, envelope);
    _finished = true;
    return ProjectStoreReceipt(
      key: key,
      projectId: envelope.project.id,
      committedRevision: revision,
      contentSha256: sha256.convert(bytes).toString(),
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
