import 'package:ggen_core/ggen_core.dart';

/// Bounded in-memory [AutosaveRecoveryJournal] used until a platform storage
/// decision is accepted.
///
/// Records are appended in order, evicted oldest-first when the entry count
/// or byte budget from [policy] is exceeded, and replayed in append order.
/// Payload association is an in-memory extension so replay can reconstruct
/// projects within this process; the file adapter milestone will define the
/// durable payload layout.
final class MemoryRecoveryJournal implements AutosaveRecoveryJournal {
  MemoryRecoveryJournal(this.policy);

  /// Per-record in-memory overhead estimate used for the byte budget.
  static const int recordOverheadBytes = 256;

  final AutosavePolicy policy;
  final List<RecoveryJournalRecord> _records = <RecoveryJournalRecord>[];
  final Map<GgenId, ProjectEnvelope> _payloads = <GgenId, ProjectEnvelope>{};
  final Map<GgenId, int> _replayedThrough = <GgenId, int>{};

  List<RecoveryJournalRecord> get records => List.unmodifiable(_records);
  int get recordCount => _records.length;

  @override
  Future<void> append(RecoveryJournalRecord record) async {
    if (record.payloadBytes > policy.maxJournalBytes) {
      throw StateError(
        'Recovery record ${record.id} exceeds the journal byte budget '
        '${policy.maxJournalBytes}.',
      );
    }
    _records.add(record);
    _evict();
  }

  /// Memory-only extension: associates the encoded payload with [recordId]
  /// so replay can reconstruct the project in this process.
  void storePayload(GgenId recordId, ProjectEnvelope envelope) {
    _payloads[recordId] = envelope;
  }

  ProjectEnvelope? payloadFor(GgenId recordId) => _payloads[recordId];

  /// Reconstructs the latest payload recorded for [projectId] in sequence
  /// order — the in-memory replay result.
  ProjectEnvelope? latestPayload(GgenId projectId) {
    ProjectEnvelope? found;
    for (final record in _records) {
      if (record.projectId == projectId) {
        final payload = _payloads[record.id];
        if (payload != null) found = payload;
      }
    }
    return found;
  }

  @override
  Stream<RecoveryJournalRecord> entries(GgenId projectId) async* {
    for (final record in _records) {
      if (record.projectId == projectId) yield record;
    }
  }

  @override
  Future<void> markReplayed(GgenId projectId, int throughSequence) async {
    final previous = _replayedThrough[projectId] ?? -1;
    if (throughSequence < previous) {
      throw StateError(
        'Replay marker for $projectId cannot move backwards '
        '($throughSequence < $previous).',
      );
    }
    _replayedThrough[projectId] = throughSequence;
  }

  int? replayedThrough(GgenId projectId) => _replayedThrough[projectId];

  void _evict() {
    var bytes = _records.fold<int>(
      0,
      (sum, record) => sum + record.payloadBytes + recordOverheadBytes,
    );
    while (_records.isNotEmpty &&
        (_records.length > policy.maxJournalEntries ||
            bytes > policy.maxJournalBytes)) {
      final removed = _records.removeAt(0);
      _payloads.remove(removed.id);
      bytes -= removed.payloadBytes + recordOverheadBytes;
    }
  }
}
