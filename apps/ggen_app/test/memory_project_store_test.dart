import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/storage/memory_project_store.dart';
import 'package:ggen_core/ggen_core.dart';

ProjectEnvelope _envelope(int revision, {String id = 'project-1'}) =>
    ProjectEnvelope(
      project: DocumentProject(id: GgenId(id), name: 'P', revision: revision),
      schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
    );

void main() {
  group('transactional store', () {
    test(
      'staged commit stores the envelope and returns a valid receipt',
      () async {
        final store = MemoryProjectStore();
        final key = ProjectStorageKey('project-1');
        final transaction = await store.begin(key);
        await transaction.stage(_envelope(0));
        final receipt = await transaction.commit();

        expect(receipt.key, key);
        expect(receipt.projectId.value, 'project-1');
        expect(receipt.committedRevision, 0);
        expect(receipt.contentSha256, hasLength(64));
        expect(receipt.contentSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(receipt.byteSize, greaterThan(0));

        final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
        final encoded = utf8.encode(codec.encode(_envelope(0)));
        expect(receipt.byteSize, encoded.length);
        expect(receipt.contentSha256, sha256.convert(encoded).toString());

        final read = await store.read(key);
        expect(read, isNotNull);
        expect(read!.project.revision, 0);
        expect(store.latest()!.project.id, read.project.id);
      },
    );

    test('commit without a staged envelope fails', () async {
      final store = MemoryProjectStore();
      final transaction = await store.begin(ProjectStorageKey('project-1'));
      expect(transaction.commit(), throwsStateError);
    });

    test('cancel discards the staged write', () async {
      final store = MemoryProjectStore();
      final key = ProjectStorageKey('project-1');
      final transaction = await store.begin(key);
      await transaction.stage(_envelope(0));
      await transaction.cancel();
      expect(await store.read(key), isNull);
      expect(store.latest(), isNull);
    });

    test('stale expected revisions are rejected', () async {
      final store = MemoryProjectStore();
      final key = ProjectStorageKey('project-1');
      final first = await store.begin(key);
      await first.stage(_envelope(0));
      await first.commit();

      // Same revision is fine (idempotent re-save).
      final redo = await store.begin(key, expectedRevision: 0);
      await redo.stage(_envelope(0));
      final redoReceipt = await redo.commit();
      expect(redoReceipt.committedRevision, 0);

      // A stale expectation is rejected.
      expect(() => store.begin(key, expectedRevision: 1), throwsStateError);
    });

    test('non-advancing staged revisions are rejected at commit', () async {
      final store = MemoryProjectStore();
      final key = ProjectStorageKey('project-1');
      final first = await store.begin(key);
      await first.stage(_envelope(0));
      await first.commit();

      final transaction = await store.begin(key, expectedRevision: 0);
      await transaction.stage(_envelope(2));
      expect(transaction.commit(), throwsStateError);
    });

    test('used transactions cannot be reused', () async {
      final store = MemoryProjectStore();
      final key = ProjectStorageKey('project-1');
      final transaction = await store.begin(key);
      await transaction.stage(_envelope(0));
      await transaction.commit();
      await expectLater(
        () => transaction.stage(_envelope(0)),
        throwsStateError,
      );
    });

    test('latest returns the most recently committed envelope', () async {
      final store = MemoryProjectStore();
      final first = await store.begin(ProjectStorageKey('project-1'));
      await first.stage(_envelope(0, id: 'project-1'));
      await first.commit();

      final second = await store.begin(ProjectStorageKey('project-2'));
      await second.stage(_envelope(1, id: 'project-2'));
      await second.commit();

      expect(store.latest()!.project.id.value, 'project-2');
      expect(store.latest()!.project.revision, 1);
    });
  });
}
