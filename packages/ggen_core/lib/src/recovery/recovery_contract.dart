import '../document/document_model.dart';

final class AutosavePolicy {
  AutosavePolicy({
    required this.maxJournalEntries,
    required this.maxJournalBytes,
    required this.checkpointEveryTransactions,
  }) {
    if (maxJournalEntries < 1 || maxJournalEntries > 100000) {
      throw ArgumentError.value(
        maxJournalEntries,
        'maxJournalEntries',
        'Journal entry limit must be in 1..100,000.',
      );
    }
    if (maxJournalBytes < 1 || maxJournalBytes > 1 << 50) {
      throw ArgumentError.value(
        maxJournalBytes,
        'maxJournalBytes',
        'Journal byte limit must be finite and positive.',
      );
    }
    if (checkpointEveryTransactions < 1 ||
        checkpointEveryTransactions > 10000) {
      throw ArgumentError.value(
        checkpointEveryTransactions,
        'checkpointEveryTransactions',
        'Checkpoint frequency must be in 1..10,000.',
      );
    }
  }

  final int maxJournalEntries;
  final int maxJournalBytes;
  final int checkpointEveryTransactions;
}

enum RecoveryRecordKind { transaction, checkpoint, replayMarker }

final class RecoveryJournalRecord {
  RecoveryJournalRecord({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.sequence,
    required this.baseRevision,
    required this.targetRevision,
    required String payloadSha256,
    required this.payloadBytes,
  }) : payloadSha256 = _sha256(payloadSha256) {
    if (sequence < 0) {
      throw ArgumentError.value(
        sequence,
        'sequence',
        'Recovery sequence cannot be negative.',
      );
    }
    if (baseRevision < 0 || targetRevision < baseRevision) {
      throw ArgumentError(
        'Recovery revisions must satisfy 0 <= base <= target.',
      );
    }
    if (payloadBytes < 1) {
      throw ArgumentError.value(
        payloadBytes,
        'payloadBytes',
        'Recovery payload must contain at least one byte.',
      );
    }
  }

  final GgenId id;
  final GgenId projectId;
  final RecoveryRecordKind kind;
  final int sequence;
  final int baseRevision;
  final int targetRevision;
  final String payloadSha256;
  final int payloadBytes;
}

/// Crash-recovery storage contract. Implementations must append atomically.
abstract interface class AutosaveRecoveryJournal {
  Future<void> append(RecoveryJournalRecord record);

  Stream<RecoveryJournalRecord> entries(GgenId projectId);

  Future<void> markReplayed(GgenId projectId, int throughSequence);
}

String _sha256(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'payloadSha256',
      'Payload digest must be a 64-character lowercase SHA-256 value.',
    );
  }
  return value;
}
