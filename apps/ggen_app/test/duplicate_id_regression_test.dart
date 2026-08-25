import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_app/src/storage/memory_project_store.dart';
import 'package:ggen_app/src/storage/memory_recovery_journal.dart';
import 'package:ggen_core/ggen_core.dart';

/// Regression suite for the duplicate-node-ID bug exposed by the
/// physical-device Open Project test (Redmi Turbo 4 Pro diagnostics
/// `2026-08-25T07:26:32Z`): the controller's `node-`/`text-`/`group-` id
/// counters were never seeded from a restored project, so the first new
/// node after Open Project collided with the project's existing `node-1` /
/// `text-1` / `group-1` ids and `Artboard._requireUniqueIds` threw —
/// shapes were silently lost and adding text crashed with an uncaught
/// error.
///
/// The fix seeds the counters from the loaded document in `restore()`.
/// These tests pin the contract: the FIRST new object after opening any
/// project must succeed immediately, and the counters must stay
/// collision-free through deletes, grouping/ungrouping, non-contiguous id
/// sets and the untouched empty-project baseline.
void main() {
  StudioController freshController({MemoryProjectStore? store}) {
    final effective = store ?? MemoryProjectStore();
    return StudioController(
      store: effective,
      journal: MemoryRecoveryJournal(
        AutosavePolicy(
          maxJournalEntries: 200,
          maxJournalBytes: 1 << 20,
          checkpointEveryTransactions: 8,
        ),
      ),
    );
  }

  List<String> nodeIds(StudioController controller) => [
    for (final node in controller.project.artboards.first.nodes)
      node.id.value,
  ];

  test(
    'restoring a project with node-1/node-2 lets the NEXT shape land '
    'immediately with a unique id',
    () async {
      final store = MemoryProjectStore();
      final first = freshController(store: store);
      first.addShapeNode(10, 10);
      first.addShapeNode(120, 10);
      expect(nodeIds(first), ['node-1', 'node-2']);
      final key = first.storageKey;
      await first.save();

      final reopened = freshController(store: store);
      expect(await reopened.restore(key), isTrue);

      // The device bug: this threw "Duplicate node ID: node-1" and the
      // shape was silently lost.
      reopened.addShapeNode(240, 10);
      expect(reopened.objectCount, 3);
      final ids = nodeIds(reopened);
      expect(ids, contains('node-3'));
      expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
    },
  );

  test(
    'restoring a project with text-1 lets the next text frame land '
    'immediately with a unique id',
    () async {
      final store = MemoryProjectStore();
      final first = freshController(store: store);
      first.addTextNode(10, 10, 'first');
      expect(nodeIds(first), ['text-1']);
      final key = first.storageKey;
      await first.save();

      final reopened = freshController(store: store);
      expect(await reopened.restore(key), isTrue);

      // The device bug: this threw an uncaught "Duplicate node ID: text-1".
      reopened.addTextNode(10, 500, 'second');
      final ids = nodeIds(reopened);
      expect(ids, contains('text-2'));
      expect(ids.toSet().length, ids.length);
      expect(
        reopened.project.artboards.first.nodes
            .firstWhere((n) => n.id.value == 'text-2')
            .extensions['text'],
        'second',
      );
    },
  );

  test(
    'restoring a project with group-1 lets the next group land with a '
    'unique group id',
    () async {
      final store = MemoryProjectStore();
      final first = freshController(store: store);
      first.addShapeNode(10, 10);
      first.addShapeNode(120, 10);
      expect(first.createGroup([GgenId('node-1'), GgenId('node-2')]), isTrue);
      expect(nodeIds(first), contains('group-1'));
      final key = first.storageKey;
      await first.save();

      final reopened = freshController(store: store);
      expect(await reopened.restore(key), isTrue);

      reopened.addShapeNode(240, 10);
      reopened.addShapeNode(360, 10);
      expect(
        reopened.createGroup([GgenId('node-3'), GgenId('node-4')]),
        isTrue,
      );
      final ids = nodeIds(reopened);
      expect(ids, contains('group-2'));
      expect(ids.toSet().length, ids.length);
    },
  );

  test(
    'the allocator stays collision-free after delete, group and ungroup',
    () async {
      final store = MemoryProjectStore();
      final first = freshController(store: store);
      for (var i = 0; i < 3; i++) {
        first.addShapeNode(10.0 + i * 100, 10);
      }
      final key = first.storageKey;
      await first.save();

      final reopened = freshController(store: store);
      await reopened.restore(key);

      // Delete the highest node, then keep adding: counters never decrease
      // mid-session, so even the reused slot cannot collide.
      expect(reopened.deleteNode(GgenId('node-3')), isTrue);
      reopened.addShapeNode(400, 10); // node-4
      expect(reopened.deleteNode(GgenId('node-4')), isTrue);
      reopened.addShapeNode(500, 10); // node-5

      // Group, then dissolve, then add again.
      expect(
        reopened.createGroup([GgenId('node-1'), GgenId('node-2')]),
        isTrue,
      );
      expect(reopened.ungroup(GgenId('group-1')), isTrue);
      reopened.addShapeNode(600, 10); // node-6

      final ids = nodeIds(reopened);
      expect(ids, contains('node-5'));
      expect(ids, contains('node-6'));
      expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
    },
  );

  test(
    'a project with non-contiguous ids and a high numeric suffix seeds the '
    'next ids above the maximum',
    () async {
      final store = MemoryProjectStore();
      final project = DocumentProject(
        id: GgenId('project-e'),
        name: 'Non-contiguous',
        revision: 12,
        artboards: [
          Artboard(
            id: GgenId('artboard-1'),
            name: 'Page',
            width: 1080,
            height: 1920,
            nodes: [
              DocumentNode(
                id: GgenId('node-1'),
                kind: DocumentNodeKind.shape,
                name: 'Shape 1',
                extensions: <String, Object?>{
                  'x': 10.0,
                  'y': 10.0,
                  'w': 100.0,
                  'h': 100.0,
                  'fill': 0xFF4E6BFF,
                  'shape_type': 'rectangle',
                },
              ),
              DocumentNode(
                id: GgenId('node-42'),
                kind: DocumentNodeKind.shape,
                name: 'Shape 42',
                extensions: <String, Object?>{
                  'x': 10.0,
                  'y': 200.0,
                  'w': 100.0,
                  'h': 100.0,
                  'fill': 0xFF6BCB77,
                  'shape_type': 'ellipse',
                },
              ),
              DocumentNode(
                id: GgenId('text-7'),
                kind: DocumentNodeKind.textFrame,
                name: 'Text 7',
                extensions: <String, Object?>{
                  'x': 10.0,
                  'y': 400.0,
                  'w': 480.0,
                  'h': 360.0,
                  'size': 24,
                  'text': 'legacy',
                  'color': 0xFF222222,
                  'columns': 1,
                  'gutter': 0.0,
                },
              ),
            ],
          ),
        ],
      );
      final transaction = await store.begin(
        ProjectStorageKey('project-e'),
        expectedRevision: -1,
      );
      await transaction.stage(
        ProjectEnvelope(
          project: project,
          schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
        ),
      );
      final receipt = await transaction.commit();

      final controller = freshController(store: store);
      expect(await controller.restore(receipt.key), isTrue);

      // Both next ids must clear the highest existing suffix of their kind,
      // not restart from 1.
      controller.addShapeNode(500, 10); // must be node-43, not node-2
      controller.addTextNode(500, 600, 'fresh'); // must be text-8, not text-2
      final ids = nodeIds(controller);
      expect(ids, contains('node-43'));
      expect(ids, contains('text-8'));
      expect(ids.toSet().length, ids.length);
    },
  );

  test('an empty untitled project still starts node/text/group ids at 1', () {
    final controller = freshController();
    controller.addShapeNode(10, 10);
    controller.addTextNode(10, 500, 'hello');
    final ids = nodeIds(controller);
    expect(ids, containsAll(<String>['node-1', 'text-1']));
    expect(ids.toSet().length, ids.length);
  });

  test(
    'restoring into the SAME controller reseeds without breaking later '
    'adds',
    () async {
      final controller = freshController();
      controller.addShapeNode(10, 10); // node-1
      final key = controller.storageKey;
      await controller.save();

      // New project resets the counters, then restoring the saved project
      // must re-seed them from the document.
      controller.newProject('Scratch');
      expect(await controller.restore(key), isTrue);
      controller.addShapeNode(200, 10); // must be node-2
      final ids = nodeIds(controller);
      expect(ids, contains('node-2'));
      expect(ids.toSet().length, ids.length);
    },
  );
}
