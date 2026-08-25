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

    test('revisions behind the stored revision are rejected at commit', () async {
      final store = FileProjectStore(root);
      final key = ProjectStorageKey('project-1');
      final first = await store.begin(key);
      await first.stage(_envelope(5));
      await first.commit();

      // Unwinding the stored revision must fail; the async result is awaited
      // via expectLater so the thrown StateError is actually observed
      // (the previous sync-style expect on a Future never saw it).
      final transaction = await store.begin(key, expectedRevision: 5);
      await transaction.stage(_envelope(2));
      await expectLater(transaction.commit(), throwsStateError);
    });

    test('multi-step revision jumps ahead of the stored revision commit', () async {
      // Regression for the device-observed "project save not found": the old
      // strict +1 check rejected a staged revision 5 after a stored 0 (five
      // edits between saves). Any advancing revision must commit.
      final store = FileProjectStore(root);
      final key = ProjectStorageKey('project-1');
      final first = await store.begin(key);
      await first.stage(_envelope(0));
      await first.commit();

      final jump = await store.begin(key, expectedRevision: 0);
      await jump.stage(_envelope(5));
      final receipt = await jump.commit();
      expect(receipt.committedRevision, 5);

      // Idempotent re-save of the same revision stays accepted.
      final redo = await store.begin(key, expectedRevision: 5);
      await redo.stage(_envelope(5));
      final redoReceipt = await redo.commit();
      expect(redoReceipt.committedRevision, 5);
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

  group('saved project listing', () {
    ProjectEnvelope namedEnvelope(int revision, String id, String name) =>
        ProjectEnvelope(
          project: DocumentProject(
            id: GgenId(id),
            name: name,
            revision: revision,
          ),
          schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
        );

    Future<void> commitProject(
      FileProjectStore store,
      String id,
      String name,
      int revision,
    ) async {
      final transaction = await store.begin(ProjectStorageKey(id));
      await transaction.stage(namedEnvelope(revision, id, name));
      await transaction.commit();
    }

    test('lists committed projects, most recently updated first', () async {
      final store = FileProjectStore(root);
      await commitProject(store, 'alpha', 'Alpha', 0);
      await commitProject(store, 'beta', 'Beta', 3);
      await File('${root.path}/projects/alpha.ggen').setLastModified(
        DateTime(2026, 8, 20, 10),
      );
      await File('${root.path}/projects/beta.ggen').setLastModified(
        DateTime(2026, 8, 22, 18),
      );

      final summaries = await store.listSavedProjects();
      expect(summaries, hasLength(2));
      expect(summaries.first.key, 'beta');
      expect(summaries.first.name, 'Beta');
      expect(summaries.first.revision, 3);
      expect(summaries.first.byteSize, greaterThan(0));
      expect(summaries.last.key, 'alpha');
      expect(summaries.last.name, 'Alpha');
      expect(summaries.last.revision, 0);
    });

    test('corrupt, invalid-key and non-project files are skipped', () async {
      final store = FileProjectStore(root);
      await commitProject(store, 'alpha', 'Alpha', 0);
      // Corrupt payload with a valid key shape.
      File('${root.path}/projects/corrupt.ggen')
          .writeAsStringSync('{not valid json');
      // Valid JSON that is not a project envelope.
      File('${root.path}/projects/odd.ggen').writeAsStringSync('{"x":1}');
      // File whose name is not a valid storage key.
      File('${root.path}/projects/UPPER.ggen').writeAsStringSync('{}');
      // Unrelated extension.
      File('${root.path}/projects/notes.txt').writeAsStringSync('ignore me');

      final summaries = await store.listSavedProjects();
      expect(summaries, hasLength(1));
      expect(summaries.single.key, 'alpha');
    });

    test('an empty store lists nothing', () async {
      expect(await FileProjectStore(root).listSavedProjects(), isEmpty);
    });
  });
}
