import 'package:ggen_core/ggen_core.dart';

import 'payload_journal.dart';

/// Bounded in-memory [AutosaveRecoveryJournal] used as the default and for
/// tests.
///
/// Records are appended in order, evicted oldest-first when the entry count
/// or byte budget from [policy] is exceeded, and replayed in append order.
/// Payload association is an in-memory extension so replay can reconstruct
/// projects within this process; the file-backed journal provides the
/// durable payload layout.
final class MemoryRecoveryJournal
    implements AutosaveRecoveryJournal, PayloadJournal {
  MemoryRecoveryJournal(this.policy);

  /// Per-record in-memory overhead estimate used for the byte budget.
  static const int recordOverheadBytes = 256;

  final AutosavePolicy policy;
  final List<RecoveryJournalRecord> _records = <RecoveryJournalRecord>[];
  final Map<GgenId, String> _payloads = <GgenId, String>{};
  final Map<GgenId, int> _replayedThrough = <GgenId, int>{};
  final ProjectCodec _codec = ProjectCodec(
    limits: ProjectCodecLimits.conservative(),
  );

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

  @override
  void storePayload(GgenId projectId, GgenId recordId, String canonicalJson) {
    _payloads[recordId] = canonicalJson;
  }

  ProjectEnvelope? payloadFor(GgenId recordId) {
    final payload = _payloads[recordId];
    if (payload == null) return null;
    try {
      return _codec.decode(payload);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<ProjectEnvelope?> latestPayload(GgenId projectId) async {
    GgenId? latestRecord;
    for (final record in _records) {
      if (record.projectId == projectId) latestRecord = record.id;
    }
    if (latestRecord == null) return null;
    return payloadFor(latestRecord);
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
