import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/storage/file_recovery_journal.dart';
import 'package:ggen_core/ggen_core.dart';

RecoveryJournalRecord _record(
  GgenId projectId,
  int sequence, {
  RecoveryRecordKind kind = RecoveryRecordKind.transaction,
  int base = 0,
  int target = 1,
  String payload = 'x',
}) {
  final bytes = utf8.encode(payload);
  return RecoveryJournalRecord(
    id: GgenId('rec-$sequence'),
    projectId: projectId,
    kind: kind,
    sequence: sequence,
    baseRevision: base,
    targetRevision: target,
    payloadSha256: sha256.convert(bytes).toString(),
    payloadBytes: bytes.length,
  );
}

AutosavePolicy _policy({
  int maxJournalEntries = 100,
  int maxJournalBytes = 1 << 20,
}) => AutosavePolicy(
  maxJournalEntries: maxJournalEntries,
  maxJournalBytes: maxJournalBytes,
  checkpointEveryTransactions: 16,
);

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ggen_journal_test_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('file-backed recovery journal', () {
    test('append and entries replay records in order', () async {
      final journal = FileRecoveryJournal(root, _policy());
      final project = GgenId('project-1');
      await journal.append(_record(project, 0));
      await journal.append(
        _record(project, 1, kind: RecoveryRecordKind.checkpoint),
      );

      final seen = await journal.entries(project).toList();
      expect(seen.map((record) => record.sequence), <int>[0, 1]);
      expect(seen.first.kind, RecoveryRecordKind.transaction);
      expect(seen.last.kind, RecoveryRecordKind.checkpoint);

      final other = GgenId('project-other');
      await journal.append(_record(other, 0));
      expect(await journal.entries(other).toList(), hasLength(1));
    });

    test('journal persists across instances (restart simulation)', () async {
      final project = GgenId('project-1');
      final first = FileRecoveryJournal(root, _policy());
      await first.append(_record(project, 0));
      await first.append(_record(project, 1));

      final second = FileRecoveryJournal(root, _policy());
      final seen = await second.entries(project).toList();
      expect(seen, hasLength(2));
      expect(seen.last.sequence, 1);
    });

    test('payloads are durable and latestPayload reconstructs', () async {
      final project = GgenId('project-1');
      final journal = FileRecoveryJournal(root, _policy());
      await journal.append(_record(project, 0));

      final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
      final envelope = ProjectEnvelope(
        project: DocumentProject(id: project, name: 'P', revision: 0),
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      );
      journal.storePayload(project, GgenId('rec-0'), codec.encode(envelope));

      await journal.append(_record(project, 1));
      final envelope1 = ProjectEnvelope(
        project: DocumentProject(id: project, name: 'P', revision: 1),
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      );
      journal.storePayload(project, GgenId('rec-1'), codec.encode(envelope1));

      // A fresh journal over the same root reconstructs the latest state.
      final fresh = FileRecoveryJournal(root, _policy());
      final latest = await fresh.latestPayload(project);
      expect(latest, isNotNull);
      expect(latest!.project.revision, 1);
      expect(latest.project.name, 'P');
    });

    test('entry cap evicts the oldest records and payloads', () async {
      // The budget applies to the whole journal file, so with a cap of 3
      // lines and interleaved payloads the newest 3 lines survive (payload
      // of record 3, record 4, payload of record 4): the visible record
      // stream is [4] and the payload reconstructs revision 4.
      final journal = FileRecoveryJournal(root, _policy(maxJournalEntries: 3));
      final project = GgenId('project-1');
      final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
      for (var i = 0; i < 5; i++) {
        await journal.append(_record(project, i));
        final envelope = ProjectEnvelope(
          project: DocumentProject(id: project, name: 'P', revision: i),
          schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
        );
        journal.storePayload(project, GgenId('rec-$i'), codec.encode(envelope));
      }

      final seen = await journal.entries(project).toList();
      expect(seen.map((record) => record.sequence), <int>[4]);

      final latest = await journal.latestPayload(project);
      expect(latest!.project.revision, 4);
    });

    test('records larger than the byte budget are rejected', () async {
      final journal = FileRecoveryJournal(root, _policy(maxJournalBytes: 100));
      await expectLater(
        () => journal.append(_record(GgenId('p'), 0, payload: 'x' * 500)),
        throwsStateError,
      );
    });

    test('replay markers cannot move backwards', () async {
      final journal = FileRecoveryJournal(root, _policy());
      final project = GgenId('project-1');
      await journal.markReplayed(project, 5);
      expect(journal.replayedThrough(project), 5);
      await expectLater(
        () => journal.markReplayed(project, 3),
        throwsStateError,
      );
      expect(journal.replayedThrough(project), 5);
    });
  });
}
