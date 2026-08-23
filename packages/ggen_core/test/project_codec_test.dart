import 'dart:convert';

import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  ProjectCodec codec({ProjectCodecLimits? limits}) =>
      ProjectCodec(limits: limits ?? ProjectCodecLimits.conservative());

  DocumentProject project({Map<String, Object?>? nodeExtensions}) =>
      DocumentProject(
        id: GgenId('project.codec'),
        name: 'Codec project',
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
                visible: true,
                locked: false,
                opacity: 0.75,
                extensions:
                    nodeExtensions ??
                    <String, Object?>{
                      'zeta': 2,
                      'alpha': <Object?>[
                        'safe',
                        <String, Object?>{'nested': true},
                      ],
                    },
              ),
            ],
          ),
        ],
      );

  ProjectEnvelope envelope({Map<String, Object?>? extensions}) =>
      ProjectEnvelope(
        project: project(),
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
        extensions: extensions ?? <String, Object?>{'zeta': 'last', 'alpha': 1},
      );

  test('canonical JSON round-trips a project envelope', () {
    final encoded = codec().encode(envelope());
    final decoded = codec().decode(encoded);

    expect(decoded.project.id, GgenId('project.codec'));
    expect(
      decoded.project.artboards.single.nodes.single.kind,
      DocumentNodeKind.textFrame,
    );
    expect(decoded.project.artboards.single.nodes.single.opacity, 0.75);
    expect(decoded.extensions['alpha'], 1);
    expect(
      decoded.project.artboards.single.nodes.single.extensions['alpha'],
      contains('safe'),
    );
    expect(codec().encode(decoded), encoded);
  });

  test('canonical ordering is independent of map insertion order', () {
    final first = codec().encode(
      envelope(extensions: <String, Object?>{'z': 1, 'a': 2}),
    );
    final second = codec().encode(
      envelope(extensions: <String, Object?>{'a': 2, 'z': 1}),
    );

    expect(first, second);
    expect(first.indexOf('"a":2'), lessThan(first.indexOf('"z":1')));
  });

  test('schema policy rejects unsupported and un-migrated versions', () {
    final policy = ProjectSchemaReadPolicy(
      currentVersion: 2,
      migrationRequiredFrom: <int>{1},
    );
    expect(policy.dispositionFor(2), ProjectSchemaDisposition.current);
    expect(
      policy.dispositionFor(1),
      ProjectSchemaDisposition.migrationRequired,
    );
    expect(() => policy.requireCurrent(1), throwsStateError);
    expect(() => policy.requireCurrent(3), throwsFormatException);
  });

  test('malformed fields and unknown kinds fail closed', () {
    final encoded = codec().encode(envelope());
    final raw = jsonDecode(encoded) as Map<String, dynamic>;
    raw['unexpected'] = true;
    expect(() => codec().decode(jsonEncode(raw)), throwsFormatException);

    final kindRaw = jsonDecode(encoded) as Map<String, dynamic>;
    final projectRaw = kindRaw['project'] as Map<String, dynamic>;
    final artboards = projectRaw['artboards'] as List<dynamic>;
    final artboard = artboards.first as Map<String, dynamic>;
    final nodes = artboard['nodes'] as List<dynamic>;
    (nodes.first as Map<String, dynamic>)['kind'] = 'unknown_kind';
    expect(() => codec().decode(jsonEncode(kindRaw)), throwsFormatException);

    final versionRaw = jsonDecode(encoded) as Map<String, dynamic>;
    versionRaw['schemaVersion'] = 2;
    expect(() => codec().decode(jsonEncode(versionRaw)), throwsFormatException);
  });

  test(
    'codec limits reject oversized JSON, collections and non-JSON values',
    () {
      final small = ProjectCodecLimits(
        maxJsonBytes: 64,
        maxArtboards: 1,
        maxNodesPerArtboard: 1,
        maxCollectionItems: 2,
        maxJsonDepth: 4,
        maxStringLength: 32,
      );
      expect(
        () => codec(limits: small).encode(envelope()),
        throwsArgumentError,
      );
      final collectionLimited = ProjectCodecLimits(
        maxJsonBytes: 1024 * 1024,
        maxArtboards: 1,
        maxNodesPerArtboard: 1,
        maxCollectionItems: 2,
        maxJsonDepth: 8,
        maxStringLength: 1024,
      );
      expect(
        () => codec(limits: collectionLimited).encode(
          envelope(
            extensions: <String, Object?>{
              'values': <Object?>[1, 2, 3],
            },
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => codec().encode(
          envelope(
            extensions: <String, Object?>{
              'unsupported': DateTime.utc(2026, 1, 1),
            },
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  group('multi-column text frame extensions', () {
    ProjectEnvelope envelopeWith(Map<String, Object?> extensions) =>
        ProjectEnvelope(
          project: DocumentProject(
            id: GgenId('project.columns'),
            name: 'Columns',
            artboards: <Artboard>[
              Artboard(
                id: GgenId('artboard.main'),
                name: 'Main',
                width: 1080,
                height: 1920,
                nodes: <DocumentNode>[
                  DocumentNode(
                    id: GgenId('node.story'),
                    kind: DocumentNodeKind.textFrame,
                    name: 'Story',
                    extensions: extensions,
                  ),
                ],
              ),
            ],
          ),
          schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
        );

    test('columns and gutter survive a JSON round-trip', () {
      final source = envelopeWith(<String, Object?>{
        'text': 'Two columns of flowing story text.',
        'size': 18.0,
        'x': 40.0,
        'y': 60.0,
        'w': 480.0,
        'h': 360.0,
        'columns': 3,
        'gutter': 24.0,
      });

      final encoded = codec().encode(source);
      final decoded = codec().decode(encoded);
      final node = decoded.project.artboards.single.nodes.single;

      expect(node.extensions['columns'], 3);
      expect(node.extensions['gutter'], 24.0);
      expect(node.extensions['w'], 480.0);
      expect(node.extensions['h'], 360.0);
      // Canonical JSON: re-encoding the decoded form reproduces the bytes.
      expect(codec().encode(decoded), encoded);
    });

    test('legacy text frame without columns/gutter decodes unchanged', () {
      final source = envelopeWith(<String, Object?>{
        'text': 'Legacy single line',
        'size': 20.0,
        'x': 10.0,
        'y': 20.0,
      });

      final decoded = codec().decode(codec().encode(source));
      final node = decoded.project.artboards.single.nodes.single;

      expect(node.extensions.containsKey('columns'), isFalse);
      expect(node.extensions.containsKey('gutter'), isFalse);
      expect(node.extensions['text'], 'Legacy single line');
    });
  });
}
