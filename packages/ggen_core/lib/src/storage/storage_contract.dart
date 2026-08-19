import '../document/document_model.dart';
import '../project/project_contract.dart';

/// Opaque stable storage key. Domain code never receives a platform path.
final class ProjectStorageKey {
  ProjectStorageKey(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.length > 128 ||
        !RegExp(r'^[a-z][a-z0-9_.-]{0,127}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'value',
        'Storage keys must be lowercase stable identifiers.',
      );
    }
    return normalized;
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectStorageKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class ProjectStoreReceipt {
  ProjectStoreReceipt({
    required this.key,
    required this.projectId,
    required this.committedRevision,
    required String contentSha256,
    required this.byteSize,
  }) : contentSha256 = _sha256(contentSha256) {
    if (committedRevision < 0) {
      throw ArgumentError.value(
        committedRevision,
        'committedRevision',
        'Committed revision cannot be negative.',
      );
    }
    if (byteSize < 1) {
      throw ArgumentError.value(
        byteSize,
        'byteSize',
        'A committed project must contain at least one byte.',
      );
    }
  }

  final ProjectStorageKey key;
  final GgenId projectId;
  final int committedRevision;
  final String contentSha256;
  final int byteSize;
}

/// A staged write is committed atomically by the platform adapter.
abstract interface class ProjectStoreTransaction {
  ProjectStorageKey get key;

  Future<void> stage(ProjectEnvelope envelope);

  Future<ProjectStoreReceipt> commit();

  Future<void> cancel();
}

/// Transactional project persistence interface with no filesystem dependency.
abstract interface class TransactionalProjectStore {
  Future<ProjectEnvelope?> read(ProjectStorageKey key);

  Future<ProjectStoreTransaction> begin(
    ProjectStorageKey key, {
    int? expectedRevision,
  });
}

String _sha256(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'contentSha256',
      'Content digest must be a 64-character lowercase SHA-256 value.',
    );
  }
  return value;
}
