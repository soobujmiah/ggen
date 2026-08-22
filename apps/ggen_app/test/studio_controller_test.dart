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
      expect(geometry.y, 1920 - 64);
      expect(geometry.x + geometry.width, lessThanOrEqualTo(1080));
      expect(geometry.y + geometry.height, lessThanOrEqualTo(1920));
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
      expect(geometry.y, 1920);
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

  group('multi-select', () {
    test('toggle selection adds, removes and keeps the primary last', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      controller.addShapeNode(400, 100);
      controller.addShapeNode(700, 100);
      final ids = controller.project.artboards.first.nodes
          .map((n) => n.id)
          .toList();

      controller.selectNode(ids[0], toggle: true);
      controller.selectNode(ids[1], toggle: true);
      expect(controller.selectedNodeIds, <GgenId>[ids[0], ids[1]]);
      expect(controller.selectedNodeId, ids[1]); // most recent = primary

      // Toggling a selected node removes it; order is preserved.
      controller.selectNode(ids[0], toggle: true);
      expect(controller.selectedNodeIds, <GgenId>[ids[1]]);
      expect(controller.selectedNodeId, ids[1]);

      controller.selectNode(ids[1], toggle: true);
      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.selectedNodeId, isNull);

      // A plain select replaces the whole selection.
      controller.selectNode(ids[0], toggle: true);
      controller.selectNode(ids[2], toggle: true);
      controller.selectNode(ids[1]);
      expect(controller.selectedNodeIds, <GgenId>[ids[1]]);
    });

    test('moveNodes moves every selected node in one undoable step', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      controller.addShapeNode(400, 100);
      final ids = controller.project.artboards.first.nodes
          .map((n) => n.id)
          .toList();

      final moved = controller.moveNodes(ids, 50, 30);
      expect(moved, isTrue);
      // One transaction, not two.
      expect(controller.revision, 3);
      final nodes = controller.project.artboards.first.nodes;
      expect(nodeGeometry(nodes[0])!.x, 150);
      expect(nodeGeometry(nodes[0])!.y, 130);
      expect(nodeGeometry(nodes[1])!.x, 450);
      expect(nodeGeometry(nodes[1])!.y, 130);

      controller.undo();
      expect(nodeGeometry(controller.project.artboards.first.nodes[0])!.x, 100);
      expect(nodeGeometry(controller.project.artboards.first.nodes[1])!.x, 400);
      controller.redo();
      expect(nodeGeometry(controller.project.artboards.first.nodes[0])!.x, 150);
      expect(nodeGeometry(controller.project.artboards.first.nodes[1])!.x, 450);
    });

    test('moveNodes skips missing nodes and returns false when nothing moved', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final existing = controller.project.artboards.first.nodes.single.id;
      expect(controller.moveNodes(<GgenId>[existing, GgenId('missing')], 10, 0),
          isTrue);
      expect(controller.moveNodes(<GgenId>[GgenId('missing')], 10, 0), isFalse);
      expect(controller.moveNodes(const <GgenId>[], 10, 0), isFalse);
      // Zero net delta is a no-op.
      expect(controller.moveNodes(<GgenId>[existing], 0, 0), isFalse);
    });

    test('deleteNodes removes a group in one step and prunes the selection', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      controller.addShapeNode(400, 100);
      controller.addShapeNode(700, 100);
      final ids = controller.project.artboards.first.nodes
          .map((n) => n.id)
          .toList();

      controller.selectNode(ids[0], toggle: true);
      controller.selectNode(ids[1], toggle: true);
      expect(controller.selectedNodeIds.length, 2);

      final deleted = controller.deleteNodes(<GgenId>[ids[0], ids[1]]);
      expect(deleted, isTrue);
      expect(controller.objectCount, 1);
      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.selectedNodeId, isNull);
      // One undoable step restores both.
      controller.undo();
      expect(controller.objectCount, 3);
      expect(controller.selectedNodeIds, isEmpty);
    });

    test('deleteNode still works as a single-node delete', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final id = controller.project.artboards.first.nodes.single.id;
      controller.selectNode(id);
      expect(controller.deleteNode(id), isTrue);
      expect(controller.selectedNodeId, isNull);
      expect(controller.objectCount, 0);
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
      expect(geometry.y, 1920); // clamped to artboard height
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

  group('layer operations', () {
    test('toggleNodeVisibility flips visible through an undoable session', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      expect(controller.project.artboards.first.nodes.single.visible, isTrue);

      final result = controller.toggleNodeVisibility(nodeId);
      expect(result, isTrue);
      expect(controller.project.artboards.first.nodes.single.visible, isFalse);
      expect(controller.revision, 2);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.project.artboards.first.nodes.single.visible, isTrue);
    });

    test('toggleNodeLock flips locked through an undoable session', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      expect(controller.project.artboards.first.nodes.single.locked, isFalse);

      final result = controller.toggleNodeLock(nodeId);
      expect(result, isTrue);
      expect(controller.project.artboards.first.nodes.single.locked, isTrue);
      expect(controller.revision, 2);

      controller.undo();
      expect(controller.project.artboards.first.nodes.single.locked, isFalse);
    });

    test('toggleNodeVisibility returns false for nonexistent node', () {
      final controller = StudioController();
      expect(
        controller.toggleNodeVisibility(GgenId('no.such')),
        isFalse,
      );
      expect(controller.revision, 0);
    });

    test('toggleNodeLock returns false for nonexistent node', () {
      final controller = StudioController();
      expect(controller.toggleNodeLock(GgenId('no.such')), isFalse);
      expect(controller.revision, 0);
    });

    test('reorderNodes moves a node through an undoable session', () {
      final controller = StudioController();
      controller.addShapeNode(10, 10);
      controller.addShapeNode(20, 20);
      controller.addShapeNode(30, 30);
      final nodes = controller.project.artboards.first.nodes;
      expect(nodes.map((n) => n.name), ['Shape 1', 'Shape 2', 'Shape 3']);

      final result = controller.reorderNodes(0, 2);
      expect(result, isTrue);
      final reordered = controller.project.artboards.first.nodes;
      expect(reordered.map((n) => n.name), ['Shape 2', 'Shape 3', 'Shape 1']);
      expect(controller.revision, 4); // 3 adds + 1 reorder

      controller.undo();
      final restored = controller.project.artboards.first.nodes;
      expect(restored.map((n) => n.name), ['Shape 1', 'Shape 2', 'Shape 3']);
    });

    test('reorderNodes rejects out-of-range and identical indices', () {
      final controller = StudioController();
      controller.addShapeNode(10, 10);
      controller.addShapeNode(20, 20);

      expect(controller.reorderNodes(-1, 0), isFalse);
      expect(controller.reorderNodes(0, 5), isFalse);
      expect(controller.reorderNodes(0, 0), isFalse);
      expect(controller.revision, 2); // Only the 2 adds.
    });

    test('deleteNode removes a node through an undoable session', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      controller.addShapeNode(200, 200);
      final nodeId = controller.project.artboards.first.nodes.first.id;
      expect(controller.objectCount, 2);

      final result = controller.deleteNode(nodeId);
      expect(result, isTrue);
      expect(controller.objectCount, 1);
      expect(controller.revision, 3);

      controller.undo();
      expect(controller.objectCount, 2);
    });

    test('deleteNode clears selection when the deleted node was selected', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      controller.selectNode(nodeId);
      expect(controller.selectedNodeId, nodeId);

      controller.deleteNode(nodeId);
      expect(controller.selectedNodeId, isNull);
    });

    test('deleteNode returns false for nonexistent node', () {
      final controller = StudioController();
      expect(controller.deleteNode(GgenId('no.such')), isFalse);
      expect(controller.revision, 0);
    });
  });

  group('resize node', () {
    test('resizeNode updates shape geometry through an undoable session', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;

      final result = controller.resizeNode(
        nodeId,
        x: 50,
        y: 50,
        width: 128,
        height: 96,
      );
      expect(result, isTrue);
      expect(controller.revision, 2);

      final node = controller.project.artboards.first.nodes.single;
      final geometry = nodeGeometry(node)!;
      expect(geometry.x, 50);
      expect(geometry.y, 50);
      expect(geometry.width, 128);
      expect(geometry.height, 96);
    });

    test('resizeNode undo restores original geometry', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      controller.resizeNode(
        nodeId,
        x: 200,
        y: 200,
        width: 32,
        height: 32,
      );

      controller.undo();
      final node = controller.project.artboards.first.nodes.single;
      final geometry = nodeGeometry(node)!;
      expect(geometry.x, 100);
      expect(geometry.y, 100);
      expect(geometry.width, 64);
      expect(geometry.height, 64);
    });

    test('resizeNode rejects non-finite and non-positive geometry', () {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      final nodeId = controller.project.artboards.first.nodes.single.id;
      expect(
        () => controller.resizeNode(
          nodeId,
          x: double.nan,
          y: 0,
          width: 10,
          height: 10,
        ),
        throwsArgumentError,
      );
      expect(
        () => controller.resizeNode(
          nodeId,
          x: 0,
          y: 0,
          width: -5,
          height: 10,
        ),
        throwsArgumentError,
      );
    });

    test('resizeNode returns false for nonexistent node', () {
      final controller = StudioController();
      expect(
        controller.resizeNode(
          GgenId('no.such'),
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        ),
        isFalse,
      );
    });

    test('resizeNode returns false for text nodes (no w/h)', () {
      final controller = StudioController();
      controller.addTextNode(100, 100, 'Hello');
      final nodeId = controller.project.artboards.first.nodes.single.id;
      expect(
        controller.resizeNode(
          nodeId,
          x: 0,
          y: 0,
          width: 100,
          height: 50,
        ),
        isFalse,
      );
    });
  });

  group('layer groups', () {
    StudioController controllerWithShapes() {
      final controller = StudioController();
      controller.addShapeNode(10, 10);
      controller.addShapeNode(40, 40);
      controller.addShapeNode(70, 70);
      return controller;
    }

    List<GgenId> shapeIds(StudioController controller) => <GgenId>[
      for (final node in controller.project.artboards.first.nodes)
        node.id,
    ];

    DocumentNode groupNode(StudioController controller) =>
        controller.project.artboards.first.nodes
            .lastWhere((n) => n.kind == DocumentNodeKind.group);

    test('createGroup groups nodes into one undoable step', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      final before = controller.revision;

      expect(controller.createGroup(<GgenId>[ids[0], ids[1]]), isTrue);
      expect(controller.revision, before + 1);
      final group = groupNode(controller);
      expect(groupChildIds(group), <GgenId>[ids[0], ids[1]]);
      expect(controller.selectedNodeId, group.id);
      // Members stay first-class nodes in the artboard.
      expect(controller.objectCount, 4);

      controller.undo();
      expect(
        controller.project.artboards.first.nodes
            .any((n) => n.kind == DocumentNodeKind.group),
        isFalse,
      );
    });

    test('createGroup rejects invalid inputs without extra revisions', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      final before = controller.revision;

      expect(controller.createGroup(<GgenId>[ids[0]]), isFalse);
      expect(
        controller.createGroup(<GgenId>[ids[0], GgenId('node-missing')]),
        isFalse,
      );
      expect(controller.createGroup(<GgenId>[ids[0], ids[0]]), isFalse);
      expect(controller.createGroup(<GgenId>[ids[0], ids[1]]), isTrue);
      // A member of an existing group cannot be regrouped.
      expect(
        controller.createGroup(<GgenId>[ids[1], ids[2]]),
        isFalse,
      );
      // An existing group cannot be nested into another group.
      final group = groupNode(controller);
      expect(
        controller.createGroup(<GgenId>[group.id, ids[2]]),
        isFalse,
      );
      expect(controller.revision, before + 1);
    });

    test('createGroup preserves a custom name', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      expect(
        controller.createGroup(<GgenId>[ids[0], ids[1]], name: 'Logo'),
        isTrue,
      );
      expect(groupNode(controller).name, 'Logo');
    });

    test('ungroup dissolves the group and keeps members', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      controller.createGroup(<GgenId>[ids[0], ids[1]]);
      final group = groupNode(controller);

      expect(controller.ungroup(group.id), isTrue);
      final nodes = controller.project.artboards.first.nodes;
      expect(
        nodes.any((n) => n.kind == DocumentNodeKind.group),
        isFalse,
      );
      expect(nodes, hasLength(3));
      expect(
        controller.selectedNodeIds,
        unorderedEquals(<GgenId>[ids[0], ids[1]]),
      );

      controller.undo();
      expect(
        controller.project.artboards.first.nodes
            .any((n) => n.kind == DocumentNodeKind.group),
        isTrue,
      );
    });

    test('group visibility toggles members in one step', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      controller.createGroup(<GgenId>[ids[0], ids[1]]);
      final before = controller.revision;
      final group = groupNode(controller);

      expect(controller.toggleNodeVisibility(group.id), isTrue);
      expect(controller.revision, before + 1);
      for (final node in controller.project.artboards.first.nodes) {
        final grouped =
            node.id == group.id || node.id == ids[0] || node.id == ids[1];
        expect(
          node.visible,
          grouped ? isFalse : isTrue,
          reason: '${node.id} should hide only with its group',
        );
      }
    });

    test('group lock toggles members in one step', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      controller.createGroup(<GgenId>[ids[0], ids[1]]);
      final group = groupNode(controller);

      expect(controller.toggleNodeLock(group.id), isTrue);
      for (final node in controller.project.artboards.first.nodes) {
        final grouped =
            node.id == group.id || node.id == ids[0] || node.id == ids[1];
        expect(
          node.locked,
          grouped ? isTrue : isFalse,
          reason: '${node.id} should lock only with its group',
        );
      }
    });

    test('deleting a group deletes its members too', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      controller.createGroup(<GgenId>[ids[0], ids[1]]);
      final group = groupNode(controller);

      expect(controller.deleteNode(group.id), isTrue);
      expect(controller.objectCount, 1); // Only ids[2] remains.
      controller.undo();
      expect(controller.objectCount, 4);
    });

    test('deleting a member prunes it from its group', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      controller.createGroup(<GgenId>[ids[0], ids[1]]);

      expect(controller.deleteNode(ids[0]), isTrue);
      expect(controller.objectCount, 3);
      expect(groupChildIds(groupNode(controller)), <GgenId>[ids[1]]);

      // Deleting the last member dissolves the group.
      expect(controller.deleteNode(ids[1]), isTrue);
      expect(controller.objectCount, 1);
      expect(
        controller.project.artboards.first.nodes
            .any((n) => n.kind == DocumentNodeKind.group),
        isFalse,
      );
    });

    test('moving a group moves its members in one step', () {
      final controller = controllerWithShapes();
      final ids = shapeIds(controller);
      controller.createGroup(<GgenId>[ids[0], ids[1]]);
      final before = controller.revision;

      double xOf(GgenId id) {
        final node = controller.project.artboards.first.nodes
            .firstWhere((n) => n.id == id);
        return (node.extensions['x']! as num).toDouble();
      }

      final before0 = xOf(ids[0]);
      final before1 = xOf(ids[1]);
      expect(controller.moveNodes(<GgenId>[groupNode(controller).id], 20, 0), isTrue);
      expect(controller.revision, before + 1);
      expect(xOf(ids[0]), before0 + 20);
      expect(xOf(ids[1]), before1 + 20);
    });

    test('helpers fail closed on malformed group payloads', () {
      final plain = DocumentNode(
        id: GgenId('node.x'),
        kind: DocumentNodeKind.shape,
        name: 'Shape',
      );
      expect(isGroupNode(plain), isFalse);
      expect(groupChildIds(plain), isNull);

      final malformed = DocumentNode(
        id: GgenId('group.x'),
        kind: DocumentNodeKind.group,
        name: 'Group',
        extensions: <String, Object?>{'children': 'not-a-list'},
      );
      expect(groupChildIds(malformed), isNull);
      expect(
        () => Artboard(
          id: GgenId('artboard-1'),
          name: 'A',
          width: 800,
          height: 600,
          nodes: <DocumentNode>[
            DocumentNode(
              id: GgenId('node.1'),
              kind: DocumentNodeKind.shape,
              name: 'S',
            ),
            malformed,
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
