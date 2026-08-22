import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  test('project preserves immutable artboards and unique IDs', () {
    final project = DocumentProject(
      id: GgenId('project.demo'),
      name: 'Professional mobile project',
      artboards: <Artboard>[
        Artboard(
          id: GgenId('artboard.main'),
          name: 'Main',
          width: 1080,
          height: 1920,
          nodes: <DocumentNode>[
            DocumentNode(
              id: GgenId('node.title'),
              kind: DocumentNodeKind.textFrame,
              name: 'Title',
            ),
          ],
        ),
      ],
    );

    expect(project.schemaVersion, 1);
    expect(project.artboards.single.nodes.single.opacity, 1);
    expect(
      () => project.artboards.add(
        Artboard(id: GgenId('extra'), name: 'Extra', width: 1, height: 1),
      ),
      throwsUnsupportedError,
    );
  });

  test('duplicate IDs and invalid geometry fail closed', () {
    final duplicate = GgenId('node.same');
    expect(
      () => Artboard(
        id: GgenId('artboard.bad'),
        name: 'Bad',
        width: 100,
        height: 100,
        nodes: <DocumentNode>[
          DocumentNode(
            id: duplicate,
            kind: DocumentNodeKind.shape,
            name: 'One',
          ),
          DocumentNode(
            id: duplicate,
            kind: DocumentNodeKind.shape,
            name: 'Two',
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => DocumentNode(
        id: GgenId('node.opacity'),
        kind: DocumentNodeKind.rasterLayer,
        name: 'Bad opacity',
        opacity: 1.1,
      ),
      throwsArgumentError,
    );
  });

  test('group references are validated fail-closed', () {
    DocumentNode shape(String id) => DocumentNode(
      id: GgenId(id),
      kind: DocumentNodeKind.shape,
      name: id,
    );
    Artboard artboard(List<DocumentNode> nodes) => Artboard(
      id: GgenId('artboard-1'),
      name: 'A',
      width: 800,
      height: 600,
      nodes: nodes,
    );
    DocumentNode group(List<String> children) => DocumentNode(
      id: GgenId('group.1'),
      kind: DocumentNodeKind.group,
      name: 'G',
      extensions: <String, Object?>{'children': children},
    );

    expect(
      () => artboard(<DocumentNode>[
        shape('node.1'),
        shape('node.2'),
        group(<String>['node.1', 'node.2']),
      ]),
      returnsNormally,
    );

    // Missing child reference fails.
    expect(
      () => artboard(<DocumentNode>[shape('node.1'), group(<String>['node.1', 'node.2'])]),
      throwsArgumentError,
    );

    // Duplicate child id fails.
    expect(
      () => artboard(<DocumentNode>[shape('node.1'), group(<String>['node.1', 'node.1'])]),
      throwsArgumentError,
    );

    // Empty children list fails.
    expect(
      () => artboard(<DocumentNode>[shape('node.1'), group(<String>[])]),
      throwsArgumentError,
    );

    // Non-group nodes must not carry children.
    expect(
      () => artboard(<DocumentNode>[
        DocumentNode(
          id: GgenId('node.1'),
          kind: DocumentNodeKind.shape,
          name: 'S',
          extensions: <String, Object?>{'children': <String>['node.1']},
        ),
      ]),
      throwsArgumentError,
    );
  });
}
