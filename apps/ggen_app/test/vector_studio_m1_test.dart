// Vector Studio Milestone 1 — primitive shape contract tests.
//
// These 21 tests pin down the acceptance criteria for the rectangle + ellipse
// slice: creation, geometry, style independence, persistence, fail-closed
// validation, undo/redo, and legacy compatibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_core/ggen_core.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_app/src/geometry/shape_geometry.dart';

void main() {
  group('M1 primitive creation', () {
    test('1. addShapeNode writes rectangle geometry with shape_type=rectangle', () {
      final c = StudioController();
      c.addShapeNode(100, 200);
      final node = c.project.artboards.first.nodes.single;
      expect(node.kind, DocumentNodeKind.shape);
      expect(node.extensions['x'], 100);
      expect(node.extensions['y'], 200);
      expect(node.extensions['w'], 64);
      expect(node.extensions['h'], 64);
      expect(node.extensions['fill'], isA<int>());
      expect(node.extensions['shape_type'], 'rectangle');
    });

    test('2. addEllipseNode writes shape_type=ellipse', () {
      final c = StudioController();
      c.addEllipseNode(50, 60);
      final node = c.project.artboards.first.nodes.single;
      expect(node.kind, DocumentNodeKind.shape);
      expect(node.extensions['shape_type'], 'ellipse');
      expect(node.extensions['x'], 50);
      expect(node.extensions['y'], 60);
    });

    test('3. fill color is independently settable per shape', () {
      final c = StudioController();
      c.addShapeNode(10, 10);
      c.addShapeNode(100, 10);
      final nodes = c.project.artboards.first.nodes;
      final a = nodeShapeGeometry(nodes[0])!;
      final b = nodeShapeGeometry(nodes[1])!;
      // The palette rotates; they should be different colors out of the box.
      expect(a.fill, isNot(equals(b.fill)));
    });

    test('4. stroke color is independently settable per shape via updateShapeStyle', () {
      final c = StudioController();
      c.addShapeNode(10, 10);
      c.addShapeNode(100, 10);
      final nodes = c.project.artboards.first.nodes;
      c.selectNode(nodes[0].id);
      c.updateShapeStyle(nodes[0].id, stroke: 0xFFFF0000, strokeWidth: 2);
      c.updateShapeStyle(nodes[1].id, stroke: 0xFF0000FF, strokeWidth: 3);
      final a = nodeShapeGeometry(c.project.artboards.first.nodes[0])!;
      final b = nodeShapeGeometry(c.project.artboards.first.nodes[1])!;
      expect(a.stroke, 0xFFFF0000);
      expect(a.strokeWidth, closeTo(2.0, 0.001));
      expect(b.stroke, 0xFF0000FF);
      expect(b.strokeWidth, closeTo(3.0, 0.001));
    });

    test('5. stroke width is independently settable per shape', () {
      final c = StudioController();
      c.addShapeNode(10, 10);
      c.addShapeNode(100, 10);
      final nodes = c.project.artboards.first.nodes;
      c.updateShapeStyle(nodes[0].id, stroke: 0xFF000000, strokeWidth: 1);
      c.updateShapeStyle(nodes[1].id, stroke: 0xFF000000, strokeWidth: 6);
      final a = nodeShapeGeometry(c.project.artboards.first.nodes[0])!;
      final b = nodeShapeGeometry(c.project.artboards.first.nodes[1])!;
      expect(a.strokeWidth, closeTo(1.0, 0.001));
      expect(b.strokeWidth, closeTo(6.0, 0.001));
    });

    test('6. style independence — restyling one shape does not affect another', () {
      final c = StudioController();
      c.addShapeNode(10, 10);
      c.addShapeNode(100, 10);
      final nodes = c.project.artboards.first.nodes;
      final before = nodeShapeGeometry(nodes[1])!;
      c.updateShapeStyle(nodes[0].id, fill: 0xFF00FF00, stroke: 0xFF000000, strokeWidth: 4);
      final after = nodeShapeGeometry(c.project.artboards.first.nodes[1])!;
      expect(after.fill, before.fill);
      expect(after.stroke, before.stroke);
      expect(after.strokeWidth, before.strokeWidth);
    });
  });

  group('M1 persistence round-trip', () {
    test('7. rectangle geometry + fill + stroke survives encode/decode', () {
      final c = StudioController();
      c.addShapeNode(20, 30);
      final n0 = c.project.artboards.first.nodes.single;
      c.updateShapeStyle(n0.id, fill: 0xFF123456, stroke: 0xFFABCDEF, strokeWidth: 2.5);
      final encoded = c.serialize();
      // Rebuild a controller and restore via the codec path.
      final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
      final decoded = codec.decode(encoded).project;
      final node = decoded.artboards.first.nodes.single;
      final g = nodeShapeGeometry(node)!;
      expect(g.x, closeTo(20, 0.001));
      expect(g.y, closeTo(30, 0.001));
      expect(g.width, closeTo(64, 0.001));
      expect(g.fill, 0xFF123456);
      expect(g.stroke, 0xFFABCDEF);
      expect(g.strokeWidth, closeTo(2.5, 0.001));
      expect(g.shapeType, ShapePrimitive.rectangle);
    });

    test('8. ellipse geometry + fill survives encode/decode', () {
      final c = StudioController();
      c.addEllipseNode(200, 300);
      final n0 = c.project.artboards.first.nodes.single;
      c.updateShapeStyle(n0.id, fill: 0xFFFF00FF);
      final encoded = c.serialize();
      final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
      final decoded = codec.decode(encoded).project;
      final g = nodeShapeGeometry(decoded.artboards.first.nodes.single)!;
      expect(g.x, closeTo(200, 0.001));
      expect(g.y, closeTo(300, 0.001));
      expect(g.fill, 0xFFFF00FF);
      expect(g.shapeType, ShapePrimitive.ellipse);
    });
  });

  group('M1 fail-closed malformed geometry rejection', () {
    test('9. core Artboard constructor rejects NaN x on a shape payload', () {
      expect(
        () => Artboard(
          id: GgenId('a1'),
          name: 'A',
          width: 800,
          height: 600,
          nodes: <DocumentNode>[
            DocumentNode(
              id: GgenId('s1'),
              kind: DocumentNodeKind.shape,
              name: 'bad',
              extensions: <String, Object?>{
                'x': double.nan,
                'y': 0,
                'w': 10,
                'h': 10,
                'fill': 0xFF000000,
              },
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('10. core Artboard constructor rejects non-positive width', () {
      expect(
        () => Artboard(
          id: GgenId('a1'),
          name: 'A',
          width: 800,
          height: 600,
          nodes: <DocumentNode>[
            DocumentNode(
              id: GgenId('s1'),
              kind: DocumentNodeKind.shape,
              name: 'bad',
              extensions: <String, Object?>{
                'x': 0, 'y': 0, 'w': -5, 'h': 10, 'fill': 0xFF000000,
              },
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('11. core Artboard constructor rejects non-int fill', () {
      expect(
        () => Artboard(
          id: GgenId('a1'),
          name: 'A',
          width: 800,
          height: 600,
          nodes: <DocumentNode>[
            DocumentNode(
              id: GgenId('s1'),
              kind: DocumentNodeKind.shape,
              name: 'bad',
              extensions: <String, Object?>{
                'x': 0, 'y': 0, 'w': 10, 'h': 10, 'fill': 'not-a-color',
              },
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('12. core Artboard constructor rejects negative stroke_width', () {
      expect(
        () => Artboard(
          id: GgenId('a1'),
          name: 'A',
          width: 800,
          height: 600,
          nodes: <DocumentNode>[
            DocumentNode(
              id: GgenId('s1'),
              kind: DocumentNodeKind.shape,
              name: 'bad',
              extensions: <String, Object?>{
                'x': 0, 'y': 0, 'w': 10, 'h': 10, 'fill': 0xFF000000,
                'stroke': 0xFFFFFFFF, 'stroke_width': -1,
              },
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('13. bare shape node (no geometry keys) is accepted as a placeholder', () {
      // Legacy/placeholder shapes created with no payload at all must not
      // break document load.
      expect(
        () => Artboard(
          id: GgenId('a1'),
          name: 'A',
          width: 800,
          height: 600,
          nodes: <DocumentNode>[
            DocumentNode(
              id: GgenId('s1'),
              kind: DocumentNodeKind.shape,
              name: 'placeholder',
            ),
          ],
        ),
        returnsNormally,
      );
    });

    test('14. legacy shape (color key, no fill/shape_type) reads as rectangle with color as fill', () {
      final node = DocumentNode(
        id: GgenId('s1'),
        kind: DocumentNodeKind.shape,
        name: 'legacy',
        extensions: <String, Object?>{
          'x': 5.0, 'y': 6.0, 'w': 32.0, 'h': 32.0,
          'color': 0xFFAABBCC,
        },
      );
      final g = nodeShapeGeometry(node);
      expect(g, isNotNull);
      expect(g!.fill, 0xFFAABBCC);
      expect(g.shapeType, ShapePrimitive.rectangle);
    });

    test('nodeShapeGeometry returns null for malformed runtime payload (fail-closed reader)', () {
      final node = DocumentNode(
        id: GgenId('s1'),
        kind: DocumentNodeKind.shape,
        name: 'bad',
        extensions: <String, Object?>{
          'x': 'oops', 'y': 0, 'w': 10, 'h': 10, 'fill': 0xFF000000,
        },
      );
      expect(nodeShapeGeometry(node), isNull);
    });
  });

  group('M1 undo/redo', () {
    test('15. undo removes an added primitive', () {
      final c = StudioController();
      c.addShapeNode(10, 10);
      expect(c.objectCount, 1);
      c.undo();
      expect(c.objectCount, 0);
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isTrue);
    });

    test('16. redo restores an added primitive', () {
      final c = StudioController();
      c.addShapeNode(10, 10);
      c.undo();
      c.redo();
      expect(c.objectCount, 1);
      final g = nodeShapeGeometry(c.project.artboards.first.nodes.single);
      expect(g, isNotNull);
      expect(g!.shapeType, ShapePrimitive.rectangle);
    });

    test('17. style update is a single undoable step', () {
      final c = StudioController();
      c.addShapeNode(10, 10);
      final id = c.project.artboards.first.nodes.single.id;
      final revBefore = c.revision;
      c.updateShapeStyle(id, fill: 0xFF112233, stroke: 0xFFFFFFFF, strokeWidth: 3);
      expect(c.revision, revBefore + 1);
      c.undo();
      final g = nodeShapeGeometry(c.project.artboards.first.nodes.single)!;
      expect(g.fill, isNot(0xFF112233));
    });

    test('18. resize is a single undoable step', () {
      final c = StudioController();
      c.addShapeNode(10, 10);
      final id = c.project.artboards.first.nodes.single.id;
      final revBefore = c.revision;
      c.resizeNode(id, x: 10, y: 10, width: 128, height: 128);
      expect(c.revision, revBefore + 1);
      final g = nodeShapeGeometry(c.project.artboards.first.nodes.single)!;
      expect(g.width, closeTo(128, 0.001));
      c.undo();
      final g2 = nodeShapeGeometry(c.project.artboards.first.nodes.single)!;
      expect(g2.width, closeTo(64, 0.001));
    });
  });

  group('M1 rendering primitives', () {
    test('19. ShapePrimitive.rectangle maps to wire "rectangle" and back', () {
      expect(ShapePrimitive.rectangle.wire, 'rectangle');
      expect(ShapePrimitive.fromWire('rectangle'), ShapePrimitive.rectangle);
    });

    test('20. ShapePrimitive.ellipse maps to wire "ellipse" and back', () {
      expect(ShapePrimitive.ellipse.wire, 'ellipse');
      expect(ShapePrimitive.fromWire('ellipse'), ShapePrimitive.ellipse);
    });

    test('21. unknown shape_type wire value falls back to rectangle (fail-safe render)', () {
      // A future shape type sent to an older client must not crash; it renders
      // as its bounding rectangle so the user still sees SOMETHING.
      expect(ShapePrimitive.fromWire('path'), ShapePrimitive.rectangle);
      expect(ShapePrimitive.fromWire(null), ShapePrimitive.rectangle);
    });
  });
}
