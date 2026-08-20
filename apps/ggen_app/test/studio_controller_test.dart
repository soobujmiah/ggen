import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/canvas/studio_canvas.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_app/src/storage/file_project_store.dart';
import 'package:ggen_app/src/storage/file_recovery_journal.dart';
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

    test('undo and redo append journal state markers and deltas', () async {
      final journal = MemoryRecoveryJournal(
        AutosavePolicy(
          maxJournalEntries: 200,
          maxJournalBytes: 1 << 20,
          checkpointEveryTransactions: 8,
        ),
      );
      final controller = StudioController(journal: journal);

      final session = controller.beginSession();
      session.updatePreview(_withNode(session.preview, 'shape-1'));
      controller.commitSession(session, 'add shape-1'); // delta 0 -> 1
      controller.undo(); // state marker 0 == 0
      controller.redo(); // delta 0 -> 1

      expect(journal.recordCount, 3);
      final records = journal.records;
      expect(records[0].baseRevision, 0);
      expect(records[0].targetRevision, 1);
      expect(records[1].baseRevision, 0);
      expect(records[1].targetRevision, 0);
      expect(records[2].baseRevision, 0);
      expect(records[2].targetRevision, 1);
      expect(
        records.every(
          (record) => record.kind == RecoveryRecordKind.transaction,
        ),
        isTrue,
      );
      expect(records.last.projectId, controller.project.id);
    });

    test('file-backed save survives a full controller restart', () async {
      final root = await Directory.systemTemp.createTemp('ggen_restart_');
      addTearDown(() => root.delete(recursive: true));

      final store = FileProjectStore(root);
      final journal = FileRecoveryJournal(
        root,
        AutosavePolicy(
          maxJournalEntries: 200,
          maxJournalBytes: 1 << 20,
          checkpointEveryTransactions: 8,
        ),
      );
      final first = StudioController(store: store, journal: journal);
      final session = first.beginSession();
      session.updatePreview(_withNode(session.preview, 'shape-1'));
      first.commitSession(session, 'add shape-1');
      final key = first.storageKey;
      final receipt = await first.save();
      expect(receipt.byteSize, greaterThan(0));
      await first.flushJournal();

      // A brand-new controller over the same root (fresh process) restores
      // the project from the file store with the journal intact.
      final restarted = StudioController(store: store, journal: journal);
      expect(await restarted.restore(key), isTrue);
      expect(restarted.project.id, first.project.id);
      expect(restarted.revision, 1);
      expect(restarted.objectCount, 1);

      // The journal carries the durable payload for replay.
      final latest = await journal.latestPayload(restarted.project.id);
      expect(latest, isNotNull);
      expect(latest!.project.revision, 1);
      expect(latest.project.artboards.single.nodes, hasLength(1));
    });
  });

  group('draw tool', () {
    test('addShapeNode adds one undoable shape node with geometry', () {
      final controller = StudioController();
      controller.addShapeNode(300, 200);

      expect(controller.revision, 1);
      expect(controller.objectCount, 1);
      expect(controller.canUndo, isTrue);

      final node = controller.project.artboards.first.nodes.single;
      expect(node.kind, DocumentNodeKind.shape);
      expect(node.name, 'Shape 1');
      final geometry = nodeGeometry(node);
      expect(geometry, isNotNull);
      expect(geometry!.x, 300);
      expect(geometry.y, 200);
      expect(geometry.width, 64);
      expect(geometry.height, 64);
      expect(geometry.color, isA<int>());
    });

    test('taps outside the artboard are clamped inside it', () {
      final controller = StudioController();
      controller.addShapeNode(-500, 10000);

      final node = controller.project.artboards.first.nodes.single;
      final geometry = nodeGeometry(node)!;
      expect(geometry.x, 0);
      expect(geometry.y, 800 - 64);
      expect(geometry.x + geometry.width, lessThanOrEqualTo(1200));
      expect(geometry.y + geometry.height, lessThanOrEqualTo(800));
    });

    test('undo removes the shape and redo restores it', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;

      controller.undo();
      expect(controller.revision, 0);
      expect(controller.objectCount, 0);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.revision, 1);
      expect(controller.objectCount, 1);
      expect(controller.project.artboards.first.nodes.single.id, nodeId);
    });

    test('invalid geometry is rejected', () {
      final controller = StudioController();
      expect(() => controller.addShapeNode(double.nan, 0), throwsArgumentError);
      expect(
        () => controller.addShapeNode(0, 0, size: -10),
        throwsArgumentError,
      );
      expect(controller.revision, 0);
    });

    test('new project resets the shape sequence', () {
      final controller = StudioController();
      controller.addShapeNode(10, 10);
      controller.newProject('Fresh');
      controller.addShapeNode(20, 20);
      expect(controller.project.artboards.first.nodes.single.name, 'Shape 1');
    });
  });

  group('text tool', () {
    test('addTextNode adds one undoable text frame with geometry', () {
      final controller = StudioController();
      controller.addTextNode(300, 200, 'Hello GGEN');

      expect(controller.revision, 1);
      expect(controller.objectCount, 1);
      expect(controller.canUndo, isTrue);

      final node = controller.project.artboards.first.nodes.single;
      expect(node.kind, DocumentNodeKind.textFrame);
      expect(node.name, 'Text 1');
      final geometry = textNodeGeometry(node);
      expect(geometry, isNotNull);
      expect(geometry!.x, 300);
      expect(geometry.y, 200);
      expect(geometry.size, 24);
      expect(geometry.text, 'Hello GGEN');
    });

    test('text is trimmed and clamped into the artboard', () {
      final controller = StudioController();
      controller.addTextNode(-500, 10000, '  padded  ');

      final node = controller.project.artboards.first.nodes.single;
      final geometry = textNodeGeometry(node)!;
      expect(geometry.x, 0);
      expect(geometry.y, 800);
      expect(geometry.text, 'padded');
    });

    test('empty or oversized text is rejected', () {
      final controller = StudioController();
      expect(() => controller.addTextNode(0, 0, '   '), throwsArgumentError);
      expect(
        () => controller.addTextNode(0, 0, 'x' * 300),
        throwsArgumentError,
      );
      expect(controller.revision, 0);
    });

    test('undo removes the text frame and redo restores it', () {
      final controller = StudioController();
      controller.addTextNode(10, 10, 'hi');
      expect(controller.objectCount, 1);

      controller.undo();
      expect(controller.objectCount, 0);
      controller.redo();
      expect(controller.objectCount, 1);
      expect(
        controller.project.artboards.first.nodes.single.kind,
        DocumentNodeKind.textFrame,
      );
    });
  });

  group('select tool', () {
    test('selectNode sets selectedNodeId and notifies', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;

      var notified = 0;
      controller.addListener(() => notified++);

      controller.selectNode(nodeId);
      expect(controller.selectedNodeId, nodeId);
      expect(notified, 1);

      // Selecting the same node again is a no-op.
      controller.selectNode(nodeId);
      expect(notified, 1);
    });

    test('deselectNode clears the selection', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      controller.selectNode(nodeId);
      expect(controller.selectedNodeId, nodeId);

      controller.deselectNode();
      expect(controller.selectedNodeId, isNull);
    });

    test('newProject clears the selection', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      controller.selectNode(controller.project.artboards.first.nodes.single.id);
      controller.newProject('Fresh');
      expect(controller.selectedNodeId, isNull);
    });
  });

  group('node move', () {
    test('moveNode shifts a shape node through one undoable transaction', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      expect(controller.revision, 1);

      final moved = controller.moveNode(nodeId, 50, 30);
      expect(moved, isTrue);
      expect(controller.revision, 2);
      expect(controller.canUndo, isTrue);

      final node = controller.project.artboards.first.nodes.single;
      final geometry = nodeGeometry(node)!;
      expect(geometry.x, 150);
      expect(geometry.y, 130);
    });

    test('moveNode clamps to artboard bounds', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;

      controller.moveNode(nodeId, -500, 9999);
      final node = controller.project.artboards.first.nodes.single;
      final geometry = nodeGeometry(node)!;
      expect(geometry.x, 0);
      expect(geometry.y, 800); // clamped to artboard height
    });

    test('moveNode returns false for nonexistent node', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      expect(controller.moveNode(GgenId('no.such.node'), 10, 10), isFalse);
      expect(controller.revision, 1); // No extra transaction.
    });

    test('moveNode returns false for zero effective delta', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      expect(controller.moveNode(nodeId, 0, 0), isFalse);
      expect(controller.revision, 1); // No extra transaction.
    });

    test('moveNode rejects non-finite delta', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      expect(() => controller.moveNode(nodeId, double.nan, 0), throwsArgumentError);
    });

    test('undo restores the original position', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      controller.moveNode(nodeId, 200, 150);

      controller.undo();
      final node = controller.project.artboards.first.nodes.single;
      final geometry = nodeGeometry(node)!;
      expect(geometry.x, 100);
      expect(geometry.y, 100);
    });

    test('redo re-applies the move', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      controller.moveNode(nodeId, 200, 150);
      controller.undo();
      controller.redo();

      final node = controller.project.artboards.first.nodes.single;
      final geometry = nodeGeometry(node)!;
      expect(geometry.x, 300);
      expect(geometry.y, 250);
    });

    test('moveNode works for text nodes', () {
      final controller = StudioController();
      controller.addTextNode(100, 100, 'Hello');
      final nodeId = controller.project.artboards.first.nodes.single.id;

      controller.moveNode(nodeId, 50, 50);
      final node = controller.project.artboards.first.nodes.single;
      final geometry = textNodeGeometry(node)!;
      expect(geometry.x, 150);
      expect(geometry.y, 150);
    });
  });
}
