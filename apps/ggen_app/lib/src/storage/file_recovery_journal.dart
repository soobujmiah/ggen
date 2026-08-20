import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ggen_core/ggen_core.dart';

import 'payload_journal.dart';

/// File-backed [AutosaveRecoveryJournal] with durable payload association.
///
/// Layout under [root]:
///   `<root>/journal/<sha256(projectId)>.jrnl`
///
/// The journal file is a line-oriented JSON log. Each line is either a
/// record line (`{"type":"record","record":{...}}`) or a payload line
/// (`{"type":"payload","record_id":"...","payload":"<canonical JSON>"}`),
/// appended atomically with a flush. Bounds from [policy] are enforced by
/// rewriting the file to keep only the most recent entries that fit.
///
/// Replay markers are session-scoped in memory: replay is idempotent by
/// revision, so re-applying entries after a crash cannot corrupt state.
final class FileRecoveryJournal
    implements AutosaveRecoveryJournal, PayloadJournal {
  FileRecoveryJournal(Directory root, this.policy)
    : journalDir = _ensureDir(root, 'journal');

  static const String _recordType = 'record';
  static const String _payloadType = 'payload';

  final Directory journalDir;
  final AutosavePolicy policy;
  final Map<GgenId, int> _replayedThrough = <GgenId, int>{};
  final ProjectCodec _codec = ProjectCodec(
    limits: ProjectCodecLimits.conservative(),
  );

  File _fileFor(GgenId projectId) {
    final digest = sha256.convert(utf8.encode(projectId.value)).toString();
    return File('${journalDir.path}${Platform.pathSeparator}$digest.jrnl');
  }

  @override
  Future<void> append(RecoveryJournalRecord record) async {
    if (record.payloadBytes > policy.maxJournalBytes) {
      throw StateError(
        'Recovery record ${record.id} exceeds the journal byte budget '
        '${policy.maxJournalBytes}.',
      );
    }
    final file = _fileFor(record.projectId);
    await _appendLine(
      file,
      jsonEncode(<String, Object?>{
        'type': _recordType,
        'record': _recordToJson(record),
      }),
    );
    _enforceBoundsSync(file);
  }

  @override
  void storePayload(GgenId projectId, GgenId recordId, String canonicalJson) {
    final file = _fileFor(projectId);
    if (!file.existsSync()) return;
    // Synchronous append: the interface is sync, so the payload must be
    // visible to the next read without a pending async write.
    file.writeAsStringSync(
      '${jsonEncode(<String, Object?>{'type': _payloadType, 'record_id': recordId.value, 'payload': canonicalJson})}\n',
      mode: FileMode.append,
      flush: true,
    );
    _enforceBoundsSync(file);
  }

  @override
  Future<ProjectEnvelope?> latestPayload(GgenId projectId) async {
    final file = _fileFor(projectId);
    if (!file.existsSync()) return null;
    String? found;
    for (final line in file.readAsLinesSync()) {
      final entry = _parseLine(line);
      if (entry == null || entry['type'] != _payloadType) continue;
      found = entry['payload'] as String?;
    }
    if (found == null) return null;
    try {
      return _codec.decode(found);
    } on FormatException {
      return null;
    }
  }

  @override
  Stream<RecoveryJournalRecord> entries(GgenId projectId) async* {
    final file = _fileFor(projectId);
    if (!file.existsSync()) return;
    for (final line in file.readAsLinesSync()) {
      final entry = _parseLine(line);
      if (entry == null || entry['type'] != _recordType) continue;
      yield _recordFromJson(entry['record'] as Map<String, Object?>);
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

  // -- internals ---------------------------------------------------------

  Future<void> _appendLine(File file, String line) async {
    final sink = file.openWrite(mode: FileMode.append);
    sink.write('$line\n');
    await sink.flush();
    await sink.close();
  }

  void _enforceBoundsSync(File file) {
    if (!file.existsSync()) return;
    final lines = file.readAsLinesSync();
    if (lines.length <= policy.maxJournalEntries &&
        _bytes(lines) <= policy.maxJournalBytes) {
      return;
    }
    while (lines.isNotEmpty &&
        (lines.length > policy.maxJournalEntries ||
            _bytes(lines) > policy.maxJournalBytes)) {
      lines.removeAt(0);
    }
    if (lines.isEmpty) {
      file.deleteSync();
      return;
    }
    final tmpPath = '${file.path}.tmp';
    File(tmpPath).writeAsStringSync('${lines.join('\n')}\n', flush: true);
    File(tmpPath).renameSync(file.path);
  }

  static int _bytes(List<String> lines) =>
      lines.fold<int>(0, (sum, line) => sum + utf8.encode(line).length + 1);

  static Map<String, Object?>? _parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      return null;
    }
    return null;
  }

  static Map<String, Object?> _recordToJson(RecoveryJournalRecord record) =>
      <String, Object?>{
        'id': record.id.value,
        'project_id': record.projectId.value,
        'kind': record.kind.name,
        'sequence': record.sequence,
        'base_revision': record.baseRevision,
        'target_revision': record.targetRevision,
        'payload_sha256': record.payloadSha256,
        'payload_bytes': record.payloadBytes,
      };

  static RecoveryJournalRecord _recordFromJson(Map<String, Object?> json) =>
      RecoveryJournalRecord(
        id: GgenId(json['id'] as String),
        projectId: GgenId(json['project_id'] as String),
        kind: RecoveryRecordKind.values.byName(json['kind'] as String),
        sequence: json['sequence'] as int,
        baseRevision: json['base_revision'] as int,
        targetRevision: json['target_revision'] as int,
        payloadSha256: json['payload_sha256'] as String,
        payloadBytes: json['payload_bytes'] as int,
      );

  static Directory _ensureDir(Directory root, String name) {
    final dir = Directory('${root.path}${Platform.pathSeparator}$name')
      ..createSync(recursive: true);
    return dir;
  }
}
