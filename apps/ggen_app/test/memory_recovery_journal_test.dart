import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/storage/memory_recovery_journal.dart';
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
  final project = GgenId('project-1');

  group('bounded recovery journal', () {
    test('append and entries stream records in order', () async {
      final journal = MemoryRecoveryJournal(_policy());
      await journal.append(_record(project, 0));
      await journal.append(
        _record(project, 1, kind: RecoveryRecordKind.checkpoint),
      );

      final seen = await journal.entries(project).toList();
      expect(seen.map((record) => record.sequence), <int>[0, 1]);
      expect(seen.first.kind, RecoveryRecordKind.transaction);
      expect(seen.last.kind, RecoveryRecordKind.checkpoint);
      expect(await journal.entries(GgenId('other')).toList(), isEmpty);
    });

    test('entry cap evicts the oldest records', () async {
      final journal = MemoryRecoveryJournal(_policy(maxJournalEntries: 3));
      for (var i = 0; i < 5; i++) {
        await journal.append(_record(project, i));
      }
      expect(journal.recordCount, 3);
      expect(journal.records.map((record) => record.sequence), <int>[2, 3, 4]);
    });

    test('byte budget evicts the oldest records', () async {
      // Each record accounts for payload bytes plus a 256-byte overhead.
      final journal = MemoryRecoveryJournal(_policy(maxJournalBytes: 800));
      for (var i = 0; i < 5; i++) {
        await journal.append(_record(project, i));
      }
      expect(journal.recordCount, 3);
      expect(journal.records.first.sequence, 2);
    });

    test('records larger than the byte budget are rejected', () async {
      final journal = MemoryRecoveryJournal(_policy(maxJournalBytes: 100));
      await expectLater(
        () => journal.append(_record(project, 0, payload: 'x' * 500)),
        throwsStateError,
      );
    });

    test('payload association reconstructs the latest project', () async {
      final journal = MemoryRecoveryJournal(_policy());
      await journal.append(_record(project, 0));
      final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
      final envelope0 = ProjectEnvelope(
        project: DocumentProject(id: project, name: 'P', revision: 0),
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      );
      journal.storePayload(project, GgenId('rec-0'), codec.encode(envelope0));

      await journal.append(_record(project, 1));
      final envelope1 = ProjectEnvelope(
        project: DocumentProject(id: project, name: 'P', revision: 1),
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      );
      journal.storePayload(project, GgenId('rec-1'), codec.encode(envelope1));

      expect(journal.payloadFor(GgenId('rec-0'))!.project.revision, 0);
      expect(journal.latestPayload(project)!.project.revision, 1);
      expect(journal.latestPayload(GgenId('other')), isNull);
    });

    test('replay markers cannot move backwards', () async {
      final journal = MemoryRecoveryJournal(_policy());
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
