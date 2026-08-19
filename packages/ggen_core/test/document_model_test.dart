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
}
