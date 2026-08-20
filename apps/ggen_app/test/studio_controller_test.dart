import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_app/src/storage/memory_project_store.dart';
import 'package:ggen_app/src/storage/memory_recovery_journal.dart';
import 'package:ggen_core/ggen_core.dart';

/// Adds one shape node to every artboard of [project] without changing its
/// identity or revision (valid tool-session preview semantics).
DocumentProject _withNode(DocumentProject project, String name) {
  final artboards = <Artboard>[
    for (final artboard in project.artboards)
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: <DocumentNode>[
          ...artboard.nodes,
          DocumentNode(
            id: GgenId('node-$name'),
            kind: DocumentNodeKind.shape,
            name: name,
          ),
        ],
      ),
  ];
  return project.copyWith(artboards: artboards);
}

void main() {
  group('project lifecycle', () {
    test('starts with an untitled revision 0 project and one artboard', () {
      final controller = StudioController();
      expect(controller.project.name, 'Untitled project');
      expect(controller.revision, 0);
      expect(controller.objectCount, 0);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
      expect(controller.project.artboards, hasLength(1));
      expect(controller.project.artboards.single.nodes, isEmpty);
    });

    test('new project replaces the project and clears history', () {
      final controller = StudioController();
      final session = controller.beginSession();
      session.updatePreview(_withNode(session.preview, 'shape-1'));
      controller.commitSession(session, 'add shape-1');
      expect(controller.revision, 1);

      controller.newProject('Fresh');
      expect(controller.project.name, 'Fresh');
      expect(controller.revision, 0);
      expect(controller.objectCount, 0);
      expect(controller.canUndo, isFalse);
      expect(controller.serialize(), isNot(contains('shape-1')));
    });
  });

  group('tool sessions', () {
    test('commit creates exactly one undoable transaction', () {
      final controller = StudioController();
      final session = controller.beginSession();
      session.updatePreview(_withNode(session.preview, 'shape-1'));
      controller.commitSession(session, 'add shape-1');

      expect(controller.revision, 1);
      expect(controller.objectCount, 1);
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      controller.undo();
      expect(controller.revision, 0);
      expect(controller.objectCount, 0);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.revision, 1);
      expect(controller.objectCount, 1);
    });

    test('cancel restores the exact input without a transaction', () {
      final controller = StudioController();
      final before = controller.project;
      final session = controller.beginSession();
      session.updatePreview(_withNode(session.preview, 'shape-1'));
      controller.cancelSession(session);

      expect(controller.project.id, before.id);
      expect(controller.revision, 0);
      expect(controller.objectCount, 0);
      expect(controller.canUndo, isFalse);
    });

    test('identity or revision changing previews are rejected', () {
      final controller = StudioController();
      final session = controller.beginSession();

      final tamperedRevision = session.preview.copyWith(revision: 99);
      expect(() => session.updatePreview(tamperedRevision), throwsStateError);

      final otherProject = DocumentProject(
        id: GgenId('other'),
        name: 'Other',
        artboards: session.preview.artboards,
      );
      expect(() => session.updatePreview(otherProject), throwsStateError);
    });

    test('stale sessions are rejected by the bounded history', () {
      final controller = StudioController();
      final stale = controller.beginSession();
      controller.commitSession(controller.beginSession(), 'first');
      stale.updatePreview(_withNode(stale.preview, 'shape-1'));
      expect(() => controller.commitSession(stale, 'stale'), throwsStateError);
    });
  });

  group('history bounds', () {
    test('oldest transactions are trimmed past the limit', () {
      final controller = StudioController(historyLimit: 2);
      for (var i = 0; i < 4; i++) {
        final session = controller.beginSession();
        session.updatePreview(_withNode(session.preview, 'shape-$i'));
        controller.commitSession(session, 'add shape-$i');
      }
      expect(controller.revision, 4);

      controller.undo();
      controller.undo();
      expect(controller.revision, 2);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);
    });
  });

  group('serialization', () {
    test('canonical round trip preserves the project', () {
      final controller = StudioController();
      final session = controller.beginSession();
      session.updatePreview(_withNode(session.preview, 'shape-1'));
      controller.commitSession(session, 'add shape-1');

      final json = controller.serialize();
      expect(json, contains('"format":"ggen.project"'));
      expect(controller.lastSerializedBytes, greaterThan(0));

      final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
      final decoded = codec.decode(json);
      expect(decoded.project.id, controller.project.id);
      expect(decoded.project.name, controller.project.name);
      expect(decoded.project.revision, 1);
      expect(decoded.project.artboards.single.nodes, hasLength(1));
      // Canonical ordering: re-encoding the decoded envelope is byte-identical.
      expect(codec.encode(decoded), json);
    });

    test('edits invalidate serialized state until re-serialized', () {
      final controller = StudioController();
      controller.serialize();
      expect(controller.lastSerializedBytes, greaterThan(0));

      final session = controller.beginSession();
      session.updatePreview(_withNode(session.preview, 'shape-1'));
      controller.commitSession(session, 'add shape-1');
      expect(controller.lastSerializedBytes, 0);
      expect(controller.lastSerialized, isEmpty);
    });
  });

  group('persistence', () {
    test(
      'save persists through the transactional store with a receipt',
      () async {
        final controller = StudioController();
        final session = controller.beginSession();
        session.updatePreview(_withNode(session.preview, 'shape-1'));
        controller.commitSession(session, 'add shape-1');

        final receipt = await controller.save();
        expect(receipt.key, controller.storageKey);
        expect(receipt.committedRevision, 1);
        expect(receipt.contentSha256, hasLength(64));
        expect(receipt.byteSize, greaterThan(0));
        expect(controller.lastReceipt, same(receipt));
      },
    );

    test('save then restore reconstructs the project from the store', () async {
      final store = MemoryProjectStore();
      final journal = MemoryRecoveryJournal(
        AutosavePolicy(
          maxJournalEntries: 200,
          maxJournalBytes: 1 << 20,
          checkpointEveryTransactions: 8,
        ),
      );
      final controller = StudioController(store: store, journal: journal);
      final session = controller.beginSession();
      session.updatePreview(_withNode(session.preview, 'shape-1'));
      controller.commitSession(session, 'add shape-1');
      final key = controller.storageKey;
      await controller.save();

      final restored = StudioController(store: store, journal: journal);
      expect(await restored.restore(key), isTrue);
      expect(restored.project.id, controller.project.id);
      expect(restored.project.name, 'Untitled project');
      expect(restored.revision, 1);
      expect(restored.objectCount, 1);
      // Restore is a snapshot: history starts fresh at the restored revision.
      expect(restored.canUndo, isFalse);
    });

    test('restore returns false when the key is absent', () async {
      final controller = StudioController();
      expect(
        await controller.restore(ProjectStorageKey('project-missing')),
        isFalse,
      );
      expect(controller.revision, 0);
    });

    test('committed edits append bounded journal transactions', () async {
      final journal = MemoryRecoveryJournal(
        AutosavePolicy(
          maxJournalEntries: 200,
          maxJournalBytes: 1 << 20,
          checkpointEveryTransactions: 8,
        ),
      );
      final controller = StudioController(journal: journal);

      final first = controller.beginSession();
      first.updatePreview(_withNode(first.preview, 'shape-1'));
      controller.commitSession(first, 'add shape-1');

      final second = controller.beginSession();
      second.updatePreview(_withNode(second.preview, 'shape-2'));
      controller.commitSession(second, 'add shape-2');

      expect(journal.recordCount, 2);
      expect(
        journal.records.every(
          (record) => record.kind == RecoveryRecordKind.transaction,
        ),
        isTrue,
      );
      expect(journal.records.first.baseRevision, 0);
      expect(journal.records.first.targetRevision, 1);
      expect(journal.records.last.baseRevision, 1);
      expect(journal.records.last.targetRevision, 2);
      expect(journal.records.last.projectId, controller.project.id);
      expect(journal.records.last.payloadSha256, hasLength(64));
    });

    test('save appends a checkpoint once the cadence is reached', () async {
      final journal = MemoryRecoveryJournal(
        AutosavePolicy(
          maxJournalEntries: 200,
          maxJournalBytes: 1 << 20,
          checkpointEveryTransactions: 4,
        ),
      );
      final controller = StudioController(
        journal: journal,
        checkpointEveryTransactions: 4,
      );
      for (var i = 0; i < 4; i++) {
        final session = controller.beginSession();
        session.updatePreview(_withNode(session.preview, 'shape-$i'));
        controller.commitSession(session, 'add shape-$i');
      }
      expect(journal.recordCount, 4);
      expect(
        journal.records.any(
          (record) => record.kind == RecoveryRecordKind.checkpoint,
        ),
        isFalse,
      );

      await controller.save();
      expect(journal.recordCount, 5);
      expect(journal.records.last.kind, RecoveryRecordKind.checkpoint);
      expect(journal.records.last.baseRevision, 4);
      expect(journal.records.last.targetRevision, 4);
    });
  });
}
