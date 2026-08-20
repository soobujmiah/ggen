import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/storage/file_project_store.dart';
import 'package:ggen_core/ggen_core.dart';

ProjectEnvelope _envelope(int revision, {String id = 'project-1'}) =>
    ProjectEnvelope(
      project: DocumentProject(id: GgenId(id), name: 'P', revision: revision),
      schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
    );

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ggen_store_test_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('file-backed transactional store', () {
    test(
      'commit writes the canonical .ggen file and returns a receipt',
      () async {
        final store = FileProjectStore(root);
        final key = ProjectStorageKey('project-1');
        final transaction = await store.begin(key);
        await transaction.stage(_envelope(0));
        final receipt = await transaction.commit();

        expect(receipt.key, key);
        expect(receipt.committedRevision, 0);
        expect(receipt.contentSha256, hasLength(64));
        expect(receipt.byteSize, greaterThan(0));

        final file = File('${root.path}/projects/project-1.ggen');
        expect(file.existsSync(), isTrue);
        expect(file.readAsStringSync(), contains('"format":"ggen.project"'));

        final read = await store.read(key);
        expect(read, isNotNull);
        expect(read!.project.revision, 0);
      },
    );

    test('store is durable across instances (restart simulation)', () async {
      final first = FileProjectStore(root);
      final key = ProjectStorageKey('project-1');
      final transaction = await first.begin(key);
      await transaction.stage(_envelope(3));
      await transaction.commit();

      // The committing instance exposes the session-scoped latest().
      expect(first.latest()!.project.id.value, 'project-1');

      // A brand-new store over the same root sees the committed project.
      final second = FileProjectStore(root);
      final read = await second.read(key);
      expect(read, isNotNull);
      expect(read!.project.revision, 3);
    });

    test('stale expected revisions are rejected', () async {
      final store = FileProjectStore(root);
      final key = ProjectStorageKey('project-1');
      final first = await store.begin(key);
      await first.stage(_envelope(0));
      await first.commit();

      final redo = await store.begin(key, expectedRevision: 0);
      await redo.stage(_envelope(0));
      final redoReceipt = await redo.commit();
      expect(redoReceipt.committedRevision, 0);

      expect(() => store.begin(key, expectedRevision: 1), throwsStateError);
    });

    test('non-advancing staged revisions are rejected at commit', () async {
      final store = FileProjectStore(root);
      final key = ProjectStorageKey('project-1');
      final first = await store.begin(key);
      await first.stage(_envelope(0));
      await first.commit();

      final transaction = await store.begin(key, expectedRevision: 0);
      await transaction.stage(_envelope(2));
      expect(transaction.commit(), throwsStateError);
    });

    test('cancel discards the staged write', () async {
      final store = FileProjectStore(root);
      final key = ProjectStorageKey('project-1');
      final transaction = await store.begin(key);
      await transaction.stage(_envelope(0));
      await transaction.cancel();
      expect(await store.read(key), isNull);
    });

    test('corrupt project files are reported, not silently accepted', () async {
      final store = FileProjectStore(root);
      final key = ProjectStorageKey('project-1');
      final file = File('${root.path}/projects/project-1.ggen');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{not json');

      expect(() => store.read(key), throwsFormatException);
    });
  });

  group('encoding matches the canonical codec', () {
    test('stored bytes decode back to the staged project', () async {
      final store = FileProjectStore(root);
      final key = ProjectStorageKey('project-1');
      final transaction = await store.begin(key);
      await transaction.stage(_envelope(2));
      final receipt = await transaction.commit();

      final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
      final encoded = codec.encode(_envelope(2));
      expect(receipt.byteSize, utf8.encode(encoded).length);

      final read = await store.read(key);
      expect(read!.project.name, 'P');
      expect(read.project.revision, 2);
    });
  });
}
